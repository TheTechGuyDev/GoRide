-- Pricing engine: per-city rates, live demand surge, rush-hour traffic,
-- airport fees and long-pickup fees. Fare = city rate (base + km + minutes)
-- x surge + airport fee + pickup fee, never below the minimum fare.

-- ---------- cities and their rates ----------
create table if not exists cities (
  name text primary key,
  lat double precision not null,
  lng double precision not null,
  radius_km numeric not null default 40,
  active boolean not null default true
);
insert into cities (name, lat, lng, radius_km) values
  ('Lagos', 6.5244, 3.3792, 45),
  ('Ibadan', 7.3775, 3.9470, 35),
  ('Ilorin', 8.4966, 4.5426, 30),
  ('Abeokuta', 7.1475, 3.3619, 30),
  ('Abuja', 9.0765, 7.3986, 40)
on conflict (name) do nothing;

-- Overrides the default rates (ride_types) in one city.
create table if not exists city_rates (
  city text not null references cities on delete cascade,
  ride_type_id text not null references ride_types on delete cascade,
  base_fare numeric not null,
  per_km numeric not null,
  per_minute numeric not null,
  minimum_fare numeric not null,
  primary key (city, ride_type_id)
);
insert into city_rates (city, ride_type_id, base_fare, per_km, per_minute, minimum_fare) values
  ('Lagos', 'bike',     500, 230, 15, 1000),
  ('Lagos', 'keke',     600, 300, 20, 1200),
  ('Lagos', 'car',     1200, 650, 40, 2500),
  ('Lagos', 'comfort', 1500, 820, 48, 3000),
  ('Lagos', 'xl',      1900, 950, 55, 3800)
on conflict do nothing;

-- ---------- airports ----------
create table if not exists airports (
  id text primary key,
  name text not null,
  city text references cities,
  lat double precision not null,
  lng double precision not null,
  radius_m int not null default 1500,
  fee int not null,
  active boolean not null default true
);
insert into airports (id, name, city, lat, lng, radius_m, fee) values
  ('los', 'Murtala Muhammed Airport', 'Lagos', 6.5774, 3.3212, 2500, 1500),
  ('ibA', 'Ibadan Airport', 'Ibadan', 7.3624, 3.9783, 1500, 1000),
  ('ilr', 'Ilorin International Airport', 'Ilorin', 8.4402, 4.4939, 1500, 1000),
  ('abv', 'Nnamdi Azikiwe Airport', 'Abuja', 9.0068, 7.2632, 2500, 1500)
on conflict (id) do nothing;

-- ---------- settings for the engine (editable in admin) ----------
alter table app_settings
  add column if not exists demand_surge_enabled boolean not null default true,
  add column if not exists demand_radius_m int not null default 3000,
  add column if not exists rush_factor numeric not null default 1.3 check (rush_factor between 1 and 2),
  add column if not exists rush_windows jsonb not null default '[[7,10],[16,20]]',
  add column if not exists rush_weekdays_only boolean not null default true,
  add column if not exists free_pickup_km numeric not null default 3,
  add column if not exists pickup_fee_per_km int not null default 100,
  add column if not exists max_pickup_fee int not null default 800;

alter table trips
  add column if not exists city text,
  add column if not exists breakdown jsonb;

-- ---------- helpers ----------
create or replace function km_between(a_lat double precision, a_lng double precision,
  b_lat double precision, b_lng double precision) returns double precision
language sql immutable as $$
  select 6371 * 2 * asin(sqrt(power(sin(radians(b_lat - a_lat) / 2), 2)
    + cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2)));
$$;

create or replace function city_at(p_lat double precision, p_lng double precision) returns text
language sql stable security definer set search_path = public as $$
  select name from cities
  where active and km_between(p_lat, p_lng, lat, lng) <= radius_km
  order by km_between(p_lat, p_lng, lat, lng) limit 1;
$$;

-- Rush hour in Nigeria (Africa/Lagos time).
create or replace function is_rush_hour() returns boolean
language plpgsql stable security definer set search_path = public as $$
declare s app_settings := settings(); h int; dow int; w jsonb;
begin
  h := extract(hour from now() at time zone 'Africa/Lagos');
  dow := extract(isodow from now() at time zone 'Africa/Lagos');
  if s.rush_weekdays_only and dow >= 6 then return false; end if;
  for w in select * from jsonb_array_elements(s.rush_windows) loop
    if h >= (w->>0)::int and h < (w->>1)::int then return true; end if;
  end loop;
  return false;
end $$;

-- Busy-area multiplier: the higher of the fixed zones and live demand
-- (riders waiting vs free drivers nearby), never above the cap.
create or replace function surge_at(p_lat double precision, p_lng double precision) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare s app_settings := settings(); zone numeric := 1; demand numeric := 1;
  waiting int; free int; r numeric;
begin
  if not s.surge_enabled then return 1; end if;
  select coalesce(max(z.multiplier), 1) into zone from demand_zones z
    where z.active and km_between(p_lat, p_lng, z.lat, z.lng) * 1000 <= z.radius_m;
  if s.demand_surge_enabled then
    select count(*) into waiting from trips t
      where t.status = 'requested' and t.requested_at > now() - interval '10 minutes'
        and km_between(p_lat, p_lng, t.pickup_lat, t.pickup_lng) * 1000 <= s.demand_radius_m;
    select count(*) into free from driver_locations l
      where l.online and not l.on_trip and l.updated_at > now() - interval '2 minutes'
        and km_between(p_lat, p_lng, l.lat, l.lng) * 1000 <= s.demand_radius_m;
    -- Each extra waiting rider per free driver adds 10%, gently.
    r := (waiting + 1)::numeric / greatest(free, 1);
    if r > 1 then demand := 1 + least(0.3, round((r - 1) * 0.1, 1)); end if;
  end if;
  return least(s.max_surge, greatest(zone, demand));
end $$;

-- Distance to the nearest free driver of this type (null if none online).
create or replace function nearest_driver_km(p_ride_type text, p_lat double precision, p_lng double precision)
returns double precision
language sql stable security definer set search_path = public as $$
  select min(km_between(p_lat, p_lng, l.lat, l.lng)) from driver_locations l
  where l.online and not l.on_trip and l.updated_at > now() - interval '2 minutes'
    and (l.ride_type_id = p_ride_type
      or (p_ride_type = 'car' and l.ride_type_id in ('comfort', 'xl')));
$$;

-- ---------- the fare ----------
drop function if exists quote_fare(text, numeric, numeric, double precision, double precision);

create or replace function quote_fare(p_ride_type text, p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision,
  p_drop_lat double precision default null, p_drop_lng double precision default null)
returns table (fare int, surge numeric, breakdown jsonb)
language plpgsql stable security definer set search_path = public as $$
declare rt ride_types; cr city_rates; s app_settings := settings();
  v_city text; base numeric; per_km numeric; per_min numeric; minimum numeric;
  minutes numeric := p_minutes; rush boolean; sg numeric; ride numeric;
  airport int := 0; airport_name text; pickup_km double precision; pickup_fee int := 0;
  pickup_rate int; total numeric;
begin
  select * into rt from ride_types where id = p_ride_type and active;
  if not found then raise exception 'Unknown ride type'; end if;
  v_city := city_at(p_lat, p_lng);
  select * into cr from city_rates c where c.city = v_city and c.ride_type_id = p_ride_type;
  base := coalesce(cr.base_fare, rt.base_fare);
  per_km := coalesce(cr.per_km, rt.per_km);
  per_min := coalesce(cr.per_minute, rt.per_minute);
  minimum := coalesce(cr.minimum_fare, rt.minimum_fare);

  -- 3. Rush hour: trips take longer in traffic.
  rush := is_rush_hour();
  if rush then minutes := round(p_minutes * s.rush_factor); end if;

  -- 2. Surge from busy areas and live demand.
  sg := surge_at(p_lat, p_lng);
  ride := greatest(minimum, base + per_km * p_km + per_min * minutes) * sg;

  -- 4. Airport fee (pickup or drop-off at an airport).
  select a.fee, a.name into airport, airport_name from airports a
    where a.active and (km_between(p_lat, p_lng, a.lat, a.lng) * 1000 <= a.radius_m
      or (p_drop_lat is not null and km_between(p_drop_lat, p_drop_lng, a.lat, a.lng) * 1000 <= a.radius_m))
    order by a.fee desc limit 1;
  airport := coalesce(airport, 0);

  -- 5. Long pickup: only when the nearest driver is far away.
  pickup_km := nearest_driver_km(p_ride_type, p_lat, p_lng);
  if pickup_km is not null and pickup_km > s.free_pickup_km then
    pickup_rate := case rt.kind when 'bike' then s.pickup_fee_per_km / 2 when 'keke' then s.pickup_fee_per_km * 3 / 4
      else s.pickup_fee_per_km end;
    pickup_fee := least(s.max_pickup_fee, round((pickup_km - s.free_pickup_km) * pickup_rate))::int;
  end if;

  total := ride + airport + pickup_fee;
  return query select round_fare(total), sg, jsonb_build_object(
    'city', coalesce(v_city, 'Default'), 'base', base, 'per_km', per_km, 'per_minute', per_min,
    'km', p_km, 'minutes', minutes, 'rush_hour', rush, 'surge', sg,
    'ride', round_fare(ride), 'airport_fee', airport, 'airport', airport_name,
    'pickup_km', round(coalesce(pickup_km, 0)::numeric, 1), 'pickup_fee', pickup_fee);
end $$;

-- Prices for every ride type at once (ride options screen).
create or replace function quote_all(p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision,
  p_drop_lat double precision default null, p_drop_lng double precision default null)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(r.id, jsonb_build_object('fare', q.fare, 'surge', q.surge, 'breakdown', q.breakdown)), '{}'::jsonb)
  from ride_types r
  cross join lateral quote_fare(r.id, p_km, p_minutes, p_lat, p_lng, p_drop_lat, p_drop_lng) q
  where r.active;
$$;
revoke execute on function quote_all(numeric, numeric, double precision, double precision, double precision, double precision) from anon, public;
grant execute on function quote_all(numeric, numeric, double precision, double precision, double precision, double precision) to authenticated;
revoke execute on function quote_fare(text, numeric, numeric, double precision, double precision, double precision, double precision) from anon, public;
grant execute on function quote_fare(text, numeric, numeric, double precision, double precision, double precision, double precision) to authenticated;
revoke execute on function city_at(double precision, double precision) from anon, public;
revoke execute on function is_rush_hour() from anon, public;
revoke execute on function nearest_driver_km(text, double precision, double precision) from anon, public, authenticated;
revoke execute on function km_between(double precision, double precision, double precision, double precision) from anon, public;

alter table cities enable row level security;
alter table city_rates enable row level security;
alter table airports enable row level security;
create policy cities_read on cities for select using (true);
create policy cities_write on cities for all using (is_staff(array['finance', 'operations']::staff_role[]));
create policy city_rates_read on city_rates for select using (true);
create policy city_rates_write on city_rates for all using (is_staff(array['finance']::staff_role[]));
create policy airports_read on airports for select using (true);
create policy airports_write on airports for all using (is_staff(array['finance', 'operations']::staff_role[]));

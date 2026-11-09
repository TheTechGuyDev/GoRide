-- 1. Ride types on/off and opening hours per city (e.g. Oyo State bans
--    commercial motorcycles 10:30 pm to 5:30 am). Unavailable types still
--    show in the app, greyed out with the reason.
-- 2. Rush hour + busy-area pricing together are capped at 1.3x.

create table if not exists city_ride_rules (
  city text not null references cities on delete cascade,
  ride_type_id text not null references ride_types on delete cascade,
  enabled boolean not null default true,
  opens time,          -- null = all day
  closes time,
  primary key (city, ride_type_id)
);
alter table city_ride_rules enable row level security;
drop policy if exists ride_rules_read on city_ride_rules;
drop policy if exists ride_rules_write on city_ride_rules;
create policy ride_rules_read on city_ride_rules for select using (true);
create policy ride_rules_write on city_ride_rules for all using (is_staff(array['operations', 'finance']::staff_role[]));

-- Oyo State executive order (June 2026): no okada 10:30 pm to 5:30 am.
insert into city_ride_rules (city, ride_type_id, enabled, opens, closes)
values ('Ibadan', 'bike', true, '05:30', '22:30')
on conflict do nothing;

create or replace function fmt_time(t time) returns text language sql immutable as $$
  select ltrim(to_char(t, 'HH12:MI'), '0') || lower(to_char(t, 'am'));
$$;

-- Null when the ride type can be booked here now, otherwise the reason.
create or replace function ride_type_block(p_type text, p_lat double precision, p_lng double precision)
returns text language plpgsql stable security definer set search_path = public as $$
declare c text := city_at(p_lat, p_lng); r city_ride_rules; now_t time := (now() at time zone 'Africa/Lagos')::time;
begin
  if c is null then return null; end if;
  select * into r from city_ride_rules where city = c and ride_type_id = p_type;
  if r.city is null then return null; end if;
  if not r.enabled then return 'Not available in ' || c || ' yet'; end if;
  if r.opens is not null and r.closes is not null then
    if (r.opens < r.closes and (now_t < r.opens or now_t >= r.closes))
       or (r.opens > r.closes and now_t >= r.closes and now_t < r.opens) then
      return 'Available ' || fmt_time(r.opens) || ' to ' || fmt_time(r.closes);
    end if;
  end if;
  return null;
end $$;
revoke execute on function ride_type_block(text, double precision, double precision) from anon, public;
grant execute on function ride_type_block(text, double precision, double precision) to authenticated;

create or replace function quote_fare(p_ride_type text, p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision,
  p_drop_lat double precision default null, p_drop_lng double precision default null)
returns table (fare int, surge numeric, breakdown jsonb)
language plpgsql stable security definer set search_path = public as $$
declare rt ride_types; cr city_rates; s app_settings := settings();
  v_city text; base numeric; per_km numeric; per_min numeric; minimum numeric;
  minutes numeric := p_minutes; rush boolean; sg numeric; ride numeric;
  airport int := 0; airport_name text; pickup_km double precision; pickup_fee int := 0;
  pickup_rate int; total numeric; normal numeric; capped boolean;
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
  -- Rush hour and busy-area pricing together never pass the surge cap
  -- (1.3x of the normal price).
  normal := greatest(minimum, base + per_km * p_km + per_min * p_minutes);
  capped := ride > normal * s.max_surge;
  ride := least(ride, normal * s.max_surge);

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
    'ride', round_fare(ride), 'capped', capped, 'airport_fee', airport, 'airport', airport_name,
    'pickup_km', round(coalesce(pickup_km, 0)::numeric, 1), 'pickup_fee', pickup_fee);
end $$;


-- Prices for every ride type, with availability.
create or replace function quote_all(p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision,
  p_drop_lat double precision default null, p_drop_lng double precision default null)
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(r.id, jsonb_build_object('fare', q.fare, 'surge', q.surge, 'breakdown', q.breakdown,
      'unavailable', ride_type_block(r.id, p_lat, p_lng))), '{}'::jsonb)
  from ride_types r
  cross join lateral quote_fare(r.id, p_km, p_minutes, p_lat, p_lng, p_drop_lat, p_drop_lng) q
  where r.active;
$$;

-- Booking guard: an unavailable ride type can't be requested.
create or replace function trips_before_insert_pay() returns trigger
language plpgsql security definer set search_path = public as $$
declare why text;
begin
  why := ride_type_block(new.ride_type_id, new.pickup_lat, new.pickup_lng);
  if why is not null then raise exception '% is not available right now. %', initcap(new.ride_type_id), why; end if;
  if wallet_balance(new.rider_id) < 0 then
    raise exception 'You have an unpaid balance. Top up your wallet to book again.';
  end if;
  if new.payment = 'card' then
    select id into new.card_id from payment_cards
      where user_id = new.rider_id and authorization_code is not null
      order by is_default desc, created_at desc limit 1;
    if new.card_id is null then raise exception 'Add a card first, or pay with wallet or cash.'; end if;
  end if;
  return new;
end $$;

-- 3. The Paystack fee is paid by the person paying (stored per payment).
alter table paystack_payments add column if not exists fee int not null default 0;

-- Drivers can't go online when their ride type is closed where they are.
create or replace function my_ride_type_block(p_lat double precision, p_lng double precision) returns text
language sql stable security definer set search_path = public as $$
  select ride_type_block(d.ride_type_id, p_lat, p_lng) from drivers d where d.id = auth.uid();
$$;
revoke execute on function my_ride_type_block(double precision, double precision) from anon, public;
grant execute on function my_ride_type_block(double precision, double precision) to authenticated;

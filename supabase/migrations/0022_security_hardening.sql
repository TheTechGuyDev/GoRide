-- Security hardening before public launch:
-- 1. Fares can't be cheated by a tampered client understating distance/time.
-- 2. Riders can no longer scrape every online driver's exact live location.
-- 3. public_config no longer exposes the SMTP email and server details.

-- ---------- 1. Fare integrity ----------
-- Road distance is always at least the straight-line distance between pickup
-- and drop-off, so the charged distance is floored to that. Time is floored
-- from the distance. Honest trips (real OSRM distance/time) are unchanged.
create or replace function quote_fare(p_ride_type text, p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision,
  p_drop_lat double precision default null, p_drop_lng double precision default null)
returns table (fare int, surge numeric, breakdown jsonb)
language plpgsql stable security definer set search_path = public as $$
declare rt ride_types; cr city_rates; s app_settings := settings();
  v_city text; base numeric; per_km numeric; per_min numeric; minimum numeric;
  v_km numeric; v_straight numeric; m0 numeric; minutes numeric; rush boolean;
  sg numeric; ride numeric; airport int := 0; airport_name text;
  pickup_km double precision; pickup_fee int := 0; pickup_rate int;
  total numeric; normal numeric; capped boolean;
begin
  select * into rt from ride_types where id = p_ride_type and active;
  if not found then raise exception 'Unknown ride type'; end if;
  v_city := city_at(p_lat, p_lng);
  select * into cr from city_rates c where c.city = v_city and c.ride_type_id = p_ride_type;
  base := coalesce(cr.base_fare, rt.base_fare);
  per_km := coalesce(cr.per_km, rt.per_km);
  per_min := coalesce(cr.per_minute, rt.per_minute);
  minimum := coalesce(cr.minimum_fare, rt.minimum_fare);

  -- Distance can't be below the straight-line distance, nor negative/absurd.
  v_km := greatest(coalesce(p_km, 0), 0);
  if p_drop_lat is not null and p_drop_lng is not null then
    v_straight := km_between(p_lat, p_lng, p_drop_lat, p_drop_lng);
    v_km := greatest(v_km, round(v_straight::numeric, 2));
  end if;
  v_km := least(v_km, 2000);
  -- Time can't be below the distance (about 1 minute per km) nor negative.
  m0 := greatest(coalesce(p_minutes, 0), 0);
  m0 := greatest(m0, ceil(v_km));

  -- Rush hour: trips take longer in traffic.
  rush := is_rush_hour();
  minutes := case when rush then round(m0 * s.rush_factor) else m0 end;

  -- Surge from busy areas and live demand.
  sg := surge_at(p_lat, p_lng);
  ride := greatest(minimum, base + per_km * v_km + per_min * minutes) * sg;
  -- Rush hour and busy-area pricing together never pass the surge cap.
  normal := greatest(minimum, base + per_km * v_km + per_min * m0);
  capped := ride > normal * s.max_surge;
  ride := least(ride, normal * s.max_surge);

  -- Airport fee (pickup or drop-off at an airport).
  select a.fee, a.name into airport, airport_name from airports a
    where a.active and (km_between(p_lat, p_lng, a.lat, a.lng) * 1000 <= a.radius_m
      or (p_drop_lat is not null and km_between(p_drop_lat, p_drop_lng, a.lat, a.lng) * 1000 <= a.radius_m))
    order by a.fee desc limit 1;
  airport := coalesce(airport, 0);

  -- Long pickup: only when the nearest driver is far away.
  pickup_km := nearest_driver_km(p_ride_type, p_lat, p_lng);
  if pickup_km is not null and pickup_km > s.free_pickup_km then
    pickup_rate := case rt.kind when 'bike' then s.pickup_fee_per_km / 2 when 'keke' then s.pickup_fee_per_km * 3 / 4
      else s.pickup_fee_per_km end;
    pickup_fee := least(s.max_pickup_fee, round((pickup_km - s.free_pickup_km) * pickup_rate))::int;
  end if;

  total := ride + airport + pickup_fee;
  return query select round_fare(total), sg, jsonb_build_object(
    'city', coalesce(v_city, 'Default'), 'base', base, 'per_km', per_km, 'per_minute', per_min,
    'km', v_km, 'minutes', minutes, 'rush_hour', rush, 'surge', sg,
    'ride', round_fare(ride), 'capped', capped, 'airport_fee', airport, 'airport', airport_name,
    'pickup_km', round(coalesce(pickup_km, 0)::numeric, 1), 'pickup_fee', pickup_fee);
end $$;

-- ---------- 2. Driver location privacy ----------
-- Before: any signed-in user could read every online driver's exact GPS and id.
-- Now: staff see all; a rider sees only the driver on their own active trip
-- (for live tracking); the home-map "cars nearby" uses an anonymized RPC.
drop policy if exists loc_read on driver_locations;
create policy loc_read_staff on driver_locations for select using (is_staff());
create policy loc_read_mytrip on driver_locations for select using (
  exists (select 1 from trips t
    where t.driver_id = driver_locations.driver_id
      and t.rider_id = auth.uid()
      and t.status in ('accepted', 'arrived', 'on_trip')));

-- Anonymized nearby pins for the map: no driver id, position snapped to about
-- 100 m, so a specific driver can't be tracked. Only drivers seen in the last
-- 2 minutes, within 5 km, matching the ride type.
create or replace function nearby_drivers(p_ride_type text, p_lat double precision, p_lng double precision)
returns table (lat double precision, lng double precision, heading numeric, ride_type_id text)
language sql stable security definer set search_path = public as $$
  select round(l.lat::numeric, 3)::double precision,
         round(l.lng::numeric, 3)::double precision,
         round(coalesce(l.heading, 0)::numeric, 0),
         l.ride_type_id
  from driver_locations l
  where l.online and not l.on_trip
    and l.updated_at > now() - interval '2 minutes'
    and km_between(p_lat, p_lng, l.lat, l.lng) <= 5
    and (p_ride_type is null or l.ride_type_id = p_ride_type
      or (p_ride_type = 'car' and l.ride_type_id in ('comfort', 'xl')))
  order by km_between(p_lat, p_lng, l.lat, l.lng)
  limit 20;
$$;
revoke execute on function nearby_drivers(text, double precision, double precision) from anon, public;
grant execute on function nearby_drivers(text, double precision, double precision) to authenticated;

-- ---------- 3. public_config: only client-safe keys ----------
-- Removes the SMTP email and server host/port from the public endpoint.
create or replace function public_config() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from integration_settings
  where not is_secret and value is not null
    and key in ('map_tile_url', 'vapid_public_key', 'paystack_public_key', 'google_client_id');
$$;

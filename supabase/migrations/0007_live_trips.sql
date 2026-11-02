-- Live trips: PIN hidden from drivers, party lookups, more realtime.

-- Drivers must not read the PIN; riders get it through trip_pin().
revoke select on trips from authenticated;
grant select (id, code, rider_id, driver_id, ride_type_id, status, pickup_address, pickup_lat, pickup_lng,
  dropoff_address, dropoff_lat, dropoff_lng, stops, route, distance_km, duration_min, surge, fare, discount,
  promo_code, waiting_fee, total_fare, commission, driver_earning, payment, scheduled_for, requested_at,
  accepted_at, arrived_at, started_at, completed_at, cancelled_at, cancelled_by, cancel_reason, refunded)
  on trips to authenticated;

create or replace function trip_pin(p_trip uuid) returns text
language sql stable security definer set search_path = public as $$
  select pin from trips where id = p_trip and (rider_id = auth.uid() or is_staff());
$$;

-- What the rider sees about their driver.
create or replace function trip_driver(p_trip uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', d.id, 'name', p.full_name, 'rating', p.rating, 'avatar_url', p.avatar_url,
    'phone', '+234 *** *** ' || right(coalesce(p.phone, '0000'), 4),
    'trips', (select count(*) from trips x where x.driver_id = d.id and x.status = 'completed'),
    'member_since', coalesce(d.approved_at, d.created_at),
    'make', d.make, 'model', d.model, 'color', d.color, 'plate', d.plate)
  from trips t join drivers d on d.id = t.driver_id join profiles p on p.id = d.id
  where t.id = p_trip and (t.rider_id = auth.uid() or is_staff());
$$;

-- What the driver sees about their rider (and what a driver sees on a request).
create or replace function trip_rider(p_trip uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'name', p.full_name, 'rating', p.rating, 'avatar_url', p.avatar_url,
    'phone', '+234 *** *** ' || right(coalesce(p.phone, '0000'), 4),
    'trips', (select count(*) from trips x where x.rider_id = p.id and x.status = 'completed'))
  from trips t join profiles p on p.id = t.rider_id
  where t.id = p_trip and (t.driver_id = auth.uid()
    or (t.status = 'requested' and is_driver()) or is_staff());
$$;

revoke execute on function trip_pin(uuid) from anon, public;
revoke execute on function trip_driver(uuid) from anon, public;
revoke execute on function trip_rider(uuid) from anon, public;
grant execute on function trip_pin(uuid), trip_driver(uuid), trip_rider(uuid) to authenticated;

alter publication supabase_realtime add table wallet_transactions, payouts, drivers, driver_documents;

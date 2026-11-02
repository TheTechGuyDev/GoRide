create or replace function my_driver_trips(p_days int default 90) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'requested_at' desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'id', t.id, 'code', t.code, 'status', t.status, 'requested_at', t.requested_at,
      'completed_at', t.completed_at, 'cancelled_at', t.cancelled_at, 'cancel_reason', t.cancel_reason,
      'pickup_address', t.pickup_address, 'dropoff_address', t.dropoff_address,
      'ride_type_id', t.ride_type_id, 'distance_km', t.distance_km, 'duration_min', t.duration_min,
      'fare', t.fare, 'waiting_fee', t.waiting_fee, 'commission', coalesce(t.commission, 0),
      'payment', t.payment, 'rider_name', p.full_name,
      'rider_stars', rr.stars, 'rider_comment', rr.comment, 'tip', coalesce(rr.tip, 0),
      'driver_stars', dr.stars) as x
    from trips t
    join profiles p on p.id = t.rider_id
    left join trip_ratings rr on rr.trip_id = t.id and rr.from_role = 'rider'
    left join trip_ratings dr on dr.trip_id = t.id and dr.from_role = 'driver'
    where t.driver_id = auth.uid() and t.status in ('completed', 'cancelled')
      and t.requested_at > now() - make_interval(days => p_days)
  ) s;
$$;
revoke execute on function my_driver_trips(int) from anon, public;
grant execute on function my_driver_trips(int) to authenticated;

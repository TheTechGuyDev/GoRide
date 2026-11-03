-- Rider's trip history with driver details and their own rating, in one call.
create or replace function my_rides(p_limit int default 50) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(x order by x->>'requested_at' desc), '[]'::jsonb) from (
    select to_jsonb(t) - 'pin' || jsonb_build_object(
      'driver', case when d.id is null then null else jsonb_build_object(
        'id', d.id, 'name', p.full_name, 'rating', p.rating, 'avatar_url', p.avatar_url,
        'phone', '+234 *** *** ' || right(coalesce(p.phone, '0000'), 4),
        'trips', (select count(*) from trips z where z.driver_id = d.id and z.status = 'completed'),
        'member_since', coalesce(d.approved_at, d.created_at),
        'make', d.make, 'model', d.model, 'color', d.color, 'plate', d.plate) end,
      'my_rating', r.stars, 'my_tags', r.tags, 'my_tip', r.tip) as x
    from trips t
    left join drivers d on d.id = t.driver_id
    left join profiles p on p.id = d.id
    left join trip_ratings r on r.trip_id = t.id and r.from_role = 'rider'
    where t.rider_id = auth.uid() and t.status in ('completed', 'cancelled')
    order by t.requested_at desc limit p_limit
  ) s;
$$;
revoke execute on function my_rides(int) from anon, public;
grant execute on function my_rides(int) to authenticated;

-- The rider's trip that is still running (to resume after the app reopens).
create or replace function my_active_trip() returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(t) from trips t
  where t.rider_id = auth.uid() and t.status in ('requested', 'accepted', 'arrived', 'on_trip')
  order by t.requested_at desc limit 1;
$$;
revoke execute on function my_active_trip() from anon, public;
grant execute on function my_active_trip() to authenticated;

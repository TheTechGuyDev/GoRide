-- Power Driver days: on any day a driver completes 20+ trips, commission for
-- that whole day drops from 10% to 7%. The earlier trips of the day are
-- refunded the difference when the 20th trip ends. Never below 7%, so GoRide
-- still earns on every trip.

alter table app_settings
  add column if not exists power_driver_enabled boolean not null default true,
  add column if not exists power_driver_trips int not null default 20 check (power_driver_trips >= 5),
  add column if not exists power_driver_rate numeric not null default 7 check (power_driver_rate between 5 and 10);

-- Trips the driver completed today (Nigeria time).
create or replace function trips_today(p_driver uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from trips
  where driver_id = p_driver and status = 'completed'
    and (completed_at at time zone 'Africa/Lagos')::date = (now() at time zone 'Africa/Lagos')::date;
$$;
revoke execute on function trips_today(uuid) from anon, public, authenticated;

create or replace function complete_trip(p_trip uuid) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips; d drivers; s app_settings := settings(); total int; comm int; gross int;
  done_today int; refund int := 0;
begin
  select * into t from trips where id = p_trip and driver_id = auth.uid() and status = 'on_trip' for update;
  if t.id is null then raise exception 'Trip not found'; end if;
  select * into d from drivers where id = t.driver_id;

  total := t.fare - t.discount + t.waiting_fee;           -- what the rider pays
  gross := t.fare + t.waiting_fee;
  comm := commission_for(d, gross);                        -- GoRide funds the promo discount

  -- Power Driver day: lower rate from the target trip onwards.
  done_today := trips_today(d.id);                         -- before this trip
  if s.power_driver_enabled and comm > 0 and done_today + 1 >= s.power_driver_trips then
    comm := round(gross * s.power_driver_rate / 100.0)::int;
    if done_today + 1 = s.power_driver_trips then
      select coalesce(sum(x.commission - round((x.fare + x.waiting_fee) * s.power_driver_rate / 100.0)), 0)::int
        into refund from trips x
        where x.driver_id = d.id and x.status = 'completed' and x.commission > 0
          and (x.completed_at at time zone 'Africa/Lagos')::date = (now() at time zone 'Africa/Lagos')::date;
    end if;
  end if;

  update trips set status = 'completed', completed_at = now(), total_fare = total,
    commission = comm, driver_earning = gross - comm
    where id = p_trip returning * into t;

  if t.payment = 'cash' then
    if comm > 0 then perform post_tx(d.id, -comm, 'commission', 'Commission on cash trip ' || t.code, t.id); end if;
    if t.discount > 0 then perform post_tx(d.id, t.discount, 'adjustment', 'Promo paid by GoRide, trip ' || t.code, t.id); end if;
  else
    perform post_tx(t.rider_id, -total, 'trip_fare', 'Trip ' || t.code, t.id);
    perform post_tx(d.id, gross - comm, 'trip_earning', 'Trip ' || t.code, t.id);
  end if;

  if refund > 0 then
    perform post_tx(d.id, refund, 'bonus', 'Power Driver day: commission refund', t.id);
  end if;
  if s.power_driver_enabled and done_today + 1 = s.power_driver_trips and commission_for(d, 100) > 0 then
    perform notify(d.id, 'earnings', 'Power Driver day unlocked',
      'You hit ' || s.power_driver_trips || ' trips today. Commission is now ' || s.power_driver_rate || '% for the rest of today'
      || case when refund > 0 then ', and ' || refund || ' naira was refunded to your wallet.' else '.' end);
  end if;

  if t.promo_code is not null then
    insert into promo_redemptions (code, user_id, trip_id, amount) values (t.promo_code, t.rider_id, t.id, t.discount);
    update promos set used = used + 1 where code = t.promo_code;
  end if;

  update driver_locations set on_trip = false where driver_id = d.id;
  perform notify(t.rider_id, 'trips', 'Trip completed', 'You paid ' || total || ' naira. Rate your driver.', jsonb_build_object('trip_id', t.id));
  return t;
end $$;

-- Driver dashboard: add today's trips and the Power Driver target.
create or replace function my_driver_summary() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'balance', wallet_balance(auth.uid()),
    'rating', (select rating from profiles where id = auth.uid()),
    'trips', (select count(*) from trips where driver_id = auth.uid() and status = 'completed'),
    'accepted_7d', (select count(*) from trips where driver_id = auth.uid() and accepted_at > now() - interval '7 days'),
    'cancelled_7d', (select count(*) from trips where driver_id = auth.uid() and cancelled_by = 'driver' and cancelled_at > now() - interval '7 days'),
    'today_trips', trips_today(auth.uid()),
    'power_enabled', s.power_driver_enabled,
    'power_trips', s.power_driver_trips,
    'power_rate', s.power_driver_rate,
    'commission_rate', s.commission_rate)
  from app_settings s where s.id = 1;
$$;
revoke execute on function my_driver_summary() from anon, public;
grant execute on function my_driver_summary() to authenticated;

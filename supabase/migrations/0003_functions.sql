-- Business rules live here so no app can bend them: fares, commission, wallets, payouts.

-- ---------- guards on protected columns ----------
create or replace function guard_profile_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if is_staff() or current_setting('goride.system', true) = 'on' then return new; end if;
  if new.role is distinct from old.role or new.rating is distinct from old.rating
     or new.rating_count is distinct from old.rating_count or new.blocked is distinct from old.blocked
     or new.referral_code is distinct from old.referral_code or new.phone is distinct from old.phone
     or (old.referred_by is not null and new.referred_by is distinct from old.referred_by) then
    raise exception 'You cannot change that field';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on profiles;
create trigger profiles_guard before update on profiles for each row execute function guard_profile_update();

create or replace function guard_driver_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if is_staff() or current_setting('goride.system', true) = 'on' then return new; end if;
  if new.plan is distinct from old.plan or new.plan_period is distinct from old.plan_period
     or new.paid_until is distinct from old.paid_until
     or new.commission_free_until is distinct from old.commission_free_until
     or new.approved_at is distinct from old.approved_at
     or new.rejection_note is distinct from old.rejection_note
     or new.status not in ('draft', 'pending') then
    raise exception 'You cannot change that field';
  end if;
  if new.status = 'pending' and old.status <> 'pending' then new.submitted_at := now(); end if;
  return new;
end $$;
drop trigger if exists drivers_guard on drivers;
create trigger drivers_guard before update on drivers for each row execute function guard_driver_update();

create or replace function guard_doc_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if is_staff() then new.updated_at := now(); return new; end if;
  new.status := 'pending'; new.note := null; new.reviewed_by := null; new.updated_at := now();
  return new;
end $$;
drop trigger if exists docs_guard on driver_documents;
create trigger docs_guard before insert or update on driver_documents for each row execute function guard_doc_update();

-- Card authorization codes never leave the server.
revoke select on payment_cards from anon, authenticated;
grant select (id, user_id, brand, last4, exp, is_default, created_at) on payment_cards to authenticated;
revoke update on payment_cards from anon, authenticated;
grant update (is_default) on payment_cards to authenticated;

-- ---------- helpers ----------
create or replace function settings() returns app_settings
language sql stable security definer set search_path = public as $$ select * from app_settings where id = 1 $$;

create or replace function wallet_balance(uid uuid default auth.uid()) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::int from wallet_transactions where user_id = uid;
$$;

create or replace function post_tx(uid uuid, amt int, k tx_kind, t text, trip uuid default null, ref text default null)
returns void language sql security definer set search_path = public as $$
  insert into wallet_transactions (user_id, amount, kind, title, trip_id, reference) values (uid, amt, k, t, trip, ref);
$$;
revoke execute on function post_tx from public, anon, authenticated;

create or replace function notify(uid uuid, cat text, t text, b text, d jsonb default null)
returns void language sql security definer set search_path = public as $$
  insert into notifications (user_id, category, title, body, data) values (uid, cat, t, b, d);
$$;
revoke execute on function notify from public, anon, authenticated;

create or replace function audit(what text) returns void
language sql security definer set search_path = public as $$
  insert into audit_log (staff_id, action) values (auth.uid(), what);
$$;
revoke execute on function audit from public, anon, authenticated;

create or replace function round_fare(x numeric) returns int
language sql immutable as $$ select (round(x / 50.0) * 50)::int $$;

-- Busy-area multiplier at a point, never above the cap.
create or replace function surge_at(p_lat double precision, p_lng double precision) returns numeric
language sql stable security definer set search_path = public as $$
  select case when not s.surge_enabled then 1 else
    least(s.max_surge, coalesce((
      select max(z.multiplier) from demand_zones z
      where z.active and
        6371000 * 2 * asin(sqrt(power(sin(radians(z.lat - p_lat) / 2), 2)
          + cos(radians(p_lat)) * cos(radians(z.lat)) * power(sin(radians(z.lng - p_lng) / 2), 2))) <= z.radius_m
    ), 1)) end
  from app_settings s where s.id = 1;
$$;

-- Fare = base + per km + per minute, at least the minimum, times surge.
create or replace function quote_fare(p_ride_type text, p_km numeric, p_minutes numeric,
  p_lat double precision, p_lng double precision)
returns table (fare int, surge numeric)
language plpgsql stable security definer set search_path = public as $$
declare rt ride_types; s numeric;
begin
  select * into rt from ride_types where id = p_ride_type and active;
  if not found then raise exception 'Unknown ride type'; end if;
  s := surge_at(p_lat, p_lng);
  return query select round_fare(greatest(rt.minimum_fare, rt.base_fare + rt.per_km * p_km + rt.per_minute * p_minutes) * s), s;
end $$;

-- What GoRide keeps from a driver's fare right now.
create or replace function commission_for(d drivers, amount int) returns int
language sql stable security definer set search_path = public as $$
  select case
    when d.plan = 'subscription' and d.paid_until > now() then 0
    when d.commission_free_until > now() then 0
    else round(amount * (select commission_rate from app_settings where id = 1) / 100.0)::int
  end;
$$;

-- ---------- rider: request a trip ----------
create or replace function request_trip(
  p_ride_type text,
  p_pickup_address text, p_pickup_lat double precision, p_pickup_lng double precision,
  p_dropoff_address text, p_dropoff_lat double precision, p_dropoff_lng double precision,
  p_km numeric, p_minutes numeric,
  p_payment pay_method default 'wallet',
  p_promo text default null,
  p_scheduled_for timestamptz default null,
  p_stops jsonb default '[]',
  p_route jsonb default null)
returns trips language plpgsql security definer set search_path = public as $$
declare q record; pr promos; disc int := 0; t trips; me profiles;
begin
  select * into me from profiles where id = auth.uid();
  if me.id is null then raise exception 'Not signed in'; end if;
  if me.blocked then raise exception 'Your account is on hold. Contact support.'; end if;
  if exists (select 1 from trips where rider_id = me.id and status in ('requested', 'accepted', 'arrived', 'on_trip')) then
    raise exception 'You already have a trip in progress';
  end if;

  select * into q from quote_fare(p_ride_type, p_km, p_minutes, p_pickup_lat, p_pickup_lng);

  if p_promo is not null and p_promo <> '' then
    select * into pr from promos where code = upper(p_promo) and active
      and starts_at <= now() and (ends_at is null or ends_at > now())
      and (usage_limit is null or used < usage_limit)
      and (ride_type_id is null or ride_type_id = p_ride_type);
    if pr.code is null then raise exception 'Invalid promo code'; end if;
    if q.fare < pr.min_spend then raise exception 'This code needs a fare of at least %', pr.min_spend; end if;
    if pr.new_riders_only and exists (select 1 from trips where rider_id = me.id and status = 'completed') then
      raise exception 'This code is for new riders only';
    end if;
    if (select count(*) from promo_redemptions where code = pr.code and user_id = me.id) >= pr.per_user_limit then
      raise exception 'You have already used this code';
    end if;
    disc := least(pr.max_off, round(q.fare * pr.percent_off / 100.0)::int);
  end if;

  if p_payment = 'wallet' and wallet_balance(me.id) < q.fare - disc then
    raise exception 'Not enough in your wallet. Top up or pay another way.';
  end if;

  insert into trips (rider_id, ride_type_id, status, pickup_address, pickup_lat, pickup_lng,
    dropoff_address, dropoff_lat, dropoff_lng, stops, route, distance_km, duration_min,
    surge, fare, discount, promo_code, payment, scheduled_for)
  values (me.id, p_ride_type, (case when p_scheduled_for is null then 'requested' else 'scheduled' end)::trip_status,
    p_pickup_address, p_pickup_lat, p_pickup_lng, p_dropoff_address, p_dropoff_lat, p_dropoff_lng,
    p_stops, p_route, p_km, p_minutes, q.surge, q.fare, disc, pr.code, p_payment, p_scheduled_for)
  returning * into t;
  return t;
end $$;

-- ---------- driver: accept, arrive, start, complete ----------
create or replace function accept_trip(p_trip uuid) returns trips
language plpgsql security definer set search_path = public as $$
declare d drivers; t trips; s app_settings := settings();
begin
  select * into d from drivers where id = auth.uid() and status = 'approved';
  if d.id is null then raise exception 'Your driver account is not active'; end if;
  if d.plan = 'subscription' and (d.paid_until is null or d.paid_until < now()) then
    raise exception 'Your subscription has ended. Renew it or switch to commission.';
  end if;
  if wallet_balance(d.id) < -s.debt_limit then
    raise exception 'Settle your commission balance before taking trips';
  end if;
  if exists (select 1 from trips where driver_id = d.id and status in ('accepted', 'arrived', 'on_trip')) then
    raise exception 'Finish your current trip first';
  end if;
  update trips set driver_id = d.id, status = 'accepted', accepted_at = now()
    where id = p_trip and status = 'requested' and driver_id is null
      and (ride_type_id = d.ride_type_id
        or (ride_type_id = 'car' and d.ride_type_id in ('comfort', 'xl')))
    returning * into t;
  if t.id is null then raise exception 'This request is no longer available'; end if;
  update driver_locations set on_trip = true where driver_id = d.id;
  perform notify(t.rider_id, 'trips', 'Driver on the way', 'Your driver accepted the trip.', jsonb_build_object('trip_id', t.id));
  return t;
end $$;

create or replace function driver_arrived(p_trip uuid) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips;
begin
  update trips set status = 'arrived', arrived_at = now()
    where id = p_trip and driver_id = auth.uid() and status = 'accepted' returning * into t;
  if t.id is null then raise exception 'Trip not found'; end if;
  perform notify(t.rider_id, 'trips', 'Your driver has arrived', 'Share your 4-digit PIN to start the trip.', jsonb_build_object('trip_id', t.id));
  return t;
end $$;

create or replace function start_trip(p_trip uuid, p_pin text) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips; s app_settings := settings(); waited numeric;
begin
  select * into t from trips where id = p_trip and driver_id = auth.uid() and status = 'arrived';
  if t.id is null then raise exception 'Trip not found'; end if;
  if t.pin <> p_pin then raise exception 'Wrong PIN. Ask the rider again.'; end if;
  waited := extract(epoch from now() - t.arrived_at) / 60;
  update trips set status = 'on_trip', started_at = now(),
    waiting_fee = greatest(0, floor(waited - s.waiting_free_minutes))::int * s.waiting_fee_per_minute
    where id = p_trip returning * into t;
  return t;
end $$;

-- Ends the trip and moves the money in one transaction.
create or replace function complete_trip(p_trip uuid) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips; d drivers; total int; comm int;
begin
  select * into t from trips where id = p_trip and driver_id = auth.uid() and status = 'on_trip' for update;
  if t.id is null then raise exception 'Trip not found'; end if;
  select * into d from drivers where id = t.driver_id;

  total := t.fare - t.discount + t.waiting_fee;           -- what the rider pays
  comm := commission_for(d, t.fare + t.waiting_fee);       -- driver pays commission on the full fare;
                                                           -- GoRide funds the promo discount
  update trips set status = 'completed', completed_at = now(), total_fare = total,
    commission = comm, driver_earning = t.fare + t.waiting_fee - comm
    where id = p_trip returning * into t;

  if t.payment = 'cash' then
    -- Driver collected cash: GoRide takes its commission from the driver wallet,
    -- and gives back the promo discount the rider did not pay.
    if comm > 0 then perform post_tx(d.id, -comm, 'commission', 'Commission on cash trip ' || t.code, t.id); end if;
    if t.discount > 0 then perform post_tx(d.id, t.discount, 'adjustment', 'Promo paid by GoRide, trip ' || t.code, t.id); end if;
  else
    perform post_tx(t.rider_id, -total, 'trip_fare', 'Trip ' || t.code, t.id);
    perform post_tx(d.id, t.fare + t.waiting_fee - comm, 'trip_earning', 'Trip ' || t.code, t.id);
  end if;

  if t.promo_code is not null then
    insert into promo_redemptions (code, user_id, trip_id, amount) values (t.promo_code, t.rider_id, t.id, t.discount);
    update promos set used = used + 1 where code = t.promo_code;
  end if;

  update driver_locations set on_trip = false where driver_id = d.id;
  perform notify(t.rider_id, 'trips', 'Trip completed', 'You paid ' || total || ' naira. Rate your driver.', jsonb_build_object('trip_id', t.id));
  return t;
end $$;

-- Rider or driver cancels. A rider who cancels after waiting past the no-show time pays the no-show fee.
create or replace function cancel_trip(p_trip uuid, p_reason text default null) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips; s app_settings := settings(); who text; fee int := 0;
begin
  select * into t from trips where id = p_trip and status in ('scheduled', 'requested', 'accepted', 'arrived') for update;
  if t.id is null then raise exception 'This trip can no longer be cancelled'; end if;
  if t.rider_id = auth.uid() then who := 'rider';
  elsif t.driver_id = auth.uid() then who := 'driver';
  else raise exception 'Not your trip'; end if;

  -- Driver waited at pickup past the no-show time: rider pays the fee to the driver.
  if t.status = 'arrived' and t.arrived_at < now() - make_interval(mins => s.no_show_minutes) then
    fee := s.no_show_fee;
    perform post_tx(t.rider_id, -fee, 'trip_fare', 'No-show fee, trip ' || t.code, t.id);
    perform post_tx(t.driver_id, fee, 'trip_earning', 'No-show fee, trip ' || t.code, t.id);
  end if;

  update trips set status = 'cancelled', cancelled_at = now(), cancelled_by = who, cancel_reason = p_reason,
    total_fare = fee where id = p_trip returning * into t;
  if t.driver_id is not null then update driver_locations set on_trip = false where driver_id = t.driver_id; end if;
  perform notify(case when who = 'rider' then t.driver_id else t.rider_id end, 'trips', 'Trip cancelled',
    'The ' || who || ' cancelled the trip.', jsonb_build_object('trip_id', t.id))
    where (case when who = 'rider' then t.driver_id else t.rider_id end) is not null;
  return t;
end $$;

create or replace function rate_trip(p_trip uuid, p_stars int, p_tags text[] default '{}',
  p_comment text default null, p_tip int default 0) returns void
language plpgsql security definer set search_path = public as $$
declare t trips; role_ user_role; target uuid;
begin
  select * into t from trips where id = p_trip and status = 'completed';
  if t.id is null then raise exception 'Trip not found'; end if;
  if t.rider_id = auth.uid() then role_ := 'rider'; target := t.driver_id;
  elsif t.driver_id = auth.uid() then role_ := 'driver'; target := t.rider_id; p_tip := 0;
  else raise exception 'Not your trip'; end if;
  if p_tip < 0 then raise exception 'Invalid tip'; end if;
  if p_tip > 0 and wallet_balance(auth.uid()) < p_tip then raise exception 'Not enough in your wallet for this tip'; end if;

  perform set_config('goride.system', 'on', true);
  insert into trip_ratings (trip_id, from_role, stars, tags, comment, tip)
    values (p_trip, role_, p_stars, p_tags, p_comment, p_tip);
  update profiles set rating = round(((rating * rating_count) + p_stars) / (rating_count + 1), 2),
    rating_count = rating_count + 1 where id = target;
  perform set_config('goride.system', 'off', true);
  if p_tip > 0 then
    perform post_tx(auth.uid(), -p_tip, 'tip', 'Tip for trip ' || t.code, t.id);
    perform post_tx(target, p_tip, 'tip', 'Tip from rider, trip ' || t.code, t.id);
    perform notify(target, 'earnings', 'You got a tip', 'A rider tipped you ' || p_tip || ' naira.');
  end if;
end $$;

-- ---------- driver: plans, payouts ----------
create or replace function pay_subscription(p_period plan_period) returns drivers
language plpgsql security definer set search_path = public as $$
declare d drivers; price int; k vehicle_kind; start_ timestamptz; len interval;
begin
  select * into d from drivers where id = auth.uid() and status = 'approved';
  if d.id is null then raise exception 'Your driver account is not active'; end if;
  select rt.kind into k from ride_types rt where rt.id = d.ride_type_id;
  select case p_period when 'daily' then daily when 'weekly' then weekly else monthly end
    into price from plan_prices where kind = k;
  if wallet_balance(d.id) < price then raise exception 'Not enough in your wallet'; end if;
  len := case p_period when 'daily' then interval '1 day' when 'weekly' then interval '7 days' else interval '30 days' end;
  start_ := case when d.plan = 'subscription' and d.plan_period = p_period and d.paid_until > now()
    then d.paid_until else now() end;
  perform post_tx(d.id, -price, 'subscription', initcap(p_period::text) || ' subscription');
  insert into subscription_payments (driver_id, period, amount, starts_at, ends_at)
    values (d.id, p_period, price, start_, start_ + len);
  perform set_config('goride.system', 'on', true);
  update drivers set plan = 'subscription', plan_period = p_period, paid_until = start_ + len
    where id = d.id returning * into d;
  perform set_config('goride.system', 'off', true);
  return d;
end $$;

create or replace function switch_to_commission() returns drivers
language plpgsql security definer set search_path = public as $$
declare d drivers;
begin
  select * into d from drivers where id = auth.uid();
  if d.plan = 'subscription' and d.paid_until > now() then
    raise exception 'You can switch when your paid subscription ends';
  end if;
  perform set_config('goride.system', 'on', true);
  update drivers set plan = 'commission' where id = auth.uid() returning * into d;
  perform set_config('goride.system', 'off', true);
  return d;
end $$;

-- Money is taken from the wallet when the request is made, so it cannot be spent twice.
create or replace function request_payout(p_amount int) returns payouts
language plpgsql security definer set search_path = public as $$
declare d drivers; p payouts; s app_settings := settings();
begin
  select * into d from drivers where id = auth.uid() and status = 'approved';
  if d.id is null then raise exception 'Your driver account is not active'; end if;
  if d.account_number is null then raise exception 'Add your bank account first'; end if;
  if p_amount < s.min_payout then raise exception 'The minimum payout is % naira', s.min_payout; end if;
  if wallet_balance(d.id) < p_amount then raise exception 'Not enough in your wallet'; end if;
  insert into payouts (driver_id, amount, bank_name, account_number, account_name)
    values (d.id, p_amount, d.bank_name, d.account_number, d.account_name) returning * into p;
  perform post_tx(d.id, -p_amount, 'payout', 'Payout to ' || d.bank_name);
  return p;
end $$;

-- ---------- rider: SOS ----------
create or replace function raise_sos(p_trip uuid, p_kind safety_kind, p_lat double precision,
  p_lng double precision, p_details text default null) returns safety_events
language plpgsql security definer set search_path = public as $$
declare e safety_events;
begin
  insert into safety_events (kind, trip_id, user_id, lat, lng, details)
    values (p_kind, p_trip, auth.uid(), p_lat, p_lng, p_details) returning * into e;
  return e;
end $$;

-- ---------- staff actions ----------
create or replace function approve_driver(p_driver uuid) returns drivers
language plpgsql security definer set search_path = public as $$
declare d drivers; s app_settings := settings();
begin
  if not is_staff(array['operations']::staff_role[]) then raise exception 'Not allowed'; end if;
  update drivers set status = 'approved', approved_at = now(), rejection_note = null,
    commission_free_until = coalesce(commission_free_until, now() + make_interval(days => s.founding_free_days))
    where id = p_driver returning * into d;
  update driver_documents set status = 'approved', reviewed_by = auth.uid() where driver_id = p_driver and status = 'pending';
  insert into driver_locations (driver_id, ride_type_id) values (p_driver, d.ride_type_id)
    on conflict (driver_id) do update set ride_type_id = excluded.ride_type_id;
  perform notify(p_driver, 'documents', 'You are approved', 'Welcome to GoRide. Your first ' || s.founding_free_days || ' days are commission free.');
  perform audit('Approved driver ' || (select full_name from profiles where id = p_driver));
  return d;
end $$;

create or replace function reject_driver(p_driver uuid, p_note text) returns drivers
language plpgsql security definer set search_path = public as $$
declare d drivers;
begin
  if not is_staff(array['operations']::staff_role[]) then raise exception 'Not allowed'; end if;
  update drivers set status = 'rejected', rejection_note = p_note where id = p_driver returning * into d;
  perform notify(p_driver, 'documents', 'Action needed on your application', p_note);
  perform audit('Rejected driver ' || (select full_name from profiles where id = p_driver) || ': ' || p_note);
  return d;
end $$;

create or replace function refund_trip(p_trip uuid, p_amount int, p_reason text) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips;
begin
  if not is_staff(array['finance', 'support']::staff_role[]) then raise exception 'Not allowed'; end if;
  select * into t from trips where id = p_trip for update;
  if p_amount <= 0 or p_amount > coalesce(t.total_fare, 0) - t.refunded then raise exception 'Invalid refund amount'; end if;
  perform post_tx(t.rider_id, p_amount, 'refund', 'Refund for trip ' || t.code || ': ' || p_reason, t.id);
  update trips set refunded = refunded + p_amount where id = p_trip returning * into t;
  perform notify(t.rider_id, 'payments', 'Refund issued', p_amount || ' naira was added to your wallet.');
  perform audit('Refunded ' || p_amount || ' on trip ' || t.code);
  return t;
end $$;

create or replace function set_payout_status(p_payout uuid, p_status payout_status, p_reason text default null) returns payouts
language plpgsql security definer set search_path = public as $$
declare p payouts;
begin
  if not is_staff(array['finance']::staff_role[]) then raise exception 'Not allowed'; end if;
  update payouts set status = p_status, failure_reason = p_reason, processed_by = auth.uid(),
    processed_at = case when p_status in ('paid', 'failed') then now() end
    where id = p_payout and status in ('pending', 'processing') returning * into p;
  if p.id is null then raise exception 'Payout not found or already closed'; end if;
  if p_status = 'failed' then   -- give the money back
    perform post_tx(p.driver_id, p.amount, 'adjustment', 'Payout failed, money returned');
  end if;
  perform notify(p.driver_id, 'earnings', 'Payout ' || p_status, p.amount || ' naira to ' || p.bank_name);
  perform audit('Marked payout of ' || p.amount || ' as ' || p_status);
  return p;
end $$;

-- Manual wallet credit/debit by finance (e.g. bank transfer received). Paystack top-ups come from the webhook.
create or replace function adjust_wallet(p_user uuid, p_amount int, p_title text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff(array['finance']::staff_role[]) then raise exception 'Not allowed'; end if;
  perform post_tx(p_user, p_amount, 'adjustment', p_title);
  perform audit('Wallet adjustment ' || p_amount || ' for ' || (select full_name from profiles where id = p_user) || ': ' || p_title);
end $$;

create or replace function send_broadcast(p_audience text, p_title text, p_body text) returns broadcasts
language plpgsql security definer set search_path = public as $$
declare b broadcasts; n int;
begin
  if not is_staff(array['operations', 'support']::staff_role[]) then raise exception 'Not allowed'; end if;
  insert into notifications (user_id, category, title, body)
    select id, 'updates', p_title, p_body from profiles
    where p_audience = 'everyone' or (p_audience = 'riders' and role = 'rider') or (p_audience = 'drivers' and role = 'driver');
  get diagnostics n = row_count;
  insert into broadcasts (audience, title, body, sent_by, recipients)
    values (p_audience, p_title, p_body, auth.uid(), n) returning * into b;
  perform audit('Sent notification "' || p_title || '" to ' || p_audience);
  return b;
end $$;

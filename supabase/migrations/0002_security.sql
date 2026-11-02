-- Row level security: riders and drivers see only their own data; staff see what their role allows.
-- Money and trip status changes go through the functions in 0003, never direct writes.

create or replace function is_staff(roles staff_role[] default null) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from staff s
    where s.id = auth.uid() and s.active
      and (roles is null or s.role = 'super_admin' or s.role = any(roles))
  );
$$;

create or replace function is_driver() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from drivers d where d.id = auth.uid() and d.status = 'approved');
$$;

-- New sign-up: create the profile (and driver row for the driver app).
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r user_role := coalesce((new.raw_user_meta_data->>'role')::user_role, 'rider');
begin
  insert into profiles (id, role, full_name, phone, email)
  values (new.id, r, coalesce(new.raw_user_meta_data->>'full_name', ''), new.phone, new.email)
  on conflict (id) do nothing;
  if r = 'driver' then
    insert into drivers (id) values (new.id) on conflict (id) do nothing;
  end if;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

alter table profiles enable row level security;
alter table staff enable row level security;
alter table ride_types enable row level security;
alter table plan_prices enable row level security;
alter table app_settings enable row level security;
alter table demand_zones enable row level security;
alter table drivers enable row level security;
alter table driver_documents enable row level security;
alter table driver_locations enable row level security;
alter table trips enable row level security;
alter table trip_ratings enable row level security;
alter table trip_messages enable row level security;
alter table wallet_transactions enable row level security;
alter table payouts enable row level security;
alter table subscription_payments enable row level security;
alter table payment_cards enable row level security;
alter table promos enable row level security;
alter table promo_redemptions enable row level security;
alter table saved_places enable row level security;
alter table emergency_contacts enable row level security;
alter table safety_events enable row level security;
alter table support_tickets enable row level security;
alter table ticket_messages enable row level security;
alter table notifications enable row level security;
alter table broadcasts enable row level security;
alter table audit_log enable row level security;

-- profiles: own row; the other party on a shared trip; staff.
create policy profiles_self on profiles for select using (id = auth.uid() or is_staff());
create policy profiles_trip_party on profiles for select using (
  exists (select 1 from trips t where t.status not in ('completed', 'cancelled')
          and ((t.rider_id = auth.uid() and t.driver_id = profiles.id)
            or (t.driver_id = auth.uid() and t.rider_id = profiles.id))));
create policy profiles_update_self on profiles for update using (id = auth.uid())
  with check (id = auth.uid());
create policy profiles_staff_update on profiles for update using (is_staff(array['operations', 'support']::staff_role[]));

-- staff: staff can see the team; only super admins change it.
create policy staff_read on staff for select using (is_staff());
create policy staff_admin on staff for all using (is_staff(array['super_admin']::staff_role[]));

-- pricing and settings: everyone signed in reads; finance/super admin writes.
create policy ride_types_read on ride_types for select using (true);
create policy ride_types_write on ride_types for all using (is_staff(array['finance']::staff_role[]));
create policy plan_prices_read on plan_prices for select using (true);
create policy plan_prices_write on plan_prices for all using (is_staff(array['finance']::staff_role[]));
create policy settings_read on app_settings for select using (true);
create policy settings_write on app_settings for update using (is_staff(array['finance']::staff_role[]));
create policy zones_read on demand_zones for select using (true);
create policy zones_write on demand_zones for all using (is_staff(array['operations']::staff_role[]));

-- drivers: own row (only registration fields while draft/rejected); riders see their driver; staff.
create policy drivers_self on drivers for select using (id = auth.uid() or is_staff());
create policy drivers_trip_party on drivers for select using (
  exists (select 1 from trips t where t.driver_id = drivers.id and t.rider_id = auth.uid()
          and t.status not in ('completed', 'cancelled')));
create policy drivers_edit_self on drivers for update using (id = auth.uid() and status in ('draft', 'rejected'))
  with check (id = auth.uid() and status in ('draft', 'pending', 'rejected'));
create policy drivers_staff on drivers for update using (is_staff(array['operations']::staff_role[]));

create policy docs_self on driver_documents for select using (driver_id = auth.uid() or is_staff());
create policy docs_insert_self on driver_documents for insert with check (driver_id = auth.uid());
create policy docs_update_self on driver_documents for update using (driver_id = auth.uid() and status <> 'approved');
create policy docs_staff on driver_documents for update using (is_staff(array['operations']::staff_role[]));

-- live locations: the driver writes their own; signed-in riders read online drivers (for the map); staff.
create policy loc_self on driver_locations for all using (driver_id = auth.uid()) with check (driver_id = auth.uid() and is_driver());
create policy loc_read on driver_locations for select using (auth.uid() is not null and (online or is_staff()));

-- trips: rider and driver of the trip; approved drivers see open requests; staff.
create policy trips_party on trips for select using (rider_id = auth.uid() or driver_id = auth.uid() or is_staff());
create policy trips_open on trips for select using (status = 'requested' and driver_id is null and is_driver());
create policy trips_staff on trips for update using (is_staff(array['operations', 'support', 'finance']::staff_role[]));

create policy ratings_party on trip_ratings for select using (
  is_staff() or exists (select 1 from trips t where t.id = trip_id and (t.rider_id = auth.uid() or t.driver_id = auth.uid())));

create policy msgs_party on trip_messages for select using (
  is_staff() or exists (select 1 from trips t where t.id = trip_id and (t.rider_id = auth.uid() or t.driver_id = auth.uid())));
create policy msgs_send on trip_messages for insert with check (
  sender_id = auth.uid() and exists (select 1 from trips t where t.id = trip_id
    and t.status in ('accepted', 'arrived', 'on_trip') and (t.rider_id = auth.uid() or t.driver_id = auth.uid())));

-- money: read your own; staff (finance) read all. Writes only via functions.
create policy tx_self on wallet_transactions for select using (user_id = auth.uid() or is_staff(array['finance', 'support']::staff_role[]));
create policy payouts_self on payouts for select using (driver_id = auth.uid() or is_staff(array['finance']::staff_role[]));
create policy payouts_staff on payouts for update using (is_staff(array['finance']::staff_role[]));
create policy subs_self on subscription_payments for select using (driver_id = auth.uid() or is_staff(array['finance']::staff_role[]));
create policy cards_self on payment_cards for select using (user_id = auth.uid());
create policy cards_delete_self on payment_cards for delete using (user_id = auth.uid());
create policy cards_default_self on payment_cards for update using (user_id = auth.uid());

-- promos: signed-in users read active codes; staff manage.
create policy promos_read on promos for select using (active or is_staff());
create policy promos_write on promos for all using (is_staff(array['operations', 'finance']::staff_role[]));
create policy redemptions_self on promo_redemptions for select using (user_id = auth.uid() or is_staff());

-- rider extras: fully owned by the user.
create policy places_self on saved_places for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy contacts_self on emergency_contacts for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy contacts_safety on emergency_contacts for select using (is_staff(array['safety']::staff_role[]));

-- safety: users raise and read their own; safety team manages.
create policy safety_self on safety_events for select using (user_id = auth.uid() or is_staff(array['safety', 'support']::staff_role[]));
create policy safety_raise on safety_events for insert with check (user_id = auth.uid());
create policy safety_staff on safety_events for update using (is_staff(array['safety']::staff_role[]));

-- support
create policy tickets_self on support_tickets for select using (user_id = auth.uid() or is_staff(array['support', 'safety']::staff_role[]));
create policy tickets_open on support_tickets for insert with check (user_id = auth.uid());
create policy tickets_staff on support_tickets for update using (is_staff(array['support', 'safety']::staff_role[]));
create policy tmsg_read on ticket_messages for select using (
  is_staff(array['support', 'safety']::staff_role[])
  or exists (select 1 from support_tickets t where t.id = ticket_id and t.user_id = auth.uid()));
create policy tmsg_user on ticket_messages for insert with check (
  sender_id = auth.uid() and not from_staff
  and exists (select 1 from support_tickets t where t.id = ticket_id and t.user_id = auth.uid()));
create policy tmsg_staff on ticket_messages for insert with check (
  from_staff and sender_id = auth.uid() and is_staff(array['support', 'safety']::staff_role[]));

-- notifications
create policy notif_self on notifications for select using (user_id = auth.uid());
create policy notif_read_flag on notifications for update using (user_id = auth.uid());
create policy notif_delete on notifications for delete using (user_id = auth.uid());
create policy broadcasts_staff on broadcasts for all using (is_staff(array['operations', 'support']::staff_role[]));

create policy audit_read on audit_log for select using (is_staff(array['super_admin']::staff_role[]));
create policy audit_write on audit_log for insert with check (staff_id = auth.uid() and is_staff());

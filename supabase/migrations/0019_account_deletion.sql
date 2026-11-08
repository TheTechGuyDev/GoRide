-- Account deletion (Google Play rule) and the admin demo-drive switch.

alter table profiles add column if not exists deleted_at timestamptz;
alter table app_settings add column if not exists demo_drive_allowed boolean not null default false;

-- Wipes personal data but keeps trip and money records (needed for
-- accounting and disputes) under an anonymous name. Called by the
-- delete-account server function after it checks the user.
create or replace function anonymize_user(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from trips where (rider_id = p_user or driver_id = p_user)
             and status in ('requested', 'accepted', 'arrived', 'on_trip')) then
    raise exception 'Finish or cancel your current trip first.';
  end if;
  if exists (select 1 from drivers where id = p_user) and wallet_balance(p_user) < 0 then
    raise exception 'Please settle your unpaid commission before deleting your account.';
  end if;
  perform set_config('goride.system', 'on', true);
  update profiles set full_name = 'Deleted user', phone = null, email = null, avatar_url = null,
    gender = null, date_of_birth = null, deleted_at = now() where id = p_user;
  update drivers set status = 'suspended' where id = p_user;
  delete from driver_locations where driver_id = p_user;
  delete from push_subscriptions where user_id = p_user;
  delete from payment_cards where user_id = p_user;
  delete from emergency_contacts where user_id = p_user;
  delete from saved_places where user_id = p_user;
  delete from notifications where user_id = p_user;
  perform set_config('goride.system', 'off', true);
end $$;
revoke execute on function anonymize_user(uuid) from anon, public, authenticated;
grant execute on function anonymize_user(uuid) to service_role;

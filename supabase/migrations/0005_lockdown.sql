-- Signed-out visitors can call nothing; internal helpers are not callable from the apps.

revoke execute on all functions in schema public from anon, public;
alter default privileges in schema public revoke execute on functions from anon, public;

-- Internal only (used inside other functions, triggers or policies by the owner).
revoke execute on function handle_new_user() from authenticated;
revoke execute on function commission_for(drivers, int) from authenticated;
revoke execute on function settings() from authenticated;
revoke execute on function wallet_balance(uuid) from authenticated;
revoke execute on function guard_profile_update() from authenticated;
revoke execute on function guard_driver_update() from authenticated;
revoke execute on function guard_doc_update() from authenticated;

-- A user can only see their own balance.
create or replace function my_balance() returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(amount), 0)::int from wallet_transactions where user_id = auth.uid();
$$;
revoke execute on function my_balance() from anon, public;
grant execute on function my_balance() to authenticated;

alter function round_fare(numeric) set search_path = public;

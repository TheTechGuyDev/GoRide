-- Approved drivers can change their payout bank account.
create or replace function set_bank(p_bank text, p_number text, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_number !~ '^\d{10}$' then raise exception 'Account number must be 10 digits'; end if;
  perform set_config('goride.system', 'on', true);
  update drivers set bank_name = p_bank, account_number = p_number, account_name = p_name where id = auth.uid();
  perform set_config('goride.system', 'off', true);
end $$;
revoke execute on function set_bank(text, text, text) from anon, public;
grant execute on function set_bank(text, text, text) to authenticated;

-- Driver's dashboard numbers in one call.
create or replace function my_driver_summary() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'balance', wallet_balance(auth.uid()),
    'rating', (select rating from profiles where id = auth.uid()),
    'trips', (select count(*) from trips where driver_id = auth.uid() and status = 'completed'),
    'accepted_7d', (select count(*) from trips where driver_id = auth.uid() and accepted_at > now() - interval '7 days'),
    'cancelled_7d', (select count(*) from trips where driver_id = auth.uid() and cancelled_by = 'driver' and cancelled_at > now() - interval '7 days'));
$$;
revoke execute on function my_driver_summary() from anon, public;
grant execute on function my_driver_summary() to authenticated;

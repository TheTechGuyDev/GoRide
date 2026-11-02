-- Phone can be set once by the user (email/Google sign-ups start without one).
create or replace function guard_profile_update() returns trigger
language plpgsql set search_path = public as $$
begin
  if is_staff() or current_setting('goride.system', true) = 'on' then return new; end if;
  if new.role is distinct from old.role or new.rating is distinct from old.rating
     or new.rating_count is distinct from old.rating_count or new.blocked is distinct from old.blocked
     or new.referral_code is distinct from old.referral_code
     or (old.phone is not null and new.phone is distinct from old.phone)
     or (old.referred_by is not null and new.referred_by is distinct from old.referred_by) then
    raise exception 'You cannot change that field';
  end if;
  return new;
end $$;

-- Google sign-ups get their name from Google.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare r user_role := coalesce((new.raw_user_meta_data->>'role')::user_role, 'rider');
begin
  insert into profiles (id, role, full_name, phone, email, avatar_url)
  values (new.id, r,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''),
    nullif(new.phone, ''), new.email, new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  if r = 'driver' then
    insert into drivers (id) values (new.id) on conflict (id) do nothing;
  end if;
  return new;
end $$;

-- Driver app: make sure a signed-in user has a driver record (covers Google sign-ups).
create or replace function become_driver() returns drivers
language plpgsql security definer set search_path = public as $$
declare d drivers;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  insert into drivers (id) values (auth.uid()) on conflict (id) do nothing;
  perform set_config('goride.system', 'on', true);
  update profiles set role = 'driver' where id = auth.uid() and role <> 'driver';
  perform set_config('goride.system', 'off', true);
  select * into d from drivers where id = auth.uid();
  return d;
end $$;
revoke execute on function become_driver() from anon, public;
grant execute on function become_driver() to authenticated;
revoke execute on function handle_new_user() from anon, public, authenticated;

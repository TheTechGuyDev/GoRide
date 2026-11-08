-- Login protection: lock an email after 5 wrong codes, block an IP after
-- many failures, and limit how often codes are sent. Used by the
-- auth-guard server function (sees the real caller IP).
create table if not exists auth_attempts (
  id bigserial primary key,
  email text not null,
  ip text,
  kind text not null,          -- send, fail, success
  at timestamptz not null default now()
);
create index if not exists auth_attempts_email_at on auth_attempts (email, at desc);
create index if not exists auth_attempts_ip_at on auth_attempts (ip, at desc);
alter table auth_attempts enable row level security;   -- server only

-- Returns null when allowed, or a message saying why not.
create or replace function auth_guard(p_email text, p_ip text, p_action text) returns text
language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email)); fails int; ip_fails int; sends int; ip_sends int; last_fail timestamptz;
begin
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return 'Enter a valid email address.'; end if;
  delete from auth_attempts where at < now() - interval '1 day';

  if p_action in ('success', 'fail', 'send') then
    insert into auth_attempts (email, ip, kind) values (e, p_ip, p_action);
    if p_action = 'success' then
      delete from auth_attempts where email = e and kind = 'fail';
    end if;
    return null;
  end if;

  -- Account lockout: 5 wrong codes in 15 minutes locks the email for 15 minutes.
  select count(*), max(at) into fails, last_fail from auth_attempts
    where email = e and kind = 'fail' and at > now() - interval '15 minutes';
  if fails >= 5 then
    return 'Too many wrong codes. For your safety this account is locked for '
      || greatest(1, ceil(extract(epoch from (last_fail + interval '15 minutes' - now())) / 60))::int || ' minutes.';
  end if;

  -- IP limit: many failures from one network (several accounts) blocks it for a while.
  if p_ip is not null then
    select count(*) into ip_fails from auth_attempts
      where ip = p_ip and kind = 'fail' and at > now() - interval '15 minutes';
    if ip_fails >= 30 then return 'Too many attempts from your network. Try again in 15 minutes.'; end if;
  end if;

  if p_action = 'can_send' then
    select count(*) into sends from auth_attempts where email = e and kind = 'send' and at > now() - interval '1 hour';
    if sends >= 5 then return 'You have asked for too many codes. Try again in an hour.'; end if;
    if p_ip is not null then
      select count(*) into ip_sends from auth_attempts where ip = p_ip and kind = 'send' and at > now() - interval '1 hour';
      if ip_sends >= 40 then return 'Too many codes requested from your network. Try again later.'; end if;
    end if;
  end if;
  return null;
end $$;
revoke execute on function auth_guard(text, text, text) from anon, public, authenticated;
grant execute on function auth_guard(text, text, text) to service_role;

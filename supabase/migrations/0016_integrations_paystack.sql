-- Integrations: API keys managed from the admin dashboard.
-- Secret keys are encrypted in Supabase Vault and only server functions can
-- read them. Public keys (safe to ship in apps) are in integration_settings.

create table if not exists integration_settings (
  key text primary key,
  is_secret boolean not null,
  value text,               -- public keys only; null for secrets
  last4 text,               -- shown masked in the dashboard
  updated_at timestamptz not null default now(),
  updated_by uuid references staff
);
alter table integration_settings enable row level security;  -- functions only

create or replace function admin_integrations() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_staff(array['finance']::staff_role[]) then raise exception 'Not allowed'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object(
      'key', i.key, 'secret', i.is_secret, 'value', i.value, 'last4', i.last4,
      'updated_at', i.updated_at, 'updated_by', s.full_name)), '[]')
    from integration_settings i left join staff s on s.id = i.updated_by);
end $$;

create or replace function admin_set_integration(p_key text, p_value text, p_secret boolean)
returns void language plpgsql security definer set search_path = public, vault as $$
declare sid uuid; v text := trim(p_value);
begin
  if not is_staff(array['super_admin']::staff_role[]) then raise exception 'Only a Super Admin can change API keys'; end if;
  if p_key !~ '^[a-z0-9_]{2,60}$' then raise exception 'Invalid key name'; end if;
  if v is null or v = '' then raise exception 'Enter a value'; end if;
  if p_secret then
    select id into sid from vault.secrets where name = 'goride_' || p_key;
    if sid is null then
      perform vault.create_secret(v, 'goride_' || p_key, 'GoRide integration ' || p_key);
    else
      perform vault.update_secret(sid, v);
    end if;
  end if;
  insert into integration_settings (key, is_secret, value, last4, updated_at, updated_by)
  values (p_key, p_secret, case when p_secret then null else v end, right(v, 4), now(), auth.uid())
  on conflict (key) do update set is_secret = excluded.is_secret, value = excluded.value,
    last4 = excluded.last4, updated_at = now(), updated_by = auth.uid();
  perform audit('Updated API key ' || p_key);
end $$;

create or replace function admin_clear_integration(p_key text)
returns void language plpgsql security definer set search_path = public, vault as $$
begin
  if not is_staff(array['super_admin']::staff_role[]) then raise exception 'Only a Super Admin can change API keys'; end if;
  delete from vault.secrets where name = 'goride_' || p_key;
  delete from integration_settings where key = p_key;
  perform audit('Removed API key ' || p_key);
end $$;

-- Public keys the apps may use (Paystack public key, map style).
create or replace function public_config() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from integration_settings where not is_secret and value is not null;
$$;

-- Server functions only (service role): read a decrypted secret.
create or replace function get_secret(p_key text) returns text
language sql stable security definer set search_path = public, vault as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'goride_' || p_key;
$$;

-- ---------- Paystack payments ----------
create table if not exists paystack_payments (
  reference text primary key,
  user_id uuid not null references profiles,
  amount int not null check (amount > 0),
  purpose text not null default 'top_up',
  status text not null default 'pending',   -- pending, success, failed
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
alter table paystack_payments enable row level security;
create policy payments_self on paystack_payments for select
  using (user_id = auth.uid() or is_staff(array['finance']::staff_role[]));

-- Called by the server function after Paystack confirms the payment.
-- Safe to call twice: the Paystack reference can only be credited once.
create or replace function credit_paystack(p_reference text, p_amount_kobo bigint)
returns boolean language plpgsql security definer set search_path = public as $$
declare p paystack_payments; naira int := (p_amount_kobo / 100)::int;
begin
  select * into p from paystack_payments where reference = p_reference for update;
  if p.reference is null or p.status = 'success' then return false; end if;
  if naira < p.amount then raise exception 'Amount paid is less than requested'; end if;
  update paystack_payments set status = 'success', paid_at = now() where reference = p_reference;
  insert into wallet_transactions (user_id, amount, kind, title, reference)
    values (p.user_id, p.amount, 'top_up',
      case when p.purpose = 'settle' then 'Commission settled with Paystack' else 'Wallet top-up (Paystack)' end,
      p_reference)
    on conflict (reference) do nothing;
  perform notify(p.user_id, 'payments', 'Payment received', p.amount || ' naira added to your GoRide wallet.');
  return true;
end $$;

do $$ declare f text; begin
  foreach f in array array['admin_integrations()', 'admin_set_integration(text, text, boolean)',
    'admin_clear_integration(text)'] loop
    execute 'revoke execute on function ' || f || ' from anon, public';
    execute 'grant execute on function ' || f || ' to authenticated';
  end loop;
  foreach f in array array['get_secret(text)', 'credit_paystack(text, bigint)'] loop
    execute 'revoke execute on function ' || f || ' from anon, public, authenticated';
    execute 'grant execute on function ' || f || ' to service_role';
  end loop;
end $$;
grant execute on function public_config() to anon, authenticated;

-- Admin dashboard can see payments.
alter publication supabase_realtime add table paystack_payments;

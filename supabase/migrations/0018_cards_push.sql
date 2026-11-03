-- Saved cards (Paystack authorizations) and push notifications.
create extension if not exists pg_net;

-- ---------- server hook: database -> server functions ----------
-- A random secret proves a call came from our own database.
do $$ begin
  if not exists (select 1 from vault.secrets where name = 'goride_hook_secret') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'goride_hook_secret', 'Database to server function calls');
  end if;
end $$;

create or replace function call_function(p_name text, p_body jsonb) returns void
language plpgsql security definer set search_path = public, vault as $$
declare secret text;
begin
  select decrypted_secret into secret from vault.decrypted_secrets where name = 'goride_hook_secret';
  perform net.http_post(
    url := 'https://xucckoofhmbyrnvvbxii.supabase.co/functions/v1/' || p_name,
    body := p_body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-goride-hook', secret),
    timeout_milliseconds := 15000);
end $$;
revoke execute on function call_function(text, jsonb) from anon, public, authenticated;

-- ---------- saved cards ----------
alter table payment_cards
  add column if not exists signature text,
  add column if not exists bank text,
  add column if not exists email text;
create unique index if not exists payment_cards_user_signature on payment_cards (user_id, signature);
grant select (id, user_id, brand, last4, exp, bank, is_default, created_at) on payment_cards to authenticated;

-- Called by the server after a successful Paystack card payment.
create or replace function save_card(p_user uuid, p_auth jsonb, p_email text) returns void
language plpgsql security definer set search_path = public as $$
declare has_default boolean;
begin
  if coalesce((p_auth->>'reusable')::boolean, false) is false or p_auth->>'channel' <> 'card' then return; end if;
  select exists (select 1 from payment_cards where user_id = p_user and is_default) into has_default;
  insert into payment_cards (user_id, brand, last4, exp, authorization_code, signature, bank, email, is_default)
  values (p_user, initcap(coalesce(trim(p_auth->>'card_type'), 'Card')), p_auth->>'last4',
    (p_auth->>'exp_month') || '/' || right(p_auth->>'exp_year', 2), p_auth->>'authorization_code',
    coalesce(p_auth->>'signature', p_auth->>'authorization_code'), p_auth->>'bank', p_email, not has_default)
  on conflict (user_id, signature) do update set authorization_code = excluded.authorization_code,
    exp = excluded.exp, email = excluded.email;
end $$;
revoke execute on function save_card(uuid, jsonb, text) from anon, public, authenticated;
grant execute on function save_card(uuid, jsonb, text) to service_role;

-- Choose which saved card pays for trips.
create or replace function set_default_card(p_card uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from payment_cards where id = p_card and user_id = auth.uid()) then
    raise exception 'Card not found';
  end if;
  update payment_cards set is_default = (id = p_card) where user_id = auth.uid();
end $$;
revoke execute on function set_default_card(uuid) from anon, public;
grant execute on function set_default_card(uuid) to authenticated;

-- ---------- card trips ----------
alter table trips add column if not exists card_id uuid references payment_cards on delete set null;

create table if not exists card_charges (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid unique references trips on delete set null,
  user_id uuid not null references profiles on delete cascade,
  card_id uuid references payment_cards on delete set null,
  amount int not null check (amount > 0),
  status text not null default 'pending',   -- pending, success, failed
  error text,
  created_at timestamptz not null default now()
);
alter table card_charges enable row level security;
create policy card_charges_self on card_charges for select
  using (user_id = auth.uid() or is_staff(array['finance']::staff_role[]));

-- A card trip uses the rider's default card. Riders who owe money from a
-- failed card payment must clear it before booking again.
create or replace function trips_before_insert_pay() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if wallet_balance(new.rider_id) < 0 then
    raise exception 'You have an unpaid balance. Top up your wallet to book again.';
  end if;
  if new.payment = 'card' then
    select id into new.card_id from payment_cards
      where user_id = new.rider_id and authorization_code is not null
      order by is_default desc, created_at desc limit 1;
    if new.card_id is null then raise exception 'Add a card first, or pay with wallet or cash.'; end if;
  end if;
  return new;
end $$;
drop trigger if exists trips_pay_check on trips;
create trigger trips_pay_check before insert on trips for each row execute function trips_before_insert_pay();

-- When a card trip ends, the fare has been taken from the wallet; the card
-- is then charged to put it back.
create or replace function trips_after_complete_card() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  insert into card_charges (trip_id, user_id, card_id, amount)
    values (new.id, new.rider_id, new.card_id, new.total_fare)
    on conflict (trip_id) do nothing returning id into cid;
  if cid is not null then perform call_function('paystack', jsonb_build_object('action', 'charge_trip', 'charge_id', cid)); end if;
  return new;
end $$;
drop trigger if exists trips_card_charge on trips;
create trigger trips_card_charge after update of status on trips for each row
  when (new.status = 'completed' and old.status is distinct from 'completed' and new.payment = 'card' and new.total_fare > 0)
  execute function trips_after_complete_card();

-- Card payments get their own wallet title.
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
      case p.purpose when 'settle' then 'Commission settled with Paystack'
        when 'card_trip' then 'Trip paid by card'
        when 'add_card' then 'Card added (amount kept in your wallet)'
        else 'Wallet top-up (Paystack)' end,
      p_reference)
    on conflict (reference) do nothing;
  if p.purpose <> 'card_trip' then
    perform notify(p.user_id, 'payments', 'Payment received', p.amount || ' naira added to your GoRide wallet.');
  end if;
  return true;
end $$;
revoke execute on function credit_paystack(text, bigint) from anon, public, authenticated;
grant execute on function credit_paystack(text, bigint) to service_role;

-- ---------- push notifications ----------
create table if not exists push_subscriptions (
  endpoint text primary key,
  user_id uuid not null references profiles on delete cascade,
  p256dh text not null,
  auth text not null,
  app text not null default 'rider',
  created_at timestamptz not null default now()
);
alter table push_subscriptions enable row level security;
create policy push_self_read on push_subscriptions for select using (user_id = auth.uid());
create policy push_self_insert on push_subscriptions for insert with check (user_id = auth.uid());
create policy push_self_update on push_subscriptions for update using (user_id = auth.uid());
create policy push_self_delete on push_subscriptions for delete using (user_id = auth.uid());

-- Every in-app notification is also sent as a phone/browser push.
create or replace function notifications_push() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from push_subscriptions where user_id = new.user_id) then
    perform call_function('push', jsonb_build_object('notification_id', new.id));
  end if;
  return new;
end $$;
drop trigger if exists notifications_push on notifications;
create trigger notifications_push after insert on notifications for each row execute function notifications_push();

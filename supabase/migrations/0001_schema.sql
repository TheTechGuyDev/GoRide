-- GoRide database: one schema shared by the rider app, driver app and admin dashboard.

create extension if not exists pgcrypto;

-- ---------- types ----------
create type user_role as enum ('rider', 'driver');
create type staff_role as enum ('super_admin', 'operations', 'finance', 'safety', 'support');
create type vehicle_kind as enum ('bike', 'keke', 'car');
create type approval_status as enum ('draft', 'pending', 'approved', 'rejected', 'suspended');
create type doc_status as enum ('missing', 'pending', 'approved', 'rejected');
create type plan_type as enum ('commission', 'subscription');
create type plan_period as enum ('daily', 'weekly', 'monthly');
create type trip_status as enum ('scheduled', 'requested', 'accepted', 'arrived', 'on_trip', 'completed', 'cancelled');
create type pay_method as enum ('wallet', 'card', 'cash');
create type tx_kind as enum ('top_up', 'trip_fare', 'trip_earning', 'commission', 'payout', 'subscription', 'refund', 'bonus', 'tip', 'referral', 'adjustment');
create type payout_status as enum ('pending', 'processing', 'paid', 'failed');
create type safety_kind as enum ('sos', 'auto_sos', 'route_deviation', 'report');
create type case_status as enum ('open', 'in_progress', 'resolved');

-- ---------- people ----------
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  role user_role not null default 'rider',
  full_name text not null default '',
  phone text unique,
  email text,
  avatar_url text,
  gender text,
  date_of_birth date,
  language text not null default 'en',
  referral_code text unique default upper(substr(md5(gen_random_uuid()::text), 1, 8)),
  referred_by uuid references profiles,
  rating numeric(3,2) not null default 5.00,
  rating_count int not null default 0,
  blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create table staff (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text not null unique,
  role staff_role not null default 'support',
  active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

-- ---------- pricing (edited from the admin dashboard) ----------
create table ride_types (
  id text primary key,
  name text not null,
  kind vehicle_kind not null,
  passengers int not null,
  base_fare numeric not null,
  per_km numeric not null,
  per_minute numeric not null,
  minimum_fare numeric not null,
  description text not null default '',
  active boolean not null default true,
  sort int not null default 0
);

create table plan_prices (
  kind vehicle_kind primary key,
  daily int not null,
  weekly int not null,
  monthly int not null
);

create table app_settings (
  id int primary key default 1 check (id = 1),
  commission_rate numeric not null default 10,      -- percent
  founding_free_days int not null default 30,
  surge_enabled boolean not null default true,
  max_surge numeric not null default 1.3 check (max_surge between 1 and 1.3),
  debt_limit int not null default 5000,
  min_payout int not null default 2000,
  waiting_free_minutes int not null default 3,
  waiting_fee_per_minute int not null default 30,
  no_show_minutes int not null default 5,
  no_show_fee int not null default 500,
  rider_referral_reward int not null default 500,
  driver_referral_reward int not null default 5000,
  off_route_meters int not null default 300,
  sos_response_seconds int not null default 60,
  maintenance_mode boolean not null default false,
  updated_at timestamptz not null default now()
);

create table demand_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text not null,
  lat double precision not null,
  lng double precision not null,
  radius_m int not null,
  multiplier numeric not null check (multiplier between 1 and 1.3),
  active boolean not null default true
);

-- ---------- drivers ----------
create table drivers (
  id uuid primary key references profiles on delete cascade,
  status approval_status not null default 'draft',
  city text,
  ride_type_id text references ride_types,
  make text, model text, year int, color text, plate text unique,
  plan plan_type not null default 'commission',
  plan_period plan_period not null default 'weekly',
  paid_until timestamptz,
  commission_free_until timestamptz,
  bank_name text, account_number text, account_name text,
  submitted_at timestamptz,
  approved_at timestamptz,
  rejection_note text,
  created_at timestamptz not null default now()
);

create table driver_documents (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers on delete cascade,
  type text not null,               -- licence, nin, vehicle_papers, insurance, road_worthiness, lasdri, vehicle_photo
  number text,
  expiry date,
  file_path text,                   -- storage: driver-docs/<driver_id>/<type>.jpg
  status doc_status not null default 'pending',
  note text,
  reviewed_by uuid references staff,
  updated_at timestamptz not null default now(),
  unique (driver_id, type)
);

-- Live position, written by the driver app every few seconds while online.
create table driver_locations (
  driver_id uuid primary key references drivers on delete cascade,
  online boolean not null default false,
  lat double precision,
  lng double precision,
  heading double precision,
  ride_type_id text references ride_types,
  on_trip boolean not null default false,
  updated_at timestamptz not null default now()
);

-- ---------- trips ----------
create table trips (
  id uuid primary key default gen_random_uuid(),
  code text unique not null default 'GR' || lpad((floor(random() * 1e8))::text, 8, '0'),
  rider_id uuid not null references profiles,
  driver_id uuid references drivers,
  ride_type_id text not null references ride_types,
  status trip_status not null default 'requested',
  pickup_address text not null, pickup_lat double precision not null, pickup_lng double precision not null,
  dropoff_address text not null, dropoff_lat double precision not null, dropoff_lng double precision not null,
  stops jsonb not null default '[]',
  route jsonb,                       -- planned route polyline, for the off-route check
  distance_km numeric not null,
  duration_min numeric not null,
  surge numeric not null default 1,
  fare int not null,                 -- quoted fare incl. surge, before promo
  discount int not null default 0,
  promo_code text,
  waiting_fee int not null default 0,
  total_fare int,                    -- final amount charged
  commission int,
  driver_earning int,
  payment pay_method not null default 'wallet',
  pin text not null default lpad((floor(random() * 10000))::text, 4, '0'),
  scheduled_for timestamptz,
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by text,
  cancel_reason text,
  refunded int not null default 0
);
create index trips_rider_idx on trips (rider_id, requested_at desc);
create index trips_driver_idx on trips (driver_id, requested_at desc);
create index trips_open_idx on trips (status) where status in ('requested', 'scheduled');

create table trip_ratings (
  trip_id uuid not null references trips on delete cascade,
  from_role user_role not null,
  stars int not null check (stars between 1 and 5),
  tags text[] not null default '{}',
  comment text,
  tip int not null default 0,
  created_at timestamptz not null default now(),
  primary key (trip_id, from_role)
);

create table trip_messages (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references trips on delete cascade,
  sender_id uuid not null references profiles,
  body text not null,
  created_at timestamptz not null default now()
);

-- ---------- money ----------
-- Every naira that moves is a row here; a wallet balance is the sum of its rows.
create table wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles,
  amount int not null,               -- + credit, - debit
  kind tx_kind not null,
  title text not null,
  trip_id uuid references trips,
  reference text unique,             -- Paystack reference, for idempotency
  created_at timestamptz not null default now()
);
create index wallet_user_idx on wallet_transactions (user_id, created_at desc);

create view wallet_balances with (security_invoker = true) as
  select user_id, coalesce(sum(amount), 0)::int as balance
  from wallet_transactions group by user_id;

create table payouts (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers,
  amount int not null check (amount > 0),
  bank_name text not null, account_number text not null, account_name text not null,
  status payout_status not null default 'pending',
  reference text unique,
  failure_reason text,
  processed_by uuid references staff,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create table subscription_payments (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references drivers,
  period plan_period not null,
  amount int not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table payment_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  brand text not null, last4 text not null, exp text not null,
  authorization_code text,           -- Paystack reusable authorization (server only)
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

-- ---------- promos ----------
create table promos (
  code text primary key,
  title text not null,
  percent_off int not null check (percent_off between 1 and 100),
  max_off int not null,
  min_spend int not null default 0,
  ride_type_id text references ride_types,
  new_riders_only boolean not null default false,
  usage_limit int,
  per_user_limit int not null default 1,
  used int not null default 0,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true
);

create table promo_redemptions (
  code text not null references promos,
  user_id uuid not null references profiles,
  trip_id uuid references trips,
  amount int not null,
  created_at timestamptz not null default now()
);

-- ---------- rider extras ----------
create table saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  label text not null, address text not null,
  lat double precision not null, lng double precision not null,
  created_at timestamptz not null default now()
);

create table emergency_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  name text not null, phone text not null, relation text,
  created_at timestamptz not null default now()
);

-- ---------- safety and support ----------
create table safety_events (
  id uuid primary key default gen_random_uuid(),
  kind safety_kind not null,
  trip_id uuid references trips,
  user_id uuid not null references profiles,
  lat double precision, lng double precision,
  details text,
  status case_status not null default 'open',
  assigned_to uuid references staff,
  notes text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles,
  trip_id uuid references trips,
  subject text not null,
  category text not null default 'general',
  status case_status not null default 'open',
  assigned_to uuid references staff,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references support_tickets on delete cascade,
  sender_id uuid not null,           -- profile or staff
  from_staff boolean not null default false,
  body text not null,
  created_at timestamptz not null default now()
);

-- ---------- notifications ----------
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles on delete cascade,
  category text not null,
  title text not null,
  body text not null,
  data jsonb,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on notifications (user_id, created_at desc);

create table broadcasts (
  id uuid primary key default gen_random_uuid(),
  audience text not null check (audience in ('riders', 'drivers', 'everyone')),
  title text not null, body text not null,
  sent_by uuid references staff,
  recipients int not null default 0,
  created_at timestamptz not null default now()
);

create table audit_log (
  id bigint generated always as identity primary key,
  staff_id uuid references staff,
  action text not null,
  created_at timestamptz not null default now()
);

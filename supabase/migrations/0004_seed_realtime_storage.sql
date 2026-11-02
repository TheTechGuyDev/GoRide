-- Starting prices, settings and launch-city busy areas; realtime; file storage.

insert into ride_types (id, name, kind, passengers, base_fare, per_km, per_minute, minimum_fare, description, sort) values
  ('bike',    'GoRide Bike',    'bike', 1,  300, 150, 10,  800, 'Fastest through traffic. Helmet provided.', 1),
  ('keke',    'GoRide Keke',    'keke', 3,  350, 170, 10,  800, 'Affordable rides for short trips.', 2),
  ('car',     'GoRide Car',     'car',  4,  800, 300, 20, 2000, 'Everyday rides in a clean, comfortable car.', 3),
  ('comfort', 'GoRide Comfort', 'car',  4, 1000, 350, 25, 2500, 'Newer cars with AC and top-rated drivers.', 4),
  ('xl',      'GoRide XL',      'car',  6, 1300, 420, 30, 3200, 'SUVs and minivans for groups and luggage.', 5);

insert into plan_prices (kind, daily, weekly, monthly) values
  ('bike', 1300, 6500, 24000),
  ('keke', 1300, 6500, 24000),
  ('car',  3000, 15000, 55000);

insert into app_settings (id) values (1);

insert into demand_zones (name, city, lat, lng, radius_m, multiplier) values
  ('UI main gate',          'Ibadan',   7.4443, 3.8995, 900, 1.2),
  ('Dugbe',                 'Ibadan',   7.3891, 3.8810, 900, 1.2),
  ('Unilorin main gate',    'Ilorin',   8.4799, 4.6752, 1000, 1.2),
  ('Post Office, Ilorin',   'Ilorin',   8.4966, 4.5426, 800, 1.1),
  ('FUNAAB gate',           'Abeokuta', 7.2251, 3.4375, 900, 1.2),
  ('Panseke',               'Abeokuta', 7.1557, 3.3602, 800, 1.1);

-- Realtime: apps subscribe to these tables.
alter publication supabase_realtime add table trips, driver_locations, trip_messages, notifications, safety_events, support_tickets, ticket_messages;

-- Storage: driver documents are private; avatars are public.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('driver-docs', 'driver-docs', false, 5242880, array['image/jpeg', 'image/png', 'application/pdf']),
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "drivers upload own docs" on storage.objects for insert to authenticated
  with check (bucket_id = 'driver-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "drivers update own docs" on storage.objects for update to authenticated
  using (bucket_id = 'driver-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "drivers and ops read docs" on storage.objects for select to authenticated
  using (bucket_id = 'driver-docs' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff(array['operations']::public.staff_role[])));

create policy "avatars public read" on storage.objects for select using (bucket_id = 'avatars');
create policy "users upload own avatar" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users replace own avatar" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

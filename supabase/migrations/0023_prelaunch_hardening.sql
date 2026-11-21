-- 0023_prelaunch_hardening.sql
-- Pre-launch hardening.
-- Hide internal business settings (commission rate, debt limit, payout floor)
-- from the public API. The admin dashboard (staff) still reads the full table;
-- the rider and driver apps read only the few non-sensitive fields they need,
-- through a whitelisted function.

-- app_settings is no longer world-readable. Staff keep full read for the dashboard.
drop policy if exists settings_read on app_settings;
create policy settings_read on app_settings for select using (is_staff());

-- The only settings the apps are allowed to see, as a small whitelist.
create or replace function public_app_settings() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'demo_drive_allowed',   demo_drive_allowed,
    'power_driver_enabled', power_driver_enabled,
    'power_driver_trips',   power_driver_trips,
    'power_driver_rate',    power_driver_rate
  )
  from app_settings where id = 1;
$$;
revoke execute on function public_app_settings() from anon, public;
grant execute on function public_app_settings() to authenticated;

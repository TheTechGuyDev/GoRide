-- 0024_advisor_fixes.sql
-- Fixes from the live Supabase Security and Performance advisors.

-- 1. Pin search_path on two helper functions (security advisor: function_search_path_mutable).
alter function public.fmt_time(time without time zone) set search_path = public;
alter function public.km_between(double precision, double precision, double precision, double precision) set search_path = public;

-- 2. Trigger functions must not be callable directly as PostgREST RPCs
--    (security advisor: anon/authenticated SECURITY DEFINER executable).
--    Triggers still fire normally; only direct /rest/v1/rpc calls are removed.
revoke execute on function public.notifications_push() from anon, public, authenticated;
revoke execute on function public.trips_after_complete_card() from anon, public, authenticated;
revoke execute on function public.trips_before_insert_pay() from anon, public, authenticated;

-- 3. Cover every foreign key with an index (performance advisor: unindexed_foreign_keys).
create index if not exists idx_airports_city on public.airports (city);
create index if not exists idx_audit_log_staff_id on public.audit_log (staff_id);
create index if not exists idx_broadcasts_sent_by on public.broadcasts (sent_by);
create index if not exists idx_card_charges_card_id on public.card_charges (card_id);
create index if not exists idx_card_charges_user_id on public.card_charges (user_id);
create index if not exists idx_city_rates_ride_type_id on public.city_rates (ride_type_id);
create index if not exists idx_city_ride_rules_ride_type_id on public.city_ride_rules (ride_type_id);
create index if not exists idx_driver_documents_reviewed_by on public.driver_documents (reviewed_by);
create index if not exists idx_driver_locations_ride_type_id on public.driver_locations (ride_type_id);
create index if not exists idx_drivers_ride_type_id on public.drivers (ride_type_id);
create index if not exists idx_emergency_contacts_user_id on public.emergency_contacts (user_id);
create index if not exists idx_integration_settings_updated_by on public.integration_settings (updated_by);
create index if not exists idx_payouts_driver_id on public.payouts (driver_id);
create index if not exists idx_payouts_processed_by on public.payouts (processed_by);
create index if not exists idx_paystack_payments_user_id on public.paystack_payments (user_id);
create index if not exists idx_profiles_referred_by on public.profiles (referred_by);
create index if not exists idx_promo_redemptions_code on public.promo_redemptions (code);
create index if not exists idx_promo_redemptions_trip_id on public.promo_redemptions (trip_id);
create index if not exists idx_promo_redemptions_user_id on public.promo_redemptions (user_id);
create index if not exists idx_promos_ride_type_id on public.promos (ride_type_id);
create index if not exists idx_push_subscriptions_user_id on public.push_subscriptions (user_id);
create index if not exists idx_safety_events_assigned_to on public.safety_events (assigned_to);
create index if not exists idx_safety_events_trip_id on public.safety_events (trip_id);
create index if not exists idx_safety_events_user_id on public.safety_events (user_id);
create index if not exists idx_saved_places_user_id on public.saved_places (user_id);
create index if not exists idx_staff_invites_invited_by on public.staff_invites (invited_by);
create index if not exists idx_subscription_payments_driver_id on public.subscription_payments (driver_id);
create index if not exists idx_support_tickets_assigned_to on public.support_tickets (assigned_to);
create index if not exists idx_support_tickets_trip_id on public.support_tickets (trip_id);
create index if not exists idx_support_tickets_user_id on public.support_tickets (user_id);
create index if not exists idx_ticket_messages_ticket_id on public.ticket_messages (ticket_id);
create index if not exists idx_trip_messages_sender_id on public.trip_messages (sender_id);
create index if not exists idx_trip_messages_trip_id on public.trip_messages (trip_id);
create index if not exists idx_trips_card_id on public.trips (card_id);
create index if not exists idx_trips_ride_type_id on public.trips (ride_type_id);
create index if not exists idx_wallet_transactions_trip_id on public.wallet_transactions (trip_id);

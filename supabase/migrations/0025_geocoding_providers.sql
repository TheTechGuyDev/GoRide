-- 0025_geocoding_providers.sql
-- Let the apps receive the geocoding provider keys (for address search and
-- map pins) through the existing public config whitelist.
--   geoapify_key : Geoapify API key (free, no card) - the recommended provider.
--   mapbox_token : Mapbox public token (pk...) - optional alternative.
-- Both are client-usable keys (restrict them to your app in the provider's
-- dashboard). Real secrets stay out of this whitelist.
create or replace function public_config() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from integration_settings
  where not is_secret and value is not null
    and key in ('map_tile_url', 'vapid_public_key', 'paystack_public_key',
                'google_client_id', 'geoapify_key', 'mapbox_token');
$$;

# GoRide

Ride-hailing platform for Nigeria. Flutter (iOS + Android), free/open resources only.

## Live preview
https://thetechguydev.github.io/GoRide/  (auto-deploys on every push to `main`)

## Structure
- `rider_app/` – Rider mobile app (Flutter)
- `driver_app/` – Driver mobile app (coming)
- `design/ui-kit/` – Reference UI screens

## Stack (all free)
- Flutter + Riverpod + go_router
- Maps: OpenStreetMap (`flutter_map`), search: Nominatim, routing: OSRM
- Payments: Paystack (test mode)
- Backend: Supabase free tier (added last; mock data until then)

## Run the rider app
```bash
cd rider_app
flutter pub get
flutter run
```

-- 0026_ibadan_rates.sql
-- Ibadan launch pricing. Ibadan had no city_rates row, so it fell back to the
-- high default ride_types rates, which priced ABOVE Bolt (bad for riders).
-- These rates land ~6-8% below Bolt Ibadan across tiers (measured against two
-- live Bolt routes, Nov 2026): riders pay less than Bolt, drivers keep 90%
-- (more than Bolt's ~75-80% take-home), and GoRide keeps its 10% commission.
insert into city_rates (city, ride_type_id, base_fare, per_km, per_minute, minimum_fare) values
  ('Ibadan', 'bike',    300,  80, 10,  600),
  ('Ibadan', 'keke',    350, 110, 10,  700),
  ('Ibadan', 'car',     800, 175, 20, 1500),
  ('Ibadan', 'comfort', 900, 195, 25, 2000),
  ('Ibadan', 'xl',     1000, 245, 30, 2600)
on conflict (city, ride_type_id) do update set
  base_fare    = excluded.base_fare,
  per_km       = excluded.per_km,
  per_minute   = excluded.per_minute,
  minimum_fare = excluded.minimum_fare;

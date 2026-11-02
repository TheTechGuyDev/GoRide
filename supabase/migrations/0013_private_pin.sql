-- The ride PIN lives in its own table that no app can read directly, so it
-- can never reach a driver (not even through live updates).
create table if not exists trip_pins (
  trip_id uuid primary key references trips on delete cascade,
  pin text not null default lpad((floor(random() * 10000))::text, 4, '0')
);
alter table trip_pins enable row level security;  -- no policies: functions only

insert into trip_pins (trip_id, pin) select id, pin from trips on conflict do nothing;

create or replace function make_trip_pin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into trip_pins (trip_id) values (new.id) on conflict do nothing;
  return new;
end $$;
drop trigger if exists trips_make_pin on trips;
create trigger trips_make_pin after insert on trips for each row execute function make_trip_pin();
revoke execute on function make_trip_pin() from anon, public, authenticated;

create or replace function trip_pin(p_trip uuid) returns text
language sql stable security definer set search_path = public as $$
  select p.pin from trip_pins p join trips t on t.id = p.trip_id
  where t.id = p_trip and (t.rider_id = auth.uid() or is_staff());
$$;

create or replace function start_trip(p_trip uuid, p_pin text) returns trips
language plpgsql security definer set search_path = public as $$
declare t trips; s app_settings := settings(); waited numeric;
begin
  select * into t from trips where id = p_trip and driver_id = auth.uid() and status = 'arrived';
  if t.id is null then raise exception 'Trip not found'; end if;
  if (select pin from trip_pins where trip_id = p_trip) is distinct from p_pin then
    raise exception 'Wrong PIN. Ask the rider again.';
  end if;
  waited := extract(epoch from now() - t.arrived_at) / 60;
  update trips set status = 'on_trip', started_at = now(),
    waiting_fee = greatest(0, floor(waited - s.waiting_free_minutes))::int * s.waiting_fee_per_minute
    where id = p_trip returning * into t;
  return t;
end $$;

create or replace function my_active_trip() returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(t) || jsonb_build_object('pin', p.pin) from trips t
  left join trip_pins p on p.trip_id = t.id
  where t.rider_id = auth.uid() and t.status in ('requested', 'accepted', 'arrived', 'on_trip')
  order by t.requested_at desc limit 1;
$$;

alter table trips drop column if exists pin;
grant select on trips to authenticated;

alter table saved_places add column if not exists details text not null default '';
alter table emergency_contacts add column if not exists email text not null default '';

-- Tip after rating (the tip screen comes after the stars).
create or replace function tip_trip(p_trip uuid, p_tip int) returns void
language plpgsql security definer set search_path = public as $$
declare t trips;
begin
  select * into t from trips where id = p_trip and status = 'completed' and rider_id = auth.uid();
  if t.id is null then raise exception 'Trip not found'; end if;
  if p_tip <= 0 or p_tip > 50000 then raise exception 'Invalid tip'; end if;
  if wallet_balance(auth.uid()) < p_tip then raise exception 'Not enough in your wallet for this tip'; end if;
  perform post_tx(auth.uid(), -p_tip, 'tip', 'Tip for trip ' || t.code, t.id);
  perform post_tx(t.driver_id, p_tip, 'tip', 'Tip from rider, trip ' || t.code, t.id);
  update trip_ratings set tip = tip + p_tip where trip_id = p_trip and from_role = 'rider';
  perform notify(t.driver_id, 'earnings', 'You got a tip', 'A rider tipped you ' || p_tip || ' naira.');
end $$;
revoke execute on function tip_trip(uuid, int) from anon, public;
grant execute on function tip_trip(uuid, int) to authenticated;

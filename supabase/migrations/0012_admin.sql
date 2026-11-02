-- Everything the admin dashboard shows, in one call (staff only).
create or replace function admin_snapshot(p_days int default 60) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare since timestamptz := now() - make_interval(days => p_days);
begin
  if not is_staff() then raise exception 'Not allowed'; end if;
  return jsonb_build_object(
    'drivers', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', d.id, 'name', p.full_name, 'phone', p.phone, 'email', p.email, 'city', d.city,
        'ride_type_id', d.ride_type_id, 'vehicle', trim(coalesce(d.color,'') || ' ' || coalesce(d.make,'') || ' ' || coalesce(d.model,'')),
        'plate', d.plate, 'status', d.status, 'plan', d.plan, 'paid_until', d.paid_until,
        'rating', p.rating, 'trips', (select count(*) from trips t where t.driver_id = d.id and t.status = 'completed'),
        'applied_at', coalesce(d.submitted_at, d.created_at), 'approved_at', d.approved_at,
        'online', coalesce(l.online, false), 'last_seen', l.updated_at, 'wallet', wallet_balance(d.id),
        'note', d.rejection_note, 'bank', d.bank_name, 'account', d.account_number,
        'docs', (select coalesce(jsonb_agg(jsonb_build_object('type', x.type, 'number', x.number, 'expiry', x.expiry,
                   'status', x.status, 'note', x.note, 'file', x.file_path) order by x.type), '[]') from driver_documents x where x.driver_id = d.id)
      ) order by d.created_at desc), '[]') from drivers d join profiles p on p.id = d.id
      left join driver_locations l on l.driver_id = d.id where d.status <> 'draft'),
    'riders', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.full_name, 'phone', p.phone, 'email', p.email, 'rating', p.rating,
        'joined', p.created_at, 'blocked', p.blocked, 'wallet', wallet_balance(p.id),
        'trips', (select count(*) from trips t where t.rider_id = p.id and t.status = 'completed'),
        'spent', (select coalesce(sum(t.total_fare - t.refunded), 0) from trips t where t.rider_id = p.id and t.status = 'completed'),
        'contacts', (select count(*) from emergency_contacts c where c.user_id = p.id)
      ) order by p.created_at desc), '[]') from profiles p where p.role = 'rider'),
    'trips', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id, 'code', t.code, 'rider_id', t.rider_id, 'rider', rp.full_name, 'driver_id', t.driver_id, 'driver', dp.full_name,
        'pickup', t.pickup_address, 'dropoff', t.dropoff_address, 'ride_type_id', t.ride_type_id,
        'fare', coalesce(t.total_fare, t.fare - t.discount), 'commission', coalesce(t.commission, 0), 'payment', t.payment,
        'status', t.status, 'cancelled_by', t.cancelled_by, 'date', t.requested_at, 'km', t.distance_km, 'minutes', t.duration_min,
        'refunded', t.refunded, 'rating', (select stars from trip_ratings r where r.trip_id = t.id and r.from_role = 'rider'),
        'route_alert', exists (select 1 from safety_events s where s.trip_id = t.id)
      ) order by t.requested_at desc), '[]') from trips t join profiles rp on rp.id = t.rider_id
      left join profiles dp on dp.id = t.driver_id where t.requested_at > since),
    'payouts', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', o.id, 'driver_id', o.driver_id, 'driver', p.full_name, 'amount', o.amount,
        'bank', o.bank_name || ' •••• ' || right(o.account_number, 4), 'status', o.status,
        'date', o.created_at, 'reference', coalesce(o.reference, ''), 'reason', o.failure_reason
      ) order by o.created_at desc), '[]') from payouts o join profiles p on p.id = o.driver_id),
    'subscriptions', (select coalesce(jsonb_agg(jsonb_build_object(
        'driver', p.full_name, 'period', s.period, 'amount', s.amount, 'date', s.created_at
      ) order by s.created_at desc), '[]') from subscription_payments s join profiles p on p.id = s.driver_id),
    'safety', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', e.id, 'kind', e.kind, 'trip', t.code, 'user_role', u.role, 'rider', rp.full_name, 'driver', dp.full_name,
        'plate', d.plate, 'place', coalesce(t.pickup_address || ' to ' || t.dropoff_address, ''),
        'lat', e.lat, 'lng', e.lng, 'time', e.created_at, 'status', e.status, 'detail', coalesce(e.details, ''),
        'notes', e.notes, 'handled_by', st.full_name,
        'contacts', (select count(*) from emergency_contacts c where c.user_id = e.user_id)
      ) order by e.created_at desc), '[]') from safety_events e join profiles u on u.id = e.user_id
      left join trips t on t.id = e.trip_id left join profiles rp on rp.id = t.rider_id
      left join profiles dp on dp.id = t.driver_id left join drivers d on d.id = t.driver_id
      left join staff st on st.id = e.assigned_to),
    'tickets', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', k.id, 'from', p.full_name, 'driver', p.role = 'driver', 'subject', k.subject, 'category', k.category,
        'status', k.status, 'created', k.created_at, 'trip', t.code, 'assignee', st.full_name,
        'messages', (select coalesce(jsonb_agg(jsonb_build_object('text', m.body, 'staff', m.from_staff, 'time', m.created_at,
                       'author', coalesce(ms.full_name, '')) order by m.created_at), '[]')
                     from ticket_messages m left join staff ms on ms.id = m.sender_id where m.ticket_id = k.id)
      ) order by k.created_at desc), '[]') from support_tickets k join profiles p on p.id = k.user_id
      left join trips t on t.id = k.trip_id left join staff st on st.id = k.assigned_to),
    'promos', (select coalesce(jsonb_agg(to_jsonb(x) order by x.starts_at desc), '[]') from promos x),
    'broadcasts', (select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'audience', b.audience, 'title', b.title,
        'body', b.body, 'date', b.created_at, 'reach', b.recipients, 'by', coalesce(s.full_name, ''))
        order by b.created_at desc), '[]') from broadcasts b left join staff s on s.id = b.sent_by),
    'staff', (select coalesce(jsonb_agg(to_jsonb(s) order by s.created_at), '[]') from staff s),
    'audit', (select coalesce(jsonb_agg(jsonb_build_object('who', coalesce(s.full_name, 'System'), 'action', a.action, 'time', a.created_at)
        order by a.created_at desc), '[]') from (select * from audit_log order by created_at desc limit 300) a left join staff s on s.id = a.staff_id),
    'pricing', (select coalesce(jsonb_agg(to_jsonb(r) order by r.sort), '[]') from ride_types r),
    'plans', (select coalesce(jsonb_agg(to_jsonb(p)), '[]') from plan_prices p),
    'settings', (select to_jsonb(s) from app_settings s where id = 1),
    'cities', (select coalesce(jsonb_agg(c.name order by c.name), '[]') from cities c where c.active),
    'city_rates', (select coalesce(jsonb_agg(to_jsonb(r)), '[]') from city_rates r),
    'online', (select count(*) from driver_locations where online and updated_at > now() - interval '2 minutes')
  );
end $$;
revoke execute on function admin_snapshot(int) from anon, public;
grant execute on function admin_snapshot(int) to authenticated;

-- Staff actions not covered by earlier functions.
create or replace function admin_set_driver_status(p_driver uuid, p_status approval_status, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_staff(array['operations', 'safety']::staff_role[]) then raise exception 'Not allowed'; end if;
  update drivers set status = p_status, rejection_note = p_note where id = p_driver;
  if p_status = 'suspended' then
    update driver_locations set online = false where driver_id = p_driver;
    perform notify(p_driver, 'documents', 'Your account is on hold', coalesce(p_note, 'Contact GoRide support.'));
  elsif p_status = 'approved' then
    perform notify(p_driver, 'documents', 'Your account is active again', 'You can go online now.');
  end if;
  perform audit((case p_status when 'suspended' then 'Suspended' else 'Reactivated' end) || ' driver '
    || (select full_name from profiles where id = p_driver) || coalesce(': ' || p_note, ''));
end $$;

create or replace function admin_review_doc(p_driver uuid, p_type text, p_status doc_status, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_staff(array['operations']::staff_role[]) then raise exception 'Not allowed'; end if;
  update driver_documents set status = p_status, note = p_note, reviewed_by = auth.uid()
    where driver_id = p_driver and type = p_type;
  if p_status = 'rejected' then
    perform notify(p_driver, 'documents', 'A document needs attention', coalesce(p_note, 'Please upload it again.'));
  end if;
end $$;

create or replace function admin_set_blocked(p_user uuid, p_blocked boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff(array['operations', 'support', 'safety']::staff_role[]) then raise exception 'Not allowed'; end if;
  perform set_config('goride.system', 'on', true);
  update profiles set blocked = p_blocked where id = p_user;
  perform set_config('goride.system', 'off', true);
  perform audit((case when p_blocked then 'Blocked ' else 'Unblocked ' end) || (select full_name from profiles where id = p_user));
end $$;

create or replace function admin_update_safety(p_event uuid, p_status case_status, p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_staff(array['safety']::staff_role[]) then raise exception 'Not allowed'; end if;
  update safety_events set status = p_status, assigned_to = auth.uid(),
    notes = case when p_note is null then notes else coalesce(notes || E'\n', '') || p_note end,
    resolved_at = case when p_status = 'resolved' then now() end
    where id = p_event;
  perform audit('Safety case marked ' || p_status);
end $$;

create or replace function admin_reply_ticket(p_ticket uuid, p_text text, p_status case_status default null) returns void
language plpgsql security definer set search_path = public as $$
declare k support_tickets;
begin
  if not is_staff(array['support', 'safety']::staff_role[]) then raise exception 'Not allowed'; end if;
  if p_text is not null and p_text <> '' then
    insert into ticket_messages (ticket_id, sender_id, from_staff, body) values (p_ticket, auth.uid(), true, p_text);
  end if;
  update support_tickets set status = coalesce(p_status, case when status = 'open' then 'in_progress'::case_status else status end),
    assigned_to = auth.uid(), updated_at = now() where id = p_ticket returning * into k;
  if p_text is not null and p_text <> '' then
    perform notify(k.user_id, 'updates', 'GoRide support replied', left(p_text, 140));
  end if;
end $$;

do $$ declare f text; begin
  foreach f in array array['admin_set_driver_status(uuid, approval_status, text)', 'admin_review_doc(uuid, text, doc_status, text)',
    'admin_set_blocked(uuid, boolean)', 'admin_update_safety(uuid, case_status, text)', 'admin_reply_ticket(uuid, text, case_status)'] loop
    execute 'revoke execute on function ' || f || ' from anon, public';
    execute 'grant execute on function ' || f || ' to authenticated';
  end loop;
end $$;

-- First super admin: the project owner's account.
insert into staff (id, full_name, email, role)
select u.id, 'Temidayo Hassan', u.email, 'super_admin' from auth.users u
where u.email in ('temidayohassan2023@gmail.com', 'temidayohassanadekunle@gmail.com')
on conflict (id) do update set role = 'super_admin', active = true;

-- Staff invites: a super admin invites an email; the person signs in to the
-- admin dashboard with that email and becomes staff.
create table if not exists staff_invites (
  email text primary key,
  full_name text not null,
  role staff_role not null,
  invited_by uuid references staff,
  created_at timestamptz not null default now()
);
alter table staff_invites enable row level security;
create policy invites_admin on staff_invites for all using (is_staff(array['super_admin']::staff_role[]));

create or replace function claim_staff() returns staff
language plpgsql security definer set search_path = public as $$
declare i staff_invites; s staff; em text := lower(coalesce(auth.jwt()->>'email', ''));
begin
  select * into s from staff where id = auth.uid();
  if s.id is not null then
    update staff set last_seen_at = now() where id = s.id;
    return s;
  end if;
  select * into i from staff_invites where lower(email) = em;
  if i.email is null then return null; end if;
  insert into staff (id, full_name, email, role) values (auth.uid(), i.full_name, em, i.role) returning * into s;
  delete from staff_invites where email = i.email;
  return s;
end $$;
revoke execute on function claim_staff() from anon, public;
grant execute on function claim_staff() to authenticated;

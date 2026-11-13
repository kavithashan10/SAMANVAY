-- Department-wise review checklists.
--
-- Every department review of a work request carries that department's own
-- checklist. Only an officer of the reviewing department (or an admin) can tick
-- items, and a review cannot be approved until every item is ticked. The rule
-- is enforced here in the database, not only in the app.

create table if not exists public.department_checklist_templates (
  id uuid primary key default gen_random_uuid(),
  -- Matches public.departments.name; '*' is the fallback for other departments.
  department_name text not null,
  item_key text not null check (item_key ~ '^[a-z0-9_]{2,60}$'),
  label text not null check (char_length(label) between 3 and 200),
  position integer not null check (position between 1 and 50),
  created_at timestamptz not null default now(),
  unique (department_name, item_key),
  unique (department_name, position)
);

alter table public.department_checklist_templates enable row level security;
drop policy if exists "Authenticated users can read checklist templates" on public.department_checklist_templates;
create policy "Authenticated users can read checklist templates"
  on public.department_checklist_templates for select to authenticated using (true);
grant select on public.department_checklist_templates to authenticated;

create table if not exists public.department_review_checklist_items (
  review_id uuid not null references public.request_department_reviews(id) on delete cascade,
  item_key text not null,
  label text not null,
  position integer not null,
  checked boolean not null default false,
  checked_by uuid references auth.users(id),
  checked_at timestamptz,
  primary key (review_id, item_key),
  check ((checked and checked_by is not null and checked_at is not null) or (not checked and checked_at is null))
);

create index if not exists department_review_checklist_items_review_idx
  on public.department_review_checklist_items(review_id, position);

alter table public.department_review_checklist_items enable row level security;
-- Items are visible exactly when the parent review is visible to the caller
-- (the subquery runs under the caller's row-level security on reviews).
drop policy if exists "Checklist items follow review visibility" on public.department_review_checklist_items;
create policy "Checklist items follow review visibility"
  on public.department_review_checklist_items for select to authenticated
  using (exists (select 1 from public.request_department_reviews r where r.id = review_id));
grant select on public.department_review_checklist_items to authenticated;
-- No direct insert/update/delete grants: writes go through the functions below.

-- Templates --------------------------------------------------------------------
insert into public.department_checklist_templates(department_name, item_key, label, position)
values
  ('Water Supply', 'records_located', 'Mains and service lines located on our records', 1),
  ('Water Supply', 'valve_isolation', 'Valve isolation plan agreed with the site team', 2),
  ('Water Supply', 'clearance_agreed', 'Clearance distance from the water main agreed', 3),
  ('Water Supply', 'interruption_notice', 'Supply-interruption notice prepared (if needed)', 4),
  ('Water Supply', 'sewer_crossing_risk', 'Sewer-crossing contamination risk reviewed', 5),

  ('Sewage and Drainage', 'records_located', 'Sewer and storm lines located on our records', 1),
  ('Sewage and Drainage', 'chambers_accessible', 'Manholes and chambers kept accessible', 2),
  ('Sewage and Drainage', 'water_crossings', 'Crossings with the water main reviewed', 3),
  ('Sewage and Drainage', 'flow_diversion', 'Flow-diversion plan agreed (if needed)', 4),
  ('Sewage and Drainage', 'post_work_check', 'Post-work flow check scheduled', 5),

  ('Electricity', 'records_located', 'LT / HT cable route located on our records', 1),
  ('Electricity', 'permit_to_work', 'Shutdown or permit-to-work arranged', 2),
  ('Electricity', 'markers_tape', 'Cable markers and warning-tape plan agreed', 3),
  ('Electricity', 'crew_briefed', 'Safe working distance briefed to the crew', 4),

  ('Gas', 'records_located', 'Gas line route located on our records', 1),
  ('Gas', 'operator_standby', 'Operator standby confirmed for the dig window', 2),
  ('Gas', 'hand_dig_zone', 'Hand-dig zone marked near the line', 3),
  ('Gas', 'emergency_contact', 'Emergency contact shared with the site', 4),

  ('Telecommunications', 'records_located', 'Duct and chamber routes located on our records', 1),
  ('Telecommunications', 'operators_notified', 'Other fibre operators notified', 2),
  ('Telecommunications', 'joint_chambers', 'Joint chamber access agreed', 3),
  ('Telecommunications', 'dig_once_ducts', 'Dig-once: spare duct space offered', 4),

  ('Municipal Corporation', 'no_moratorium', 'Road segment is not under a restoration moratorium', 1),
  ('Municipal Corporation', 'traffic_plan', 'Traffic-management plan approved', 2),
  ('Municipal Corporation', 'restoration_spec', 'Restoration specification agreed', 3),
  ('Municipal Corporation', 'restoration_guarantee', 'Restoration guarantee recorded', 4),
  ('Municipal Corporation', 'inspection_booked', 'Post-restoration inspection booked', 5),

  ('Roads & Highways', 'segment_ownership', 'Road ownership and segment confirmed', 1),
  ('Roads & Highways', 'no_moratorium', 'Segment is not under a recent-resurfacing moratorium', 2),
  ('Roads & Highways', 'traffic_plan', 'Traffic diversion plan approved', 3),
  ('Roads & Highways', 'restoration_spec', 'Reinstatement specification agreed', 4),

  ('Stormwater Management', 'drains_located', 'Storm drains and culverts located on our records', 1),
  ('Stormwater Management', 'flow_paths', 'Flood pathways kept clear during the work', 2),
  ('Stormwater Management', 'monsoon_window', 'Work window checked against the monsoon calendar', 3),

  ('Public Health Engineering', 'supply_impact', 'Drinking-water supply impact assessed', 1),
  ('Public Health Engineering', 'contamination_risk', 'Contamination risk at crossings reviewed', 2),
  ('Public Health Engineering', 'notice_plan', 'Public notice plan agreed', 3),

  ('*', 'records_checked', 'Our asset records checked for this corridor', 1),
  ('*', 'conflicts_reviewed', 'Conflicts with our assets reviewed', 2),
  ('*', 'conditions_recorded', 'Conditions for the site team recorded', 3)
on conflict (department_name, item_key) do update
  set label = excluded.label, position = excluded.position;

-- Helpers ----------------------------------------------------------------------

-- Creates a review's checklist from its department template if it has none.
create or replace function private.ensure_department_review_checklist(p_review_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  v_department_name text;
begin
  if exists (select 1 from public.department_review_checklist_items i where i.review_id = p_review_id) then
    return;
  end if;
  select d.name into v_department_name
  from public.request_department_reviews r
  join public.departments d on d.id = r.department_id
  where r.id = p_review_id;
  if v_department_name is null then
    raise exception 'Department review not found';
  end if;
  insert into public.department_review_checklist_items(review_id, item_key, label, position)
  select p_review_id, t.item_key, t.label, t.position
  from public.department_checklist_templates t
  where t.department_name = case
    when exists (select 1 from public.department_checklist_templates x where x.department_name = v_department_name)
      then v_department_name else '*' end
  on conflict do nothing;
end;
$function$;
revoke all on function private.ensure_department_review_checklist(uuid) from public, anon, authenticated;

-- Read a review's checklist; returns whether the caller may tick it.
create or replace function public.get_department_review_checklist(p_review_id uuid)
returns table(item_key text, label text, item_position integer, checked boolean, checked_at timestamptz, can_edit boolean, review_status text)
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_dept uuid;
  v_review_dept uuid;
  v_requester uuid;
  v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select p.role, p.department_id into v_role, v_dept from public.profiles p where p.id = v_uid;
  select r.department_id, e.requester_id, r.review_status
    into v_review_dept, v_requester, v_status
  from public.request_department_reviews r
  join public.excavation_requests e on e.id = r.request_id
  where r.id = p_review_id;
  if v_review_dept is null then raise exception 'Department review not found'; end if;
  if not (
    v_role in ('admin', 'coordinator')
    or (v_role = 'department' and v_dept = v_review_dept)
    or v_requester = v_uid
  ) then
    raise exception 'Not authorised to view this checklist';
  end if;

  perform private.ensure_department_review_checklist(p_review_id);

  return query
  select i.item_key, i.label, i.position, i.checked, i.checked_at,
         (v_role = 'admin' or (v_role = 'department' and v_dept = v_review_dept))
           and coalesce(v_status, 'pending') not in ('approved', 'rejected'),
         coalesce(v_status, 'pending')
  from public.department_review_checklist_items i
  where i.review_id = p_review_id
  order by i.position;
end;
$function$;
revoke all on function public.get_department_review_checklist(uuid) from public, anon;
grant execute on function public.get_department_review_checklist(uuid) to authenticated;

-- Tick or untick one item. Only the reviewing department's officer (or admin).
create or replace function public.set_department_review_checklist_item(p_review_id uuid, p_item_key text, p_checked boolean)
returns void
language plpgsql security definer set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_dept uuid;
  v_review_dept uuid;
  v_status text;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select p.role, p.department_id into v_role, v_dept from public.profiles p where p.id = v_uid;
  select r.department_id, r.review_status into v_review_dept, v_status
  from public.request_department_reviews r where r.id = p_review_id;
  if v_review_dept is null then raise exception 'Department review not found'; end if;
  if not (v_role = 'admin' or (v_role = 'department' and v_dept = v_review_dept)) then
    raise exception 'Only the reviewing department can update this checklist';
  end if;
  if coalesce(v_status, 'pending') in ('approved', 'rejected') then
    raise exception 'This review is finalised; its checklist can no longer change';
  end if;

  perform private.ensure_department_review_checklist(p_review_id);

  update public.department_review_checklist_items i
  set checked = p_checked,
      checked_by = case when p_checked then v_uid else null end,
      checked_at = case when p_checked then now() else null end
  where i.review_id = p_review_id and i.item_key = p_item_key;
  if not found then raise exception 'Checklist item not found'; end if;
end;
$function$;
revoke all on function public.set_department_review_checklist_item(uuid, text, boolean) from public, anon;
grant execute on function public.set_department_review_checklist_item(uuid, text, boolean) to authenticated;

-- Approval gate ----------------------------------------------------------------
create or replace function private.require_complete_department_checklist()
returns trigger
language plpgsql security definer set search_path = ''
as $function$
begin
  if new.review_status = 'approved' and new.review_status is distinct from old.review_status then
    perform private.ensure_department_review_checklist(new.id);
    if exists (
      select 1 from public.department_review_checklist_items i
      where i.review_id = new.id and not i.checked
    ) then
      raise exception 'DEPARTMENT_CHECKLIST_INCOMPLETE: tick every checklist item before approving'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$function$;
revoke all on function private.require_complete_department_checklist() from public, anon, authenticated;

drop trigger if exists require_complete_department_checklist on public.request_department_reviews;
create trigger require_complete_department_checklist
  before update of review_status on public.request_department_reviews
  for each row execute function private.require_complete_department_checklist();

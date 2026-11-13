-- Dig-once screening.
--
-- Finds other active work requests whose work areas come within a small
-- distance of this request and whose planned work windows fall within a few
-- months of it, so departments can combine trenches instead of cutting the
-- same road twice. Uses the request latitude/longitude (great-circle
-- distance), so it does not depend on PostGIS geometry being populated.
--
-- Advisory only: it compares records stored in SAMANVAY and says nothing about
-- works that were never recorded.

create or replace function public.get_request_dig_once_matches(
  p_request_id uuid,
  p_window_days integer default 90,
  p_distance_m numeric default 60
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := (select auth.uid());
  v_role text;
  v_staff boolean;
  v_requester uuid;
  v_lat double precision;
  v_lon double precision;
  v_radius double precision;
  v_start date;
  v_end date;
  v_matches jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if p_window_days is null or p_window_days < 0 or p_window_days > 365 then
    raise exception 'Window must be between 0 and 365 days';
  end if;
  if p_distance_m is null or p_distance_m < 0 or p_distance_m > 1000 then
    raise exception 'Distance must be between 0 and 1000 metres';
  end if;

  select p.role into v_role from public.profiles p where p.id = v_uid;

  select r.requester_id, r.latitude::double precision, r.longitude::double precision,
         coalesce(r.work_radius_m, 0)::double precision,
         r.planned_start_date::date, coalesce(r.planned_end_date, r.planned_start_date)::date
    into v_requester, v_lat, v_lon, v_radius, v_start, v_end
  from public.excavation_requests r
  where r.id = p_request_id;

  if not found then
    raise exception 'Request not found';
  end if;

  if not (
    v_role in ('admin', 'coordinator')
    or v_requester = v_uid
    or (v_role = 'department' and public.is_department_assigned_to_request(p_request_id))
  ) then
    raise exception 'You are not authorised to screen this request';
  end if;
  v_staff := v_role in ('admin', 'coordinator', 'department');

  if v_lat is null or v_lon is null then
    return jsonb_build_object('status', 'missing_work_location', 'matches', '[]'::jsonb);
  end if;
  if v_start is null then
    return jsonb_build_object('status', 'missing_work_dates', 'matches', '[]'::jsonb);
  end if;

  with others as (
    select
      o.request_number,
      o.title,
      o.case_category,
      o.status,
      o.planned_start_date::date as s,
      coalesce(o.planned_end_date, o.planned_start_date)::date as e,
      coalesce(o.work_radius_m, 0)::double precision as radius,
      2 * 6371000 * asin(sqrt(
        power(sin(radians(o.latitude::double precision - v_lat) / 2), 2)
        + cos(radians(v_lat)) * cos(radians(o.latitude::double precision))
          * power(sin(radians(o.longitude::double precision - v_lon) / 2), 2)
      )) as dist
    from public.excavation_requests o
    where o.id <> p_request_id
      and o.latitude is not null
      and o.longitude is not null
      and o.planned_start_date is not null
      and coalesce(o.status, '') not in ('rejected', 'cancelled', 'closed', 'completed', 'draft')
  ),
  matched as (
    select o.*, greatest(0, o.s - v_end, v_start - o.e) as gap_days
    from others o
    where o.dist <= p_distance_m + o.radius + v_radius
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'request_number', m.request_number,
      'title', case when v_staff then m.title end,
      'case_category', m.case_category,
      'status', m.status,
      'planned_start_date', m.s,
      'planned_end_date', m.e,
      'distance_m', round(m.dist::numeric, 1),
      'gap_days', m.gap_days
    ) order by m.gap_days, m.dist), '[]'::jsonb)
  into v_matches
  from matched m
  where m.gap_days <= p_window_days;

  return jsonb_build_object(
    'status', 'completed',
    'window_days', p_window_days,
    'distance_m', p_distance_m,
    'matches', v_matches,
    'disclaimer', 'Dig-once screening compares planned work recorded in SAMANVAY only. Unrecorded works are not detected.'
  );
end;
$function$;

revoke all on function public.get_request_dig_once_matches(uuid, integer, numeric) from public, anon;
grant execute on function public.get_request_dig_once_matches(uuid, integer, numeric) to authenticated;

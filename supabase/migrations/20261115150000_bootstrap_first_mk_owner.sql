-- One-time, allowlisted conversion of the designated MK Messenger customer identity into the first Owner.
create or replace function public.bootstrap_mk_owner(
  p_user_id uuid,
  p_username text,
  p_display_name text default 'MK Owner'
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_email text;
begin
  if p_user_id is null
     or p_username is null
     or p_username !~ '^[a-zA-Z0-9_]{3,24}$' then
    raise exception 'Valid owner identity is required';
  end if;

  select lower(u.email) into v_email
  from auth.users u
  where u.id = p_user_id;

  if v_email is distinct from '1987zinwaimin@gmail.com' then
    raise exception 'This account is not approved for Owner bootstrap';
  end if;

  if exists (select 1 from private.owner_accounts) then
    raise exception 'Owner bootstrap is already completed';
  end if;

  insert into public.profiles(id, username, display_name)
  values (p_user_id, p_username, coalesce(nullif(p_display_name, ''), 'MK Owner'));

  insert into private.owner_accounts(user_id, active)
  values (p_user_id, true);

  return true;
end;
$function$;

revoke all on function public.bootstrap_mk_owner(uuid, text, text) from public, anon, authenticated;
grant execute on function public.bootstrap_mk_owner(uuid, text, text) to service_role;

create or replace function public.can_bootstrap_mk_owner(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select
    exists (
      select 1 from auth.users u
      where u.id = p_user_id
        and lower(u.email) = '1987zinwaimin@gmail.com'
    )
    and not exists (select 1 from private.owner_accounts);
$function$;

revoke all on function public.can_bootstrap_mk_owner(uuid) from public, anon, authenticated;
grant execute on function public.can_bootstrap_mk_owner(uuid) to service_role;

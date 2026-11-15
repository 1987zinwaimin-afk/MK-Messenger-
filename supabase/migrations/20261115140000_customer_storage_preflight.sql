-- Read-only preflight for Customer Account deletion.
-- Storage objects are removed before relational metadata so a failed storage cleanup
-- never proceeds to database/Auth deletion. This function is service-role only.

create or replace function private.get_mk_customer_storage_paths(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  v_chat_paths text[] := '{}';
  v_wall_paths text[] := '{}';
  v_avatar text;
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if exists (
    select 1
    from private.owner_accounts oa
    where oa.user_id = p_user_id and oa.active = true
  ) then
    raise exception 'Owner accounts cannot be deleted through customer deletion';
  end if;

  if not exists (select 1 from auth.users au where au.id = p_user_id) then
    raise exception 'Customer account does not exist';
  end if;

  select coalesce(array_agg(distinct m.body), '{}')
    into v_chat_paths
  from public.messages m
  where m.sender_id = p_user_id
    and m.message_type in ('image', 'video', 'file', 'audio')
    and m.body <> '';

  select coalesce(array_agg(distinct wpm.storage_path), '{}')
    into v_wall_paths
  from public.wall_post_media wpm
  where wpm.owner_id = p_user_id;

  select p.avatar_url into v_avatar
  from public.profiles p
  where p.id = p_user_id;

  return jsonb_build_object(
    'chat_paths', to_jsonb(v_chat_paths),
    'wall_paths', to_jsonb(v_wall_paths),
    'avatar_path', v_avatar
  );
end;
$function$;

revoke all on function private.get_mk_customer_storage_paths(uuid) from public, anon, authenticated;
grant execute on function private.get_mk_customer_storage_paths(uuid) to service_role;

create or replace function public.get_mk_customer_storage_paths(p_user_id uuid)
returns jsonb
language sql
security definer
set search_path to ''
as $function$
  select private.get_mk_customer_storage_paths(p_user_id);
$function$;

revoke all on function public.get_mk_customer_storage_paths(uuid) from public, anon, authenticated;
grant execute on function public.get_mk_customer_storage_paths(uuid) to service_role;

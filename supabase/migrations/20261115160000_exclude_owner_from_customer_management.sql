create or replace function public.list_mk_customer_profiles()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.username, p.display_name, p.avatar_url, p.created_at
  from public.profiles p
  where exists (
    select 1 from private.owner_accounts caller_owner
    where caller_owner.user_id = auth.uid() and caller_owner.active = true
  )
  and not exists (
    select 1 from private.owner_accounts target_owner
    where target_owner.user_id = p.id and target_owner.active = true
  )
  order by p.created_at desc;
$$;

revoke all on function public.list_mk_customer_profiles() from public, anon;
grant execute on function public.list_mk_customer_profiles() to authenticated;

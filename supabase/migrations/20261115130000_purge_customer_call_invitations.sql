-- Complete customer deletion: remove call invitation records involving the account.
-- This is additive to the existing deletion routine and does not run against production
-- until this migration is explicitly applied.

create or replace function private.purge_mk_customer_data(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_chat_paths text[] := '{}';
  v_wall_paths text[] := '{}';
  v_avatar text;
  v_conv record;
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

  select avatar_url into v_avatar
  from public.profiles
  where id = p_user_id;

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

  -- Remove call history/invitations where the account was either participant.
  delete from public.call_invitations
  where caller_id = p_user_id or recipient_id = p_user_id;

  -- Remove replies to this user's messages before deleting those messages.
  update public.messages m
  set reply_to_id = null
  where m.reply_to_id in (
    select id from public.messages where sender_id = p_user_id
  );

  -- Remove authored messages from every conversation, including shared/group chats.
  delete from public.messages
  where sender_id = p_user_id;

  -- Remove user's own content and related likes/comments/media metadata.
  delete from public.wall_posts
  where author_id = p_user_id;
  delete from public.wall_post_comments
  where user_id = p_user_id;
  delete from public.wall_post_likes
  where user_id = p_user_id;
  delete from public.wall_post_media
  where owner_id = p_user_id;

  -- Remove reports involving the deleted account and personal safety/social records.
  delete from public.user_reports
  where reporter_id = p_user_id or reported_user_id = p_user_id;
  delete from public.friend_requests
  where sender_id = p_user_id or receiver_id = p_user_id;
  delete from public.user_blocks
  where blocker_id = p_user_id or blocked_id = p_user_id;
  delete from public.push_subscriptions
  where user_id = p_user_id;
  delete from public.message_hidden_for
  where user_id = p_user_id;
  delete from public.message_pins
  where user_id = p_user_id;
  delete from public.message_reactions
  where user_id = p_user_id;
  delete from public.message_receipts
  where user_id = p_user_id;
  delete from public.conversation_pins
  where pinned_by = p_user_id;
  delete from public.chat_user_preferences
  where user_id = p_user_id;
  delete from public.conversation_archives
  where user_id = p_user_id;

  -- Transfer ownership of created conversations to a remaining member; delete empty conversations.
  for v_conv in
    select c.id,
      (
        select cm.user_id
        from public.conversation_members cm
        where cm.conversation_id = c.id
          and cm.user_id <> p_user_id
        order by cm.joined_at
        limit 1
      ) as next_owner
    from public.conversations c
    where c.created_by = p_user_id
  loop
    if v_conv.next_owner is null then
      delete from public.conversations where id = v_conv.id;
    else
      update public.conversations
      set created_by = v_conv.next_owner
      where id = v_conv.id;
    end if;
  end loop;

  delete from public.conversation_members
  where user_id = p_user_id;

  -- Remove any remaining conversations that no longer have members.
  delete from public.conversations c
  where not exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = c.id
  );

  -- Finally remove the profile; auth.users is deleted by the Edge Function after this succeeds.
  delete from public.profiles
  where id = p_user_id;

  return jsonb_build_object(
    'chat_paths', to_jsonb(v_chat_paths),
    'wall_paths', to_jsonb(v_wall_paths),
    'avatar_path', v_avatar
  );
end;
$function$;

revoke all on function private.purge_mk_customer_data(uuid) from public, anon, authenticated;
grant execute on function private.purge_mk_customer_data(uuid) to service_role;

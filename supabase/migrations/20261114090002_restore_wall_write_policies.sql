-- Restore write policies after the wall visibility helper was narrowed to auth.uid().
drop policy if exists "Users like visible wall posts" on public.wall_post_likes;
create policy "Users like visible wall posts" on public.wall_post_likes
for insert to authenticated with check (
  user_id = (select auth.uid())
  and public.can_view_wall_post(post_id)
);
drop policy if exists "Users comment on visible wall posts" on public.wall_post_comments;
create policy "Users comment on visible wall posts" on public.wall_post_comments
for insert to authenticated with check (
  user_id = (select auth.uid())
  and public.can_view_wall_post(post_id)
  and (
    parent_comment_id is null
    or exists (
      select 1 from public.wall_post_comments parent
      where parent.id = parent_comment_id and parent.post_id = wall_post_comments.post_id
    )
  )
);
drop policy if exists "Users edit own wall comments" on public.wall_post_comments;
create policy "Users edit own wall comments" on public.wall_post_comments
for update to authenticated using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()) and public.can_view_wall_post(post_id));

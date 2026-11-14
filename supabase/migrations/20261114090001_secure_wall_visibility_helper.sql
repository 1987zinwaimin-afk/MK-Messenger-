-- Restrict wall visibility helper to the authenticated caller; never accept a caller-supplied viewer id.
drop policy if exists "Wall posts visible by privacy" on public.wall_posts;
drop policy if exists "Visible wall media" on public.wall_post_media;
drop policy if exists "Visible wall likes" on public.wall_post_likes;
drop policy if exists "Visible wall comments" on public.wall_post_comments;
drop policy if exists "Users like visible wall posts" on public.wall_post_likes;
drop policy if exists "Users comment on visible wall posts" on public.wall_post_comments;
drop policy if exists "Users edit own wall comments" on public.wall_post_comments;
drop policy if exists "Wall media visible with post privacy" on storage.objects;
drop function if exists public.can_view_wall_post(uuid,uuid);

create or replace function public.can_view_wall_post(p_post_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.wall_posts p
    where p.id = p_post_id
      and (
        p.author_id = (select auth.uid())
        or (
          not exists (
            select 1 from public.user_blocks b
            where (b.blocker_id = p.author_id and b.blocked_id = (select auth.uid()))
               or (b.blocker_id = (select auth.uid()) and b.blocked_id = p.author_id)
          )
          and (
            p.privacy = 'public'
            or (
              p.privacy = 'friends'
              and exists (
                select 1 from public.friend_requests fr
                where fr.status = 'accepted'
                  and (
                    (fr.sender_id = p.author_id and fr.receiver_id = (select auth.uid()))
                    or (fr.sender_id = (select auth.uid()) and fr.receiver_id = p.author_id)
                  )
              )
            )
          )
        )
      )
  );
$$;
revoke all on function public.can_view_wall_post(uuid) from public, anon;
grant execute on function public.can_view_wall_post(uuid) to authenticated;

create policy "Wall posts visible by privacy" on public.wall_posts
for select to authenticated using (public.can_view_wall_post(id));
create policy "Visible wall media" on public.wall_post_media
for select to authenticated using (public.can_view_wall_post(post_id));
create policy "Visible wall likes" on public.wall_post_likes
for select to authenticated using (public.can_view_wall_post(post_id));
create policy "Visible wall comments" on public.wall_post_comments
for select to authenticated using (public.can_view_wall_post(post_id));
create policy "Wall media visible with post privacy" on storage.objects
for select to authenticated using (
  bucket_id = 'wall-media'
  and exists (
    select 1 from public.wall_post_media m
    where m.storage_path = name
      and public.can_view_wall_post(m.post_id)
  )
);

-- MK Messenger Wall: additive schema only. Existing auth, profiles, chats and messages remain untouched.
create table if not exists public.wall_posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 5000),
  privacy text not null default 'public' check (privacy in ('public','friends','only_me')),
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, author_id)
);

create table if not exists public.wall_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.wall_posts(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  media_type text not null check (media_type in ('image','video')),
  mime_type text not null,
  file_size bigint not null check (file_size > 0 and file_size <= 52428800),
  created_at timestamptz not null default now(),
  unique (id, post_id)
);

create table if not exists public.wall_post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.wall_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

create table if not exists public.wall_post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.wall_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_comment_id uuid,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, post_id),
  constraint wall_comment_parent_same_post_fk
    foreign key (parent_comment_id, post_id)
    references public.wall_post_comments(id, post_id) on delete cascade
);

create index if not exists wall_posts_feed_idx on public.wall_posts (created_at desc);
create index if not exists wall_posts_author_idx on public.wall_posts (author_id, created_at desc);
create index if not exists wall_media_post_idx on public.wall_post_media (post_id, created_at);
create index if not exists wall_likes_post_idx on public.wall_post_likes (post_id, created_at desc);
create index if not exists wall_comments_post_idx on public.wall_post_comments (post_id, created_at);

create or replace function public.can_view_wall_post(p_post_id uuid, p_viewer_id uuid default auth.uid())
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
        p.author_id = p_viewer_id
        or (
          not exists (
            select 1 from public.user_blocks b
            where (b.blocker_id = p.author_id and b.blocked_id = p_viewer_id)
               or (b.blocker_id = p_viewer_id and b.blocked_id = p.author_id)
          )
          and (
            p.privacy = 'public'
            or (
              p.privacy = 'friends'
              and exists (
                select 1 from public.friend_requests fr
                where fr.status = 'accepted'
                  and (
                    (fr.sender_id = p.author_id and fr.receiver_id = p_viewer_id)
                    or (fr.sender_id = p_viewer_id and fr.receiver_id = p.author_id)
                  )
              )
            )
          )
        )
      )
  );
$$;

revoke all on function public.can_view_wall_post(uuid,uuid) from public, anon;
grant execute on function public.can_view_wall_post(uuid,uuid) to authenticated;

alter table public.wall_posts enable row level security;
alter table public.wall_post_media enable row level security;
alter table public.wall_post_likes enable row level security;
alter table public.wall_post_comments enable row level security;

drop policy if exists "Wall posts visible by privacy" on public.wall_posts;
create policy "Wall posts visible by privacy" on public.wall_posts
for select to authenticated using (public.can_view_wall_post(id, (select auth.uid())));
drop policy if exists "Users create own wall posts" on public.wall_posts;
create policy "Users create own wall posts" on public.wall_posts
for insert to authenticated with check (author_id = (select auth.uid()));
drop policy if exists "Authors update own wall posts" on public.wall_posts;
create policy "Authors update own wall posts" on public.wall_posts
for update to authenticated using (author_id = (select auth.uid()))
with check (author_id = (select auth.uid()));
drop policy if exists "Authors delete own wall posts" on public.wall_posts;
create policy "Authors delete own wall posts" on public.wall_posts
for delete to authenticated using (author_id = (select auth.uid()));

drop policy if exists "Visible wall media" on public.wall_post_media;
create policy "Visible wall media" on public.wall_post_media
for select to authenticated using (public.can_view_wall_post(post_id, (select auth.uid())));
drop policy if exists "Authors attach media to own posts" on public.wall_post_media;
create policy "Authors attach media to own posts" on public.wall_post_media
for insert to authenticated with check (
  owner_id = (select auth.uid())
  and exists (select 1 from public.wall_posts p where p.id = post_id and p.author_id = (select auth.uid()))
);
drop policy if exists "Authors remove own wall media" on public.wall_post_media;
create policy "Authors remove own wall media" on public.wall_post_media
for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists "Visible wall likes" on public.wall_post_likes;
create policy "Visible wall likes" on public.wall_post_likes
for select to authenticated using (public.can_view_wall_post(post_id, (select auth.uid())));
drop policy if exists "Users like visible wall posts" on public.wall_post_likes;
create policy "Users like visible wall posts" on public.wall_post_likes
for insert to authenticated with check (user_id = (select auth.uid()) and public.can_view_wall_post(post_id, (select auth.uid())));
drop policy if exists "Users unlike own wall posts" on public.wall_post_likes;
create policy "Users unlike own wall posts" on public.wall_post_likes
for delete to authenticated using (user_id = (select auth.uid()));

drop policy if exists "Visible wall comments" on public.wall_post_comments;
create policy "Visible wall comments" on public.wall_post_comments
for select to authenticated using (public.can_view_wall_post(post_id, (select auth.uid())));
drop policy if exists "Users comment on visible wall posts" on public.wall_post_comments;
create policy "Users comment on visible wall posts" on public.wall_post_comments
for insert to authenticated with check (
  user_id = (select auth.uid())
  and public.can_view_wall_post(post_id, (select auth.uid()))
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
with check (user_id = (select auth.uid()) and public.can_view_wall_post(post_id, (select auth.uid())));
drop policy if exists "Users delete own wall comments" on public.wall_post_comments;
create policy "Users delete own wall comments" on public.wall_post_comments
for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, update, delete on public.wall_posts to authenticated;
grant select, insert, delete on public.wall_post_media to authenticated;
grant select, insert, delete on public.wall_post_likes to authenticated;
grant select, insert, update, delete on public.wall_post_comments to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'wall-media',
  'wall-media',
  false,
  52428800,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']
)
on conflict (id) do update
set public = false,
    file_size_limit = 52428800,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Wall media owner uploads" on storage.objects;
create policy "Wall media owner uploads" on storage.objects
for insert to authenticated with check (
  bucket_id = 'wall-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
drop policy if exists "Wall media visible with post privacy" on storage.objects;
create policy "Wall media visible with post privacy" on storage.objects
for select to authenticated using (
  bucket_id = 'wall-media'
  and exists (
    select 1 from public.wall_post_media m
    where m.storage_path = name
      and public.can_view_wall_post(m.post_id, (select auth.uid()))
  )
);
drop policy if exists "Wall media owner deletes" on storage.objects;
create policy "Wall media owner deletes" on storage.objects
for delete to authenticated using (
  bucket_id = 'wall-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='wall_posts') then
      alter publication supabase_realtime add table public.wall_posts;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='wall_post_likes') then
      alter publication supabase_realtime add table public.wall_post_likes;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='wall_post_comments') then
      alter publication supabase_realtime add table public.wall_post_comments;
    end if;
  end if;
end $$;

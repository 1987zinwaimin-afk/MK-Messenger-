-- Add covering indexes for Wall foreign keys and comment reply lookups.
create index if not exists wall_post_media_owner_idx on public.wall_post_media(owner_id);
create index if not exists wall_post_likes_user_idx on public.wall_post_likes(user_id);
create index if not exists wall_post_comments_user_idx on public.wall_post_comments(user_id);
create index if not exists wall_post_comments_parent_idx on public.wall_post_comments(parent_comment_id, post_id);

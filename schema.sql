-- MK Messenger isolated Supabase schema
-- Apply ONLY to a newly created, dedicated MK Messenger project.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-zA-Z0-9_]{3,24}$'),
  display_name text not null default '',
  avatar_url text,
  bio text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  receiver_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> receiver_id),
  unique (sender_id, receiver_id)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('direct','group')),
  title text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null default '',
  message_type text not null default 'text' check (message_type in ('text','image','video','file','location','system')),
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  check (length(body) <= 10000)
);

create index if not exists profiles_username_lower_idx on public.profiles (lower(username));
create index if not exists messages_conversation_created_idx on public.messages (conversation_id, created_at desc);
create index if not exists friend_requests_receiver_status_idx on public.friend_requests (receiver_id, status);

-- Create a profile automatically when a user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  candidate text;
begin
  candidate := coalesce(new.raw_user_meta_data ->> 'username', split_part(new.email, '@', 1));
  candidate := regexp_replace(candidate, '[^a-zA-Z0-9_]', '', 'g');
  if length(candidate) < 3 then candidate := 'user_' || substr(new.id::text, 1, 8); end if;
  candidate := substr(candidate, 1, 24);
  insert into public.profiles(id, username, display_name)
  values (new.id, candidate, coalesce(new.raw_user_meta_data ->> 'display_name', candidate))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_mk_messenger on auth.users;
create trigger on_auth_user_created_mk_messenger
after insert on auth.users for each row execute procedure public.handle_new_user();

-- Accepting a request creates a private direct conversation for the two users.
create or replace function public.accept_friend_request(p_request_id uuid)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
  req public.friend_requests%rowtype;
  conv_id uuid;
begin
  select * into req from public.friend_requests
   where id = p_request_id and receiver_id = auth.uid() and status = 'pending'
   for update;
  if not found then raise exception 'Friend request not found or not pending'; end if;

  update public.friend_requests set status='accepted', updated_at=now() where id=req.id;

  insert into public.conversations(kind, title, created_by)
  values ('direct', null, auth.uid()) returning id into conv_id;

  insert into public.conversation_members(conversation_id,user_id,role)
  values (conv_id, req.sender_id, 'member'), (conv_id, req.receiver_id, 'member');

  return conv_id;
end;
$$;

revoke all on function public.accept_friend_request(uuid) from public;
grant execute on function public.accept_friend_request(uuid) to authenticated;

-- SECURITY DEFINER helper avoids recursive RLS checks on conversation_members.
create or replace function public.is_conversation_member(p_conversation_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
  );
$$;
revoke all on function public.is_conversation_member(uuid) from public;
grant execute on function public.is_conversation_member(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.friend_requests enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

drop policy if exists "Signed-in users can view profiles" on public.profiles;
create policy "Signed-in users can view profiles" on public.profiles
for select to authenticated using (true);
drop policy if exists "Users create their own profile" on public.profiles;
create policy "Users create their own profile" on public.profiles
for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile" on public.profiles
for update to authenticated using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

drop policy if exists "Participants can view friend requests" on public.friend_requests;
create policy "Participants can view friend requests" on public.friend_requests
for select to authenticated using ((select auth.uid()) in (sender_id,receiver_id));
drop policy if exists "Users send friend requests as themselves" on public.friend_requests;
create policy "Users send friend requests as themselves" on public.friend_requests
for insert to authenticated with check ((select auth.uid()) = sender_id);
drop policy if exists "Receiver can update friend request" on public.friend_requests;
create policy "Receiver can update friend request" on public.friend_requests
for update to authenticated using ((select auth.uid()) = receiver_id)
with check ((select auth.uid()) = receiver_id);

drop policy if exists "Members can view their conversations" on public.conversations;
create policy "Members can view their conversations" on public.conversations
for select to authenticated using (public.is_conversation_member(id));
drop policy if exists "Creator can create conversation" on public.conversations;
create policy "Creator can create conversation" on public.conversations
for insert to authenticated with check (created_by = (select auth.uid()));

drop policy if exists "Members can view conversation membership" on public.conversation_members;
create policy "Members can view conversation membership" on public.conversation_members
for select to authenticated using (public.is_conversation_member(conversation_id));
-- Membership inserts are intentionally restricted to trusted database functions.
-- Do not add a client-side self-join policy.

drop policy if exists "Conversation members can read messages" on public.messages;
create policy "Conversation members can read messages" on public.messages
for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists "Conversation members can send as themselves" on public.messages;
create policy "Conversation members can send as themselves" on public.messages
for insert to authenticated with check (
 sender_id = (select auth.uid()) and public.is_conversation_member(conversation_id)
);
drop policy if exists "Senders can edit their own messages" on public.messages;
create policy "Senders can edit their own messages" on public.messages
for update to authenticated using (sender_id = (select auth.uid()))
with check (sender_id = (select auth.uid()));

-- Enable message INSERT events for realtime subscriptions.
do $$
begin
 if exists (select 1 from pg_publication where pubname='supabase_realtime')
 and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime'
                 and schemaname='public' and tablename='messages') then
   alter publication supabase_realtime add table public.messages;
 end if;
end $$;

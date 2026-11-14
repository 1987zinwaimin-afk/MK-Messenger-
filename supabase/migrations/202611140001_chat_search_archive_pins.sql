-- Add per-user chat organization and message pinning.
-- Additive only: does not alter existing chat/message rows.
create table if not exists public.chat_user_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  archived_at timestamptz,
  pinned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, conversation_id)
);

create index if not exists chat_user_preferences_user_archive_idx
  on public.chat_user_preferences (user_id, archived_at);
create index if not exists chat_user_preferences_user_pin_idx
  on public.chat_user_preferences (user_id, pinned_at desc);

alter table public.chat_user_preferences enable row level security;

drop policy if exists "Users view own chat preferences" on public.chat_user_preferences;
create policy "Users view own chat preferences"
  on public.chat_user_preferences for select to authenticated
  using (user_id = (select auth.uid())
    and public.is_conversation_member(conversation_id));

drop policy if exists "Users create own chat preferences" on public.chat_user_preferences;
create policy "Users create own chat preferences"
  on public.chat_user_preferences for insert to authenticated
  with check (user_id = (select auth.uid())
    and public.is_conversation_member(conversation_id));

drop policy if exists "Users update own chat preferences" on public.chat_user_preferences;
create policy "Users update own chat preferences"
  on public.chat_user_preferences for update to authenticated
  using (user_id = (select auth.uid())
    and public.is_conversation_member(conversation_id))
  with check (user_id = (select auth.uid())
    and public.is_conversation_member(conversation_id));

drop policy if exists "Users delete own chat preferences" on public.chat_user_preferences;
create policy "Users delete own chat preferences"
  on public.chat_user_preferences for delete to authenticated
  using (user_id = (select auth.uid())
    and public.is_conversation_member(conversation_id));

grant select, insert, update, delete on public.chat_user_preferences to authenticated;
revoke all on public.chat_user_preferences from anon, public;

create table if not exists public.message_pins (
  user_id uuid not null references auth.users(id) on delete cascade,
  message_id uuid not null references public.messages(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, message_id)
);

create index if not exists message_pins_user_created_idx
  on public.message_pins (user_id, created_at desc);

alter table public.message_pins enable row level security;

drop policy if exists "Users view own message pins" on public.message_pins;
create policy "Users view own message pins"
  on public.message_pins for select to authenticated
  using (user_id = (select auth.uid())
    and exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_member(m.conversation_id)
    ));

drop policy if exists "Users pin messages in own conversations" on public.message_pins;
create policy "Users pin messages in own conversations"
  on public.message_pins for insert to authenticated
  with check (user_id = (select auth.uid())
    and exists (
      select 1 from public.messages m
      where m.id = message_id
        and m.deleted_at is null
        and public.is_conversation_member(m.conversation_id)
    ));

drop policy if exists "Users unpin own messages" on public.message_pins;
create policy "Users unpin own messages"
  on public.message_pins for delete to authenticated
  using (user_id = (select auth.uid())
    and exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_member(m.conversation_id)
    ));

grant select, insert, delete on public.message_pins to authenticated;
revoke all on public.message_pins from anon, public;

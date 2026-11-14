-- The production project already contains the RLS-protected
-- chat_user_preferences and message_pins tables used by this feature.
-- Keep this migration idempotent and remove only redundant duplicate
-- policies/indexes; preserve all existing user rows and the original policies.

drop policy if exists "Users view own chat preferences" on public.chat_user_preferences;
drop policy if exists "Users create own chat preferences" on public.chat_user_preferences;
drop policy if exists "Users update own chat preferences" on public.chat_user_preferences;
drop policy if exists "Users delete own chat preferences" on public.chat_user_preferences;

drop policy if exists "Users view own message pins" on public.message_pins;
drop policy if exists "Users pin messages in own conversations" on public.message_pins;
drop policy if exists "Users unpin own messages" on public.message_pins;

drop index if exists public.chat_user_preferences_user_archive_idx;
drop index if exists public.chat_user_preferences_user_pin_idx;
drop index if exists public.message_pins_user_created_idx;

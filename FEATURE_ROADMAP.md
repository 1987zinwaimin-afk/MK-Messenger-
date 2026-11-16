# MK Messenger Feature Roadmap

This roadmap is additive. Preserve the existing production URL, GitHub repository, Supabase project, authentication identities, profiles, conversations, messages, storage objects, and all existing data.

## Phase 1 — Account security (implemented on feature branch)
- Add an Account Security screen without changing the existing account model.
- Show the signed-in email, current session expiry, and browser/device user-agent hint.
- Allow an authenticated user to update their password through Supabase Auth.
- Allow a user to revoke other refresh-token sessions while keeping the current session active.
- Do not claim to enumerate every active device: the browser client does not expose a trusted session inventory.

## Phase 2 — Chat productivity
- Conversation search and message search with pagination.
- Pin/unpin messages and archive conversations using per-user state.
- Forward messages with clear sender/context attribution.
- Improve unread counts using database-side aggregation/pagination rather than a fixed 2,000-message scan.
- Preserve existing Delete for Me and permanent Delete for Everyone semantics.

## Phase 3 — Notifications
- Add Web Push subscriptions and a service worker for background notifications. (service-worker push display and click handling implemented on feature branch; delivery is not active yet)
- Store each user's push subscription securely and support unsubscribe/revocation. (additive user-scoped table + owner-only RLS migration and browser subscribe/unsubscribe controls implemented on feature branch; migration not applied to production)
- Add an authenticated server-side push sender using VAPID secrets; never expose private keys or service-role credentials in the browser. (pending VAPID key generation and secure server-side sender deployment)
- Keep foreground notifications working and avoid exposing service-role credentials in the browser.

## Phase 4 — Voice and video calling
- Evaluate a dedicated WebRTC signaling/media approach and TURN relay requirements.
- Add one-to-one voice/video first, then group calling only after reliability and cost testing.
- Do not assume Supabase Realtime alone provides media transport.

## Phase 5 — Group collaboration
- Add group announcements, polls, invite links, pinned messages, and shared media gallery.
- Enforce every group action with database-side membership and role checks.
- Keep current group ownership/admin rules intact.

## Phase 6 — Backup and storage controls
- Add user-scoped chat export and attachment management.
- Design backup/restore with explicit user confirmation and integrity checks.
- Never silently overwrite existing data.

## Phase 7 — Moderation and operations
- Add a private report review workflow with narrowly scoped moderator permissions.
- Add account restriction/appeal workflows only after authorization and audit logging are designed.
- Add operational health, storage, and error monitoring.

## Release gates
- Build and validate each phase on a feature branch first.
- Review database changes and RLS/security advisors before any production migration.
- Test with at least two independent accounts, including unauthorized-access checks.
- Confirm the existing permanent Vercel alias remains attached before production release.


## Wall & Friends Activity (2026-11-14)
- [x] Additive Wall schema: posts, media metadata, likes, comments and nested replies.
- [x] Default post privacy is Public; per-post Friends Only and Only Me options.
- [x] Row Level Security for post, media, like and comment visibility and ownership.
- [x] Private wall-media Storage bucket with owner upload/delete and post-privacy read checks.
- [x] Add My Wall and Friends Activity navigation and responsive Navy + Gold UI.
- [x] Photo/video composer (up to 6 items, 50 MB each), captions and privacy selector.
- [x] Likes, comments/replies, post edit/delete/pin/unpin and shareable post links.
- [x] JavaScript syntax validation and database policy/table verification.
- [ ] Browser-level verification with two separate signed-in accounts (requires app test session).
- [ ] Production deployment (hold until the user requests it and Vercel deployment capacity is available).

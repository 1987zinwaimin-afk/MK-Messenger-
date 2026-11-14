# MK Messenger — Phase 2 starter files

This folder contains the source files to upload to the empty GitHub repository:
https://github.com/1987zinwaimin-afk/MK-Messenger-

## Upload to GitHub (Android)
1. Open the repository link and stay on the `main` branch.
2. Tap **Add file** → **Upload files**.
3. Extract this ZIP on your phone first.
4. Upload `index.html`, `config.example.js`, `README.md`, and the `supabase` folder (containing `schema.sql`).
5. Tap **Commit changes**.

If GitHub mobile does not let you upload a folder, create the `supabase` folder first, open it, then upload `schema.sql` there.

## Configure Supabase
1. Create a brand-new Supabase project named `MK Messenger` in Singapore (`ap-southeast-1`). Do not reuse any existing project's database.
2. Open SQL Editor and run `supabase/schema.sql`.
3. Open Project Settings → API. Copy the Project URL and the anon/public (publishable) key.
4. Copy `config.example.js` to `config.js`, then replace the two placeholder values.
5. Upload `config.js` to the repository only after entering your public anon/publishable key. The anon key is intended for browser use; never use the `service_role` key.
6. In Authentication → URL Configuration, add the production website URL to Site URL and Redirect URLs.

## Current scope
- Email/password registration and sign-in
- Automatic user profile creation
- Username search
- Friend request sending and accepting
- Direct conversation creation after accepting a request
- Realtime text messages
- Profile editing

## Not yet included
- Google OAuth, group creation/member management, image/video/file upload, location sharing, push notifications, voice/video calls, message encryption, moderation/admin tools.

## Important security notes
- This is an initial implementation, not a full production audit.
- The SQL enables Row Level Security and intentionally does not allow users to add themselves to arbitrary conversations.
- Do not expose database passwords or Supabase service-role keys in frontend files.
- Test with two separate accounts before inviting other users.

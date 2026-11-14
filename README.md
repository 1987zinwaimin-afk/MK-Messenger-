# MK Messenger Android app

Native Android wrapper for the existing MK Messenger production website.

- Android 13+ uses `MediaStore.ACTION_PICK_IMAGES` (the Android system Photo Picker).
- Older Android versions use the image content picker.
- Camera capture uses a private FileProvider URI.
- No broad photo-library permission is requested.
- Existing accounts, chats and messages continue to use the existing backend.

## Build APK with GitHub Actions

The included workflow builds a debug APK whenever files under `android/` change, or manually from **Actions → Build MK Messenger Android APK → Run workflow**. Download the `MK-Messenger-Android` artifact from the completed run.

Package: `com.mk.messenger`
Website: `https://mk-messenger-khant-min-htet2.vercel.app/`

## Production deployment (keep this workflow)

- Vercel project: `mk-messenger` (`prj_5uPcpuY9BVhd8LHGgPtAw0U7bIlW`)
- Git repository: `1987zinwaimin-afk/MK-Messenger-`
- Production branch: `main`
- Permanent production URL: https://mk-messenger-khant-min-htet2.vercel.app/
- Supabase project ref: `lpjmsncnyeyliskwvrgj`

### Required release process

1. Make changes on the existing `main` source; do not recreate the project or replace its backend.
2. Preserve the approved Navy Blue + Champagne Gold mobile UI, existing authentication, profiles, conversations and data.
3. Commit the complete source changes to GitHub `main`.
4. Let the connected Vercel Git integration create the deployment from that commit.
5. Verify the deployment is `READY` and is attached to the permanent production domain before announcing completion.
6. If a deployment fails, inspect the build logs and fix the source; do not silently fall back to an unrelated preview or manual upload.

Never change the production domain, Supabase project, existing user data, or storage policies as part of routine UI work.

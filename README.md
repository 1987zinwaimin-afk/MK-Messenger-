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

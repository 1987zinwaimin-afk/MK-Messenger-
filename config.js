// MK Messenger Supabase configuration
// The publishable/anon key is intended for browser use.
// NEVER place a Supabase service_role key or database password in this file.
window.MK_CONFIG = {
  supabaseUrl: "https://lpjmsncnyeyliskwvrgj.supabase.co",
  supabaseAnonKey: "sb_publishable_31NKlPChayKiE5mb6dDEjg_J_i4dceg",
  // Public VAPID key only; the matching private key belongs in Supabase Edge Function secrets.
  vapidPublicKey: "BCpfOE5mkO8kMSVR01diviK0odNszBGOBxYPICQuaKVhOWqsN0AhZkcCeWrzk8edUcMEIzlXQDdW3Uf5BOjK4Ao"
};

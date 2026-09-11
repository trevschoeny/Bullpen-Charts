/* Bullpen Charts — backend configuration.
 *
 * Leave this as-is and the app runs on its own: every coach's bullpens stay in
 * their own browser, nothing is shared.
 *
 * Fill it in and the app uses your Supabase project instead: coaches sign in,
 * and everyone on a team sees the same bullpens from any device.
 *
 *   1. supabase.com → New project (free tier is fine).
 *   2. SQL Editor → paste supabase-schema.sql → Run.
 *   3. Project Settings → API → copy the Project URL and the anon/publishable key.
 *   4. Paste them below and commit.
 *
 * The anon key is MEANT to be public. It identifies the project, it does not
 * grant access — row level security decides what each signed-in coach can see,
 * and that runs inside the database where the browser cannot reach it.
 *
 * Do NOT paste the service_role key here. That one bypasses every policy.
 */
window.BULLPEN_CONFIG = {
  url: "https://fegdzjtaewmrmivtnlmi.supabase.co",
  anonKey: "sb_publishable_SYMAaOBoh8Iq5QAuUq-O9w_Ln5Msoon"
};

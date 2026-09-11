# Bullpen Charts

Chart pitching bullpens on a tablet. Tap the strike zone where the ball crossed
the plate; get strike rate, command, velocity and heat maps back.

**Live app:** https://YOUR-USERNAME.github.io/bullpen-charts/

---

## For coaches

Open the link on an iPad and **add it to the home screen** (Share → Add to Home
Screen). It then launches full-screen and works with no signal, which matters at
most fields.

- **Pick your team** on the way in. The choice is remembered on that device.
- **Start bullpen**, pick the pitcher, pick the pitch type, tap where the ball
  crossed the plate. One tap per pitch.
- **Set the mitt** (optional) to mark where the catcher set up. Every pitch after
  that is scored by how many inches it missed by — that is the command number.
- **Press and hold** a dot to move a pitch; tap it to change type or velocity.
- **Catcher / Pitcher** switches which side you are standing on. The data is
  stored the same either way, so charts from both views compare directly.

### Signing in

If the app has been connected to a Supabase project (see below), coaches sign in
with a **magic link** — type your email, tap the link that arrives, done. No
password to remember, forget, or share around a coaching staff.

You see a team only if its owner invited your email address. That check runs in
the database, not in the page, so it holds regardless of what anyone does in a
browser.

Per-session and per-team CSV export is under the pen and on the Sessions tab if
you want the numbers in a spreadsheet.

---

## Shared data (Supabase)

Out of the box the app stores everything in the browser it was charted on —
fine for one coach, useless for a staff. Connecting a Supabase project makes
every coach on a team see the same bullpens from any device, live.

**Cost: free.** The Supabase free tier covers 500 MB of database, 50,000 monthly
active users and unlimited API requests. A bullpen is a few KB, so a program
would need tens of thousands of sessions to approach the limit.

### Setup, about ten minutes

1. **supabase.com** → New project. Free tier. Save the database password
   somewhere, though the app never needs it.
2. **SQL Editor → New query** → paste all of `supabase-schema.sql` → **Run**.
   That creates the tables, the access policies and the realtime hooks.
3. **Project Settings → API Keys** → copy the **Project URL** and the **anon /
   publishable** key. Not `service_role` — that one bypasses every policy and
   must never go in a web page.
4. Paste both into `config.js` and commit. The app switches to shared mode on
   the next load. *(Already filled in for this copy.)*
5. **Authentication → URL Configuration** → set Site URL to your Pages address
   (`https://YOUR-USERNAME.github.io/bullpen-charts/`) so magic links come back
   to the right place.

The anon key is *meant* to be public. It names the project; it grants nothing on
its own. Every table is protected by row level security keyed on team
membership.

### Keeping the project awake

Supabase pauses a free project after a week with no activity, and a season has
quiet weeks. `keepalive.yml` is a GitHub Action that pings the database twice a
week to prevent that.

1. Move it to `.github/workflows/keepalive.yml`.
2. **Repo Settings → Secrets and variables → Actions** → add `SUPABASE_URL` and
   `SUPABASE_ANON_KEY`.

Actions minutes are free on public repositories. If a project does pause, nothing
is lost — restore it from the Supabase dashboard.

### Adding coaches

Create a team and you own it. **Roster → Who can see this team → Invite a
coach**, enter their email. They get access the first time they sign in with
that address. Send them the app link yourself — the invite controls what they
see, it does not send mail.

### Moving your existing bullpens over

In the old version: **Roster → Backup → Download backup**. In the new one, sign
in, then **Roster → Backup → Restore from backup**. Old-style IDs are rewritten
to the database's format with every team, pitcher and session link preserved.
Restore merges, so running it twice changes nothing.

### Without Supabase

Leave `config.js` empty and the app works standalone: each coach's data stays in
their own browser, nothing is shared, and **Roster → Backup** is the only copy
you control. Download one after each session — clearing browser data erases
everything otherwise.

---

## Deploying it

The app is one self-contained HTML file plus icons. Any static host works.

### GitHub Pages

1. Create a repository named `bullpen-charts`.
2. Upload everything in this folder to the repository root.
3. **Settings → Pages → Source: Deploy from a branch**, branch `main`, folder `/ (root)`.
4. Wait a minute, then open `https://YOUR-USERNAME.github.io/bullpen-charts/`.

The repository can be public — there is no data in it, only the app. Anyone with
the link can use it; their bullpens stay on their own device.

### Updating

Replace `index.html` and commit. Installed copies pick up the new version the
next time they are opened with a connection — the service worker cache name is
stamped with a content hash at build time, so a changed app always invalidates
the old cache.

---

## Building from source

`bullpen-charts.html` is the single source of truth. It has no `<html>`/`<head>`
wrapper because it is also published as a Claude artifact, which supplies one.

```
python3 build.py
```

writes `dist/` — `index.html` (source wrapped in a full document), `sw.js` with a
fresh cache stamp, the icons, the manifest, `config.js`, `supabase-schema.sql`
and this README. Deploy `dist/`.

`config.js` is copied from `static/`, so put your real project values there if
you want them to survive a rebuild.

## What it does not do

- Velocity is typed in by hand. There is no radar integration.
- Offline charting works, but writes made offline are not queued for later — with
  Supabase connected, a pitch logged with no signal stays on that device.
- Anyone you invite to a team sees all of that team's bullpens. There are no
  per-pitcher permissions.

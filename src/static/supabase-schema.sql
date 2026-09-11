-- ============================================================================
-- Bullpen Charts — Supabase schema
--
-- Run this ONCE in your project's SQL editor (Dashboard → SQL Editor → New
-- query → paste → Run). It is safe to re-run: everything is IF NOT EXISTS or
-- CREATE OR REPLACE.
--
-- The access model: a coach sees a team only if there is a row for them in
-- team_members. That check runs inside Postgres on every query, so it cannot
-- be bypassed by anything the browser does — which is why the publishable key
-- is safe to ship in a static page.
-- ============================================================================

-- ---------------------------------------------------------------- profiles --
-- Mirrors auth.users so the app can show who is on a team without needing
-- privileged access to the auth schema.
create table if not exists public.profiles (
  id         uuid primary key references auth.users on delete cascade,
  email      text not null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------------- teams --
create table if not exists public.teams (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  zone_bot   double precision not null default 1.45,   -- feet off the ground
  zone_top   double precision not null default 3.10,
  types      text[] not null default '{FB,CH,CB}',
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------ memberships --
create table if not exists public.team_members (
  team_id    uuid not null references public.teams on delete cascade,
  user_id    uuid not null references auth.users on delete cascade,
  role       text not null default 'coach' check (role in ('owner','coach')),
  created_at timestamptz not null default now(),
  primary key (team_id, user_id)
);

-- ---------------------------------------------------------------- invites --
-- A coach can be invited before they have ever signed in, so invites are keyed
-- by email and converted to a membership the moment that email registers.
create table if not exists public.team_invites (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams on delete cascade,
  email      text not null,
  role       text not null default 'coach' check (role in ('owner','coach')),
  invited_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  unique (team_id, email)
);

-- --------------------------------------------------------------- pitchers --
create table if not exists public.pitchers (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams on delete cascade,
  name       text not null,
  number     text not null default '',
  throws     text not null default 'R' check (throws in ('R','L')),
  created_at timestamptz not null default now()
);
create index if not exists pitchers_team_idx on public.pitchers (team_id);

-- --------------------------------------------------------------- sessions --
-- One row per bullpen. The pitches live in a jsonb array because they are only
-- ever read and written as a whole session, and a 60-pitch pen is a few KB.
create table if not exists public.sessions (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams on delete cascade,
  pitcher_id uuid references public.pitchers on delete set null,
  date       date not null default current_date,
  label      text not null default '',
  notes      text not null default '',
  pitches    jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists sessions_team_date_idx on public.sessions (team_id, date desc);

-- ============================================================================
-- Helpers. SECURITY DEFINER so that checking membership does not itself
-- re-trigger the policies on team_members (which would recurse forever).
-- ============================================================================
create or replace function public.is_team_member(t uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = t and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_team_owner(t uuid)
returns boolean language sql security definer stable
set search_path = public as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = t and m.user_id = auth.uid() and m.role = 'owner'
  );
$$;

-- Whoever creates a team owns it.
create or replace function public.handle_new_team()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.team_members (team_id, user_id, role)
  values (new.id, auth.uid(), 'owner')
  on conflict do nothing;
  return new;
end $$;

drop trigger if exists on_team_created on public.teams;
create trigger on_team_created after insert on public.teams
  for each row execute function public.handle_new_team();

-- A new signup claims any invites waiting on their email address.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  insert into public.profiles (id, email)
  values (new.id, lower(new.email))
  on conflict (id) do update set email = excluded.email;

  insert into public.team_members (team_id, user_id, role)
  select i.team_id, new.id, i.role
    from public.team_invites i
   where lower(i.email) = lower(new.email)
  on conflict do nothing;

  delete from public.team_invites where lower(email) = lower(new.email);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- The signup trigger above only fires for BRAND NEW accounts. A coach who has
-- signed in before — because they were already on another team, or just tried
-- the app once — would otherwise never pick up a later invite. The app calls
-- this on every sign-in, so invites land whether the account is new or not.
create or replace function public.claim_invites()
returns integer language plpgsql security definer
set search_path = public as $$
declare
  em text;
  n  integer := 0;
begin
  if auth.uid() is null then return 0; end if;
  select lower(u.email) into em from auth.users u where u.id = auth.uid();
  if em is null then return 0; end if;

  insert into public.profiles (id, email) values (auth.uid(), em)
  on conflict (id) do update set email = excluded.email;

  insert into public.team_members (team_id, user_id, role)
  select i.team_id, auth.uid(), i.role
    from public.team_invites i
   where lower(i.email) = em
  on conflict do nothing;
  get diagnostics n = row_count;

  delete from public.team_invites where lower(email) = em;
  return n;
end $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists sessions_touch on public.sessions;
create trigger sessions_touch before update on public.sessions
  for each row execute function public.touch_updated_at();

-- ============================================================================
-- Row level security. Nothing is readable until a policy says so.
-- ============================================================================
alter table public.profiles     enable row level security;
alter table public.teams        enable row level security;
alter table public.team_members enable row level security;
alter table public.team_invites enable row level security;
alter table public.pitchers     enable row level security;
alter table public.sessions     enable row level security;

-- profiles: you can read yourself, and anyone you share a team with.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (
    id = auth.uid()
    or exists (
      select 1 from public.team_members me
      join public.team_members them on them.team_id = me.team_id
      where me.user_id = auth.uid() and them.user_id = public.profiles.id
    )
  );

drop policy if exists profiles_self_write on public.profiles;
create policy profiles_self_write on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- teams
drop policy if exists teams_read on public.teams;
create policy teams_read on public.teams for select
  using (public.is_team_member(id));

drop policy if exists teams_insert on public.teams;
create policy teams_insert on public.teams for insert
  with check (auth.uid() is not null and created_by = auth.uid());

drop policy if exists teams_update on public.teams;
create policy teams_update on public.teams for update
  using (public.is_team_member(id)) with check (public.is_team_member(id));

drop policy if exists teams_delete on public.teams;
create policy teams_delete on public.teams for delete
  using (public.is_team_owner(id));

-- memberships: members can see the staff list; only owners change it.
drop policy if exists members_read on public.team_members;
create policy members_read on public.team_members for select
  using (public.is_team_member(team_id));

drop policy if exists members_write on public.team_members;
create policy members_write on public.team_members for all
  using (public.is_team_owner(team_id)) with check (public.is_team_owner(team_id));

-- A coach can always remove themselves from a team.
drop policy if exists members_leave on public.team_members;
create policy members_leave on public.team_members for delete
  using (user_id = auth.uid());

-- invites: owners manage them; an invitee can see their own pending invite.
drop policy if exists invites_read on public.team_invites;
create policy invites_read on public.team_invites for select
  using (public.is_team_owner(team_id) or lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists invites_write on public.team_invites;
create policy invites_write on public.team_invites for all
  using (public.is_team_owner(team_id)) with check (public.is_team_owner(team_id));

-- pitchers and sessions: any member of the team, full access.
drop policy if exists pitchers_all on public.pitchers;
create policy pitchers_all on public.pitchers for all
  using (public.is_team_member(team_id)) with check (public.is_team_member(team_id));

drop policy if exists sessions_all on public.sessions;
create policy sessions_all on public.sessions for all
  using (public.is_team_member(team_id)) with check (public.is_team_member(team_id));

-- ============================================================================
-- Realtime — this is what makes two coaches at the same pen see each other.
-- ============================================================================
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end $$;

-- ADD TABLE errors if the table is already published, so check first — this
-- whole script is meant to be safe to run again.
do $$
declare t text;
begin
  foreach t in array array['sessions','pitchers','teams'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- Realtime needs the full old row to report deletes correctly.
alter table public.sessions replica identity full;
alter table public.pitchers replica identity full;
alter table public.teams    replica identity full;

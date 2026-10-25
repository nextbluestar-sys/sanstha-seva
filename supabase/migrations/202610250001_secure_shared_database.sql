-- Sanstha Seva secure shared database for Supabase.
-- Run this entire file in Supabase Dashboard > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Sanstha Seva member',
  role text not null default 'member' check (role in ('admin','staff','member')),
  family_id text,
  member_id text,
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id text primary key,
  name text not null,
  phone text not null default '',
  village text not null default '',
  family_id text not null,
  relation text not null default 'Member',
  monthly numeric(12,2) not null default 0 check (monthly >= 0),
  address text not null default '',
  photo text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.donations (
  id text primary key,
  member_id text not null references public.members(id) on update cascade,
  name text not null default '',
  amount numeric(12,2) not null check (amount > 0),
  mode text not null default 'Cash',
  date date not null default current_date,
  status text not null default 'Paid' check (status in ('Paid','Pending','Failed','Refunded')),
  reference text not null default '',
  family_id text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  details text not null default '',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists members_family_id_idx on public.members(family_id);
create index if not exists donations_member_id_idx on public.donations(member_id);
create index if not exists donations_date_idx on public.donations(date desc);
create index if not exists profiles_family_id_idx on public.profiles(family_id);

-- Helper functions run with owner privileges to avoid recursive profile RLS checks.
create or replace function public.is_sanstha_staff()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('admin','staff')); $$;

create or replace function public.is_sanstha_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'); $$;

revoke all on function public.is_sanstha_staff() from public, anon;
revoke all on function public.is_sanstha_admin() from public, anon;
grant execute on function public.is_sanstha_staff() to authenticated;
grant execute on function public.is_sanstha_admin() to authenticated;

-- New accounts always start as member; never accept role from browser metadata.
create or replace function public.handle_new_sanstha_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (new.id, coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1), 'Sanstha Seva member'), 'member')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_sanstha on auth.users;
create trigger on_auth_user_created_sanstha
after insert on auth.users for each row execute procedure public.handle_new_sanstha_user();

alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.donations enable row level security;
alter table public.announcements enable row level security;

-- Revoke broad access explicitly; grant only intended operations to signed-in users.
revoke all on public.profiles, public.members, public.donations, public.announcements from anon;
revoke all on public.profiles, public.members, public.donations, public.announcements from authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, family_id, member_id, role) on public.profiles to authenticated;
grant select, insert, update, delete on public.members to authenticated;
grant select, insert, update, delete on public.donations to authenticated;
grant select, insert, update, delete on public.announcements to authenticated;

-- Profiles: users can read only themselves; staff can read all; only admin can update.
drop policy if exists profiles_read_self_or_staff on public.profiles;
create policy profiles_read_self_or_staff on public.profiles for select to authenticated
using (id = auth.uid() or public.is_sanstha_staff());
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles for update to authenticated
using (public.is_sanstha_admin()) with check (public.is_sanstha_admin());

-- Members: staff can manage all members; ordinary members can read their assigned family only.
drop policy if exists members_read_staff_or_family on public.members;
create policy members_read_staff_or_family on public.members for select to authenticated
using (public.is_sanstha_staff() or family_id = (select p.family_id from public.profiles p where p.id = auth.uid()));
drop policy if exists members_insert_staff on public.members;
create policy members_insert_staff on public.members for insert to authenticated
with check (public.is_sanstha_staff());
drop policy if exists members_update_staff on public.members;
create policy members_update_staff on public.members for update to authenticated
using (public.is_sanstha_staff()) with check (public.is_sanstha_staff());
drop policy if exists members_delete_staff on public.members;
create policy members_delete_staff on public.members for delete to authenticated
using (public.is_sanstha_staff());

-- Donations: staff can manage all; members can read donations for their assigned family only.
drop policy if exists donations_read_staff_or_family on public.donations;
create policy donations_read_staff_or_family on public.donations for select to authenticated
using (public.is_sanstha_staff() or exists (
  select 1 from public.members m join public.profiles p on p.id = auth.uid()
  where m.id = donations.member_id and m.family_id = p.family_id
));
drop policy if exists donations_insert_staff on public.donations;
create policy donations_insert_staff on public.donations for insert to authenticated
with check (public.is_sanstha_staff());
drop policy if exists donations_update_staff on public.donations;
create policy donations_update_staff on public.donations for update to authenticated
using (public.is_sanstha_staff()) with check (public.is_sanstha_staff());
drop policy if exists donations_delete_staff on public.donations;
create policy donations_delete_staff on public.donations for delete to authenticated
using (public.is_sanstha_staff());

-- Announcements are visible to signed-in users; only staff may publish or edit them.
drop policy if exists announcements_read_authenticated on public.announcements;
create policy announcements_read_authenticated on public.announcements for select to authenticated using (true);
drop policy if exists announcements_insert_staff on public.announcements;
create policy announcements_insert_staff on public.announcements for insert to authenticated with check (public.is_sanstha_staff());
drop policy if exists announcements_update_staff on public.announcements;
create policy announcements_update_staff on public.announcements for update to authenticated using (public.is_sanstha_staff()) with check (public.is_sanstha_staff());
drop policy if exists announcements_delete_staff on public.announcements;
create policy announcements_delete_staff on public.announcements for delete to authenticated using (public.is_sanstha_staff());

-- After a user signs up and confirms their email, promote the first administrator manually:
-- update public.profiles set role = 'admin' where id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');

-- Sanstha Seva username/password migration. Run AFTER the original secure database setup.
-- Username login uses a reserved, non-deliverable synthetic email internally; members never need email.
alter table public.profiles add column if not exists username text;

-- Backfill usernames from existing synthetic/email logins where possible.
update public.profiles p
set username = lower(split_part(u.email, '@', 1))
from auth.users u
where p.id = u.id and (p.username is null or p.username = '');

create unique index if not exists profiles_username_unique on public.profiles (lower(username)) where username is not null;

create or replace function public.handle_new_sanstha_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username, display_name, role, family_id, member_id)
  values (
    new.id,
    lower(coalesce(nullif(new.raw_user_meta_data->>'username',''), split_part(new.email,'@',1))),
    coalesce(nullif(new.raw_user_meta_data->>'display_name',''), split_part(new.email,'@',1), 'Sanstha Seva member'),
    'member',
    nullif(new.raw_user_meta_data->>'family_id',''),
    nullif(new.raw_user_meta_data->>'member_id','')
  )
  on conflict (id) do update set
    username = excluded.username,
    display_name = excluded.display_name,
    family_id = excluded.family_id,
    member_id = excluded.member_id;
  return new;
end;
$$;

-- Username is visible only to the signed-in account or staff, via existing profiles RLS.
-- Existing RLS remains enabled; this migration does not expose tables to anonymous visitors.

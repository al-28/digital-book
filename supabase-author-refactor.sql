-- DIGITAL BOOK — AUTHOR / PROFILE SYSTEM
-- Run once after supabase-repair.sql.
-- Safe for existing books and users.

create table if not exists public.author_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Author',
  slug text not null unique,
  bio text not null default '',
  website text not null default '',
  avatar_path text,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.author_profiles enable row level security;
grant select on public.author_profiles to anon, authenticated;
grant insert, update, delete on public.author_profiles to authenticated;

drop policy if exists "Authors manage their own profile" on public.author_profiles;
create policy "Authors manage their own profile"
on public.author_profiles
for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Anyone can read public author profiles" on public.author_profiles;
create policy "Anyone can read public author profiles"
on public.author_profiles
for select to anon, authenticated
using (is_public = true);

alter table public.books add column if not exists author_id uuid references public.author_profiles(user_id) on delete set null;
create index if not exists books_author_id_idx on public.books(author_id);

insert into public.author_profiles(user_id, display_name, slug)
select
  u.id,
  coalesce(nullif(trim(u.raw_user_meta_data->>'display_name'),''), nullif(trim(u.raw_user_meta_data->>'full_name'),''), split_part(coalesce(u.email,''),'@',1), 'Author'),
  'author-' || replace(u.id::text,'-','')
from auth.users u
where not exists (select 1 from public.author_profiles p where p.user_id = u.id)
on conflict (slug) do nothing;

update public.books b
set author_id = p.user_id
from public.author_profiles p
where b.author_id is null and p.user_id = b.user_id;

update public.author_profiles p
set display_name = src.author_name, updated_at = now()
from (
  select distinct on (b.user_id) b.user_id, nullif(trim(b.author),'') as author_name
  from public.books b
  where nullif(trim(b.author),'') is not null
  order by b.user_id, b.created_at asc
) src
where p.user_id = src.user_id
  and coalesce(nullif(trim(p.display_name),''),'Author') = 'Author'
  and src.author_name is not null;

drop policy if exists "Anyone can read public author avatars" on storage.objects;
create policy "Anyone can read public author avatars"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'photos'
  and exists (
    select 1 from public.author_profiles p
    where p.avatar_path = storage.objects.name and p.is_public = true
  )
);

create index if not exists author_profiles_public_idx on public.author_profiles(is_public, updated_at desc);
create index if not exists author_profiles_slug_idx on public.author_profiles(slug);

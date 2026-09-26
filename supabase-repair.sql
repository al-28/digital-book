-- DIGITAL BOOK V1.8 REPAIR / MIGRATION
-- Run this once in Supabase SQL Editor on an existing Digital Book project.
-- It is safe to re-run and preserves existing books, photos, sections and covers.

create extension if not exists pgcrypto;

-- Core book table
create table if not exists public.books (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'My Book',
  cover_path text,
  created_at timestamptz not null default now()
);

alter table public.books add column if not exists is_public boolean not null default false;
alter table public.books add column if not exists description text not null default '';
alter table public.books add column if not exists author text not null default '';
alter table public.books enable row level security;

-- Core sections
create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.books(id) on delete cascade,
  name text not null,
  position bigint not null default 0,
  created_at timestamptz not null default now()
);
alter table public.sections enable row level security;

-- Existing photos table: add book/section relationships if an older version is installed.
alter table public.photos add column if not exists book_id uuid references public.books(id) on delete cascade;
alter table public.photos add column if not exists section_id uuid references public.sections(id) on delete set null;

-- Compatibility table from V1.1.
create table if not exists public.book_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null default 'My Book',
  updated_at timestamptz not null default now()
);
alter table public.book_settings enable row level security;

-- Give every existing user/photo a book before enforcing the relationship.
insert into public.books(user_id,title)
select bs.user_id, coalesce(nullif(trim(bs.title),''),'My Book')
from public.book_settings bs
where not exists (
  select 1 from public.books b where b.user_id = bs.user_id
);

insert into public.books(user_id,title)
select distinct p.user_id, 'My Book'
from public.photos p
where not exists (
  select 1 from public.books b where b.user_id = p.user_id
);

update public.photos p
set book_id = b.id
from public.books b
where p.book_id is null
  and p.user_id = b.user_id;

-- Remove any impossible orphan relationship before making it required.
delete from public.photos
where book_id is null;

alter table public.photos alter column book_id set not null;

create index if not exists books_user_created_idx
  on public.books(user_id, created_at);
create index if not exists books_public_created_idx
  on public.books(is_public, created_at desc);
create index if not exists photos_book_position_idx
  on public.photos(book_id, position);
create index if not exists photos_user_position_idx
  on public.photos(user_id, position);
create index if not exists sections_book_position_idx
  on public.sections(book_id, position);

-- Grants used by the browser Data API.
grant select, insert, update, delete on public.books to authenticated;
grant select on public.books to anon;
grant select, insert, update, delete on public.sections to authenticated;
grant select on public.sections to anon;
grant select, insert, update, delete on public.photos to authenticated;
grant select on public.photos to anon;
grant select, insert, update, delete on public.book_settings to authenticated;

-- BOOK POLICIES
drop policy if exists "Users can manage their own books" on public.books;
drop policy if exists "Anyone can read published books" on public.books;

create policy "Users can manage their own books"
on public.books
for all
to authenticated
using ((select (select auth.uid())) = user_id)
with check ((select (select auth.uid())) = user_id);

create policy "Anyone can read published books"
on public.books
for select
to anon, authenticated
using (is_public = true);

-- SECTION POLICIES
drop policy if exists "Users can manage their own sections" on public.sections;
drop policy if exists "Anyone can read sections from published books" on public.sections;

create policy "Users can manage their own sections"
on public.sections
for all
to authenticated
using (
  exists (
    select 1 from public.books b
    where b.id = sections.book_id
      and b.user_id = (select (select auth.uid()))
  )
)
with check (
  exists (
    select 1 from public.books b
    where b.id = sections.book_id
      and b.user_id = (select (select auth.uid()))
  )
);

create policy "Anyone can read sections from published books"
on public.sections
for select
to anon, authenticated
using (
  exists (
    select 1 from public.books b
    where b.id = sections.book_id
      and b.is_public = true
  )
);

-- PHOTO POLICIES
drop policy if exists "Users can read their own photos" on public.photos;
drop policy if exists "Users can insert their own photos" on public.photos;
drop policy if exists "Users can update their own photos" on public.photos;
drop policy if exists "Users can delete their own photos" on public.photos;
drop policy if exists "Anyone can read photos from published books" on public.photos;

create policy "Users can read their own photos"
on public.photos
for select
to authenticated
using ((select (select auth.uid())) = user_id);

create policy "Users can insert their own photos"
on public.photos
for insert
to authenticated
with check (
  (select (select auth.uid())) = user_id
  and exists (
    select 1 from public.books b
    where b.id = photos.book_id
      and b.user_id = (select (select auth.uid()))
  )
  and (
    photos.section_id is null
    or exists (
      select 1
      from public.books b2
      join public.sections s2 on s2.book_id = b2.id
      where b2.id = photos.book_id
        and s2.id = photos.section_id
    )
  )
);

create policy "Users can update their own photos"
on public.photos
for update
to authenticated
using ((select (select auth.uid())) = user_id)
with check (
  (select (select auth.uid())) = user_id
  and exists (
    select 1 from public.books b
    where b.id = photos.book_id
      and b.user_id = (select (select auth.uid()))
  )
  and (
    section_id is null
    or exists (
      select 1 from public.sections s
      where s.id = photos.section_id
        and s.book_id = photos.book_id
    )
  )
);

create policy "Users can delete their own photos"
on public.photos
for delete
to authenticated
using ((select (select auth.uid())) = user_id);

create policy "Anyone can read photos from published books"
on public.photos
for select
to anon, authenticated
using (
  exists (
    select 1 from public.books b
    where b.id = photos.book_id
      and b.is_public = true
  )
);

-- BOOK SETTINGS POLICIES
drop policy if exists "Users can read their own book settings" on public.book_settings;
drop policy if exists "Users can insert their own book settings" on public.book_settings;
drop policy if exists "Users can update their own book settings" on public.book_settings;

create policy "Users can read their own book settings"
on public.book_settings for select to authenticated
using ((select (select auth.uid())) = user_id);

create policy "Users can insert their own book settings"
on public.book_settings for insert to authenticated
with check ((select (select auth.uid())) = user_id);

create policy "Users can update their own book settings"
on public.book_settings for update to authenticated
using ((select (select auth.uid())) = user_id)
with check ((select (select auth.uid())) = user_id);

-- STORAGE
insert into storage.buckets (id,name,public)
values ('photos','photos',false)
on conflict (id) do update set public=false;

drop policy if exists "Users can upload their own book photos" on storage.objects;
drop policy if exists "Users can view their own book photos" on storage.objects;
drop policy if exists "Users can delete their own book photos" on storage.objects;
drop policy if exists "Users can update their own book photos" on storage.objects;
drop policy if exists "Anyone can read storage for published books" on storage.objects;

create policy "Users can upload their own book photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select (select auth.uid()))::text
);

create policy "Users can view their own book photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select (select auth.uid()))::text
);

create policy "Users can update their own book photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select (select auth.uid()))::text
)
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select (select auth.uid()))::text
);

create policy "Users can delete their own book photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select (select auth.uid()))::text
);

-- Public signed URLs: published photo files AND published cover files.
create policy "Anyone can read storage for published books"
on storage.objects for select
to anon, authenticated
using (
  bucket_id = 'photos'
  and (
    exists (
      select 1
      from public.photos p
      join public.books b on b.id = p.book_id
      where p.storage_path = storage.objects.name
        and b.is_public = true
    )
    or exists (
      select 1
      from public.books b
      where b.cover_path = storage.objects.name
        and b.is_public = true
    )
  )
);

-- Make the browser-facing schema explicitly available.
grant select on public.books, public.sections, public.photos to anon;
grant select, insert, update, delete on public.books, public.sections, public.photos to authenticated;


-- V2.0: favorites and bookmarks
create table if not exists public.book_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, book_id)
);
alter table public.book_favorites enable row level security;
grant select, insert, delete on public.book_favorites to authenticated;
drop policy if exists "Users can manage their own favorites" on public.book_favorites;
create policy "Users can manage their own favorites"
on public.book_favorites for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create table if not exists public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  book_id uuid not null references public.books(id) on delete cascade,
  photo_id uuid not null references public.photos(id) on delete cascade,
  page_index integer not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, photo_id)
);
alter table public.bookmarks enable row level security;
create index if not exists bookmarks_user_book_idx on public.bookmarks(user_id, book_id, created_at desc);
grant select, insert, delete on public.bookmarks to authenticated;
drop policy if exists "Users can manage their own bookmarks" on public.bookmarks;
create policy "Users can manage their own bookmarks"
on public.bookmarks for all to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.books b where b.id = book_id and b.user_id = (select auth.uid()))
  and exists (select 1 from public.photos p where p.id = photo_id and p.book_id = book_id and p.user_id = (select auth.uid()))
);

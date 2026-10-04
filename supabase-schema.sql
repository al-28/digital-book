-- DIGITAL BOOK — SUPABASE SETUP
-- Run this entire script in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.photos (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  filename text not null,
  caption text not null default '',
  position bigint not null default 0,
  created_at timestamptz not null default now()
);

alter table public.photos enable row level security;

drop policy if exists "Users can read their own photos" on public.photos;
create policy "Users can read their own photos"
on public.photos for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own photos" on public.photos;
create policy "Users can insert their own photos"
on public.photos for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own photos" on public.photos;
create policy "Users can update their own photos"
on public.photos for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own photos" on public.photos;
create policy "Users can delete their own photos"
on public.photos for delete
to authenticated
using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do update set public = false;

drop policy if exists "Users can upload their own book photos" on storage.objects;
create policy "Users can upload their own book photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can view their own book photos" on storage.objects;
create policy "Users can view their own book photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can delete their own book photos" on storage.objects;
create policy "Users can delete their own book photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users can update their own book photos" on storage.objects;
create policy "Users can update their own book photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create index if not exists photos_user_position_idx
on public.photos(user_id, position);

create index if not exists photos_user_created_idx
on public.photos(user_id, created_at);


create table if not exists public.book_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null default 'My Book',
  updated_at timestamptz not null default now()
);

alter table public.book_settings enable row level security;

drop policy if exists "Users can read their own book settings" on public.book_settings;
create policy "Users can read their own book settings" on public.book_settings for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own book settings" on public.book_settings;
create policy "Users can insert their own book settings" on public.book_settings for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their own book settings" on public.book_settings;
create policy "Users can update their own book settings" on public.book_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- V1.2: multiple books and sections
create table if not exists public.books (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null default 'My Book',
 cover_path text,
 created_at timestamptz not null default now()
);
alter table public.books enable row level security;
drop policy if exists "Users can manage their own books" on public.books;
create policy "Users can manage their own books" on public.books for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create table if not exists public.sections (
 id uuid primary key default gen_random_uuid(),
 book_id uuid not null references public.books(id) on delete cascade,
 name text not null,
 position bigint not null default 0,
 created_at timestamptz not null default now()
);
alter table public.sections enable row level security;
drop policy if exists "Users can manage their own sections" on public.sections;
create policy "Users can manage their own sections" on public.sections for all to authenticated
using (exists(select 1 from public.books b where b.id=book_id and b.user_id=(select auth.uid())))
with check (exists(select 1 from public.books b where b.id=book_id and b.user_id=(select auth.uid())));

alter table public.photos add column if not exists book_id uuid references public.books(id) on delete cascade;
alter table public.photos add column if not exists section_id uuid references public.sections(id) on delete set null;
insert into public.books(user_id,title)
select user_id,coalesce(title,'My Book') from public.book_settings
where not exists(select 1 from public.books b where b.user_id=public.book_settings.user_id);
insert into public.books(user_id,title)
select distinct p.user_id,'My Book' from public.photos p
where not exists(select 1 from public.books b where b.user_id=p.user_id);
update public.photos p set book_id=b.id from public.books b where p.user_id=b.user_id and p.book_id is null;
-- After the migration above, every photo must belong to a book.
alter table public.photos alter column book_id set not null;
create index if not exists photos_book_position_idx on public.photos(book_id,position);


-- V1.4: now that books/sections exist, enforce that each photo stays inside
-- a book owned by the same user and that its section belongs to that book.
drop policy if exists "Users can insert their own photos" on public.photos;
create policy "Users can insert their own photos"
on public.photos for insert
to authenticated
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.books b where b.id = book_id and b.user_id = (select auth.uid()))
  and (
    section_id is null
    or exists (
      select 1
      from public.books b2
      join public.sections s2 on s2.book_id = b2.id
      where b2.id = photos.book_id
        and s2.id = photos.section_id
    )
  )
);

drop policy if exists "Users can update their own photos" on public.photos;
create policy "Users can update their own photos"
on public.photos for update
to authenticated
using ((select auth.uid()) = user_id)
with check (
  (select auth.uid()) = user_id
  and exists (select 1 from public.books b where b.id = book_id and b.user_id = (select auth.uid()))
  and (section_id is null or exists (
    select 1 from public.sections s where s.id = section_id and s.book_id = book_id
  ))
);


-- V1.7: public book discovery/library
alter table public.books add column if not exists is_public boolean not null default false;
alter table public.books add column if not exists description text not null default '';
alter table public.books add column if not exists author text not null default '';

create index if not exists books_public_created_idx
on public.books(is_public, created_at desc);

-- Keep owner management, and allow the public to read only published books.
drop policy if exists "Users can manage their own books" on public.books;
drop policy if exists "Anyone can read published books" on public.books;

create policy "Users can manage their own books"
on public.books for all to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Anyone can read published books"
on public.books for select
to anon, authenticated
using (is_public = true);

-- Published photos are readable only when their parent book is published.
drop policy if exists "Anyone can read photos from published books" on public.photos;
create policy "Anyone can read photos from published books"
on public.photos for select
to anon, authenticated
using (
  exists (
    select 1
    from public.books b
    where b.id = photos.book_id
      and b.is_public = true
  )
);

-- Signed URLs for the private photos bucket still require SELECT on storage.objects.
-- This policy exposes only objects that are attached to a published book.
drop policy if exists "Anyone can read storage for published books" on storage.objects;
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


-- Public readers can see section/chapter names for published books.
drop policy if exists "Anyone can read sections from published books" on public.sections;
create policy "Anyone can read sections from published books"
on public.sections for select
to anon, authenticated
using (
  exists (
    select 1 from public.books b
    where b.id = sections.book_id
      and b.is_public = true
  )
);


-- V1.8: browser-facing grants. RLS still controls which rows are reachable.
grant select, insert, update, delete on public.books to authenticated;
grant select on public.books to anon;
grant select, insert, update, delete on public.sections to authenticated;
grant select on public.sections to anon;
grant select, insert, update, delete on public.photos to authenticated;
grant select on public.photos to anon;



-- Chapter ordering and page-assignment indexes.
create index if not exists sections_book_position_idx on public.sections(book_id,position);
create index if not exists photos_section_idx on public.photos(section_id);

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

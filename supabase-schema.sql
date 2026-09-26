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
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own photos" on public.photos;
create policy "Users can insert their own photos"
on public.photos for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own photos" on public.photos;
create policy "Users can update their own photos"
on public.photos for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own photos" on public.photos;
create policy "Users can delete their own photos"
on public.photos for delete
to authenticated
using (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do update set public = false;

drop policy if exists "Users can upload their own book photos" on storage.objects;
create policy "Users can upload their own book photos"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can view their own book photos" on storage.objects;
create policy "Users can view their own book photos"
on storage.objects for select
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can delete their own book photos" on storage.objects;
create policy "Users can delete their own book photos"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Users can update their own book photos" on storage.objects;
create policy "Users can update their own book photos"
on storage.objects for update
to authenticated
using (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'photos'
  and (storage.foldername(name))[1] = auth.uid()::text
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
create policy "Users can read their own book settings" on public.book_settings for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Users can insert their own book settings" on public.book_settings;
create policy "Users can insert their own book settings" on public.book_settings for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users can update their own book settings" on public.book_settings;
create policy "Users can update their own book settings" on public.book_settings for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

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
create policy "Users can manage their own books" on public.books for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);

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
using (exists(select 1 from public.books b where b.id=book_id and b.user_id=auth.uid()))
with check (exists(select 1 from public.books b where b.id=book_id and b.user_id=auth.uid()));

alter table public.photos add column if not exists book_id uuid references public.books(id) on delete cascade;
alter table public.photos add column if not exists section_id uuid references public.sections(id) on delete set null;
insert into public.books(user_id,title)
select user_id,coalesce(title,'My Book') from public.book_settings
where not exists(select 1 from public.books b where b.user_id=public.book_settings.user_id);
insert into public.books(user_id,title)
select distinct p.user_id,'My Book' from public.photos p
where not exists(select 1 from public.books b where b.user_id=p.user_id);
update public.photos p set book_id=b.id from public.books b where p.user_id=b.user_id and p.book_id is null;
create index if not exists photos_book_position_idx on public.photos(book_id,position);

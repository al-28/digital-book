-- DIGITAL BOOK — SUPABASE SETUP
-- Run this entire script in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.photos (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null unique,
  filename text not null,
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

# Digital Book

A private, cloud-backed digital photo book designed to work from Mac, iPhone, iPad, and other devices.

## Architecture

- GitHub Pages: hosts `index.html`
- Supabase Auth: account/login
- Supabase Postgres: photo metadata and order
- Supabase Storage: private original photos
- No traditional server is required

## Setup

### 1. Create Supabase project

Create a project at https://supabase.com/

### 2. Create the database/storage

Open **SQL Editor** in Supabase and run the complete contents of:

`supabase-schema.sql`

This creates:

- `photos` table
- Row Level Security
- private `photos` storage bucket
- storage security policies
- indexes

### 3. Get Supabase credentials

In Supabase, open **Project Settings → API**.

Copy:

- Project URL
- Publishable/anon key

Only the public/anon key belongs in the browser. Never put a service-role key in `index.html`.

### 4. Configure index.html

Near the bottom of `index.html`, replace:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

with your project values.

### 5. GitHub Pages

Push the repository to GitHub and enable:

**Settings → Pages → Deploy from branch → main → /(root)**

Then open the GitHub Pages URL.

## Current V1 features

- Email/password authentication
- Private cloud photo storage
- Multiple-photo upload
- Drag-and-drop upload
- Uploads appended to the end
- Drag-and-drop reordering
- Persistent ordering
- Delete photos
- Responsive desktop/mobile interface
- Same book across devices
- Private storage with signed image URLs

## Important

The website cannot securely provide cross-device cloud storage using GitHub Pages alone. Supabase supplies the backend/database/storage while GitHub Pages supplies the frontend.

## Next planned features

- Book title and cover
- Sections/chapters
- Captions
- Multiple books
- Photo replacement
- PDF export
- Backup/export
- PWA installation
- Better touch-based reordering

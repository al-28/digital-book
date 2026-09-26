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
- Editable book title
- Per-photo captions
- Full-screen photo viewer with keyboard navigation
- Responsive desktop/mobile interface
- Same book across devices
- Private storage with signed image URLs

## Important

The website cannot securely provide cross-device cloud storage using GitHub Pages alone. Supabase supplies the backend/database/storage while GitHub Pages supplies the frontend.

## V1.1

V1.1 adds an editable persistent book title, per-photo captions, and a full-screen viewer with previous/next navigation and Escape/arrow-key controls. Re-run the complete `supabase-schema.sql` in Supabase SQL Editor so the new `caption` column and `book_settings` table are created.

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

## V1.4 — reliability, book library, and Google login

V1.4 fixes several issues discovered during a full project audit:

- Restores the Reading Mode HTML that the V1.3 JavaScript expected.
- Fixes JavaScript blockers that could prevent the app from starting.
- Makes the **Cancel** button in authentication reliably close and reset the dialog.
- Adds **Continue with Google** through Supabase Auth.
- Adds **Forgot your password?** recovery.
- Adds a **My Books** library so every saved book can be reopened.
- Remembers the last selected book on each device.
- Keeps photos attached to their specific book.
- Prevents photo records from being assigned to another user's book or to a section belonging to another book.
- Fixes section-specific reordering so it does not renumber unrelated sections.
- Hardens logged-out controls and logout/auth state transitions.

### Where is an uploaded book?

The website itself does not store your books in the browser or inside GitHub. After you upload photos, the app stores:

- the book and its title/cover in Supabase Postgres (`books`)
- the photo metadata/order in Supabase Postgres (`photos`)
- the original image files in the private Supabase Storage `photos` bucket

When you sign in again, use **My Books** or the book selector at the top to reopen the book. The same account can access the same books from another phone or computer. Private files are displayed through temporary signed URLs rather than public image URLs.


### Account storage and authentication

User accounts are **not supposed to be stored in the Storage bucket**. Supabase Auth creates and stores accounts in the project's protected `auth.users` table. The browser uses the Supabase publishable/anon key to call Auth; Row Level Security protects the app's own `books`, `sections`, and `photos` tables.

The app does not need a separate account table or a second password database. Adding a database trigger just for signup would add another failure point, so this project intentionally lets Supabase Auth remain the source of truth for accounts.

V1.6 also pins the Supabase JavaScript SDK to a current stable release, keeps browser session persistence enabled, keeps the Cancel button usable during authentication, adds a timeout so a stuck Auth request cannot leave the dialog permanently on "Creating…", and adds a resend-confirmation action when email confirmation is required.

If signup appears stuck, check **Supabase → Authentication → Users** first. If the user exists there but is unconfirmed, the account was created and the next step is email confirmation. Supabase's built-in email provider is intended for testing and has a low sending limit; production email delivery should use custom SMTP.

### Google login setup

The code now includes the Google sign-in button, but Google must also be enabled in your Supabase project.

1. In Supabase, open **Authentication → Providers → Google** and enable Google.
2. Create a **Web application** OAuth client in Google Cloud.
3. Add your deployed site's origin to Google's authorized JavaScript origins.
4. Add the Supabase callback URL shown on the Supabase Google provider page to Google's authorized redirect URIs.
5. In Supabase **Authentication → URL Configuration**, set your production Site URL and add the exact site URL as an allowed redirect URL.
6. Put the Google Client ID and Client Secret into the Supabase Google provider settings.

The frontend uses the current page as the OAuth redirect target, so the deployed GitHub Pages URL must be allowed by Supabase.

### Password recovery

The **Forgot your password?** button sends a Supabase recovery email and returns the user to the app. Supabase must have the production site URL/redirect URL configured, and email delivery must be enabled.

### Security model

Keep the Supabase publishable/anon key in the browser only. Never put a Supabase service-role/secret key in `index.html`. The database and storage RLS policies are responsible for restricting each user's books, photos, and files.

### Deployment

This project is a static frontend, so GitHub Pages is the simplest deployment target. Fly.io can host static files too, but would add a container/web-server layer that this project does not currently need.
## V1.7 — Public Library

The app now includes a public discovery page for books that their owners choose to publish.

### Public library behavior

- **Public Library** is visible without logging in.
- Search books by title, author, or description.
- Published books can be opened directly into Reading Mode.
- Published books expose their chapters/sections and book pages to public readers.
- A book is **private by default**. The owner can use **Publish** to make it discoverable, and **Unpublish** to remove it from the public library.
- The existing private account/book workflow remains available under **My Books**.

### V1.7 Supabase migration

Run the updated `supabase-schema.sql` in the Supabase SQL Editor. The migration adds:

- `books.is_public`
- `books.author`
- `books.description`
- public-read RLS policies for published books, sections, photos, and their storage objects
- an index for public-book discovery

The existing `photos` bucket stays private. Only files belonging to a published book are readable by public readers through the new RLS policies.

This follows Supabase's RLS model: public data should have an explicit `SELECT` policy, and private Storage files require `SELECT` permission for signed URLs.
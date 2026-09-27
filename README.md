# Voidhold

Browser empire game in the OGame family: one planet, three structures, propulsion research, raiders, and a 10×10 galaxy of derelicts. Timers keep running while the app is closed. The server owns resources and combat.

## Play locally

```bash
npm install
cp .env.local.example .env.local
npm run dev
```

The game needs a **dedicated** Supabase project named `voidhold` (do not reuse Miaudoku or family-finances). Fill `.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_OR_PUBLISHABLE_KEY
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

Then:

1. Run every file in [`supabase/migrations/`](supabase/migrations/) in numeric order (`001` … `034`) in the SQL editor, **or** `npx supabase link --project-ref <ref>` then `npx supabase db push`. Vercel deploys the app only; it does not apply SQL. After applying, run [`supabase/verify_migrations.sql`](supabase/verify_migrations.sql) and confirm every row shows `exists = true`.
2. Authentication → URL configuration: add `http://localhost:3000/auth/callback` and your production `/auth/callback`.
3. Enable Email (magic link).

```bash
npm test
npm run dev
```

Open [http://localhost:3000](http://localhost:3000), sign in, upgrade mines, build a raider, and raid a brown **N** cell on the galaxy map.

## Vercel

Import this folder (or its GitHub repo) in Vercel, set the same `NEXT_PUBLIC_*` env vars, and deploy. Add the production URL to Supabase redirect URLs and to `NEXT_PUBLIC_SITE_URL`.

## Google Play

The Android wrapper loads the hosted web app (auth + server actions need a real origin). See [docs/PLAY_STORE.md](docs/PLAY_STORE.md).

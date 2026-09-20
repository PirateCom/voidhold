# Google Play listing — Voidhold

Package: `com.voidhold.game`

Voidhold is a live space-empire game. The Play app is a Capacitor shell around the hosted Next.js game so accounts, resource timers, and combat stay server-authoritative.

Do not ship until the web loop is playable on the production URL, then point `VOIDHOLD_SERVER_URL` at that origin.

## Short description (80 characters max)

Hold a world in the dark. Mine, research, and raid derelicts in a tiny galaxy.

## Full description

Voidhold is a small persistent space empire.

You start with one planet. Upgrade the ore mine, crystal mine, and power plant. Research propulsion, build raiders, and send them across a 10×10 galaxy to strip abandoned worlds. Buildings and fleets keep running while the app is closed.

Sign in with an email magic link. Progress is stored in your Voidhold account.

## Privacy policy URL

Host the in-app `/privacy` page (or this file’s privacy paragraph) on the production HTTPS origin and paste that URL into Play Console.

## Data safety form

- Data collected: Yes (account email, game progress)
- Data shared: No (beyond the hosting/auth provider needed to run the game)
- Encrypted in transit: Yes
- Users can request deletion: Yes (delete the account / email the developer)

## Content rating

Strategy / simulation. Mild sci-fi combat against empty NPC worlds. No user-generated public chat in v1.

## Store assets

- App icon: 512 × 512 PNG
- Feature graphic: 1024 × 500 PNG
- Phone screenshots: Planet, Yards, Galaxy, Fleets (at least 4)

## Wrap and internal testing

1. Deploy the Next.js app (Vercel) and confirm magic-link login works.
2. Set `VOIDHOLD_SERVER_URL` to that HTTPS origin.
3. From `Voidhold/`:

   ```bash
   npm install
   npx cap sync android
   npx cap open android
   ```

4. In Android Studio, generate a signed AAB (`targetSdk` 36 for new apps).
5. Play Console → testing → internal testing track → upload the AAB and add testers.

Create a release keystore once and keep it out of git (`*.jks`, `keystore.properties`).

```bash
keytool -genkey -v -keystore voidhold-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias voidhold
```

## Capacitor note

This app loads the hosted site rather than a static export, because auth cookies and server actions need the Next.js origin. A thin wrapper with no working game will be rejected; ship after the universe loop works in the browser.

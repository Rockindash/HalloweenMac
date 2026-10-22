# Dockorate on the Mac App Store

There are two versions of Dockorate, built from the same code:

| | Website version | Mac App Store version |
|---|---|---|
| Xcode scheme | `FallDock` | `DockorateAppStore` |
| Paid for | Gumroad license key | On the App Store (paid upfront) |
| Updates | Sparkle, from the appcast on the website | The App Store |
| App Sandbox | No | Yes (`FallDock/Dockorate-AppStore.entitlements`) |
| Info.plist | `FallDock/Info.plist` | `FallDock/Info-AppStore.plist` (no Sparkle keys) |
| Release | `scripts/release.sh` | `scripts/release-appstore.sh` |

The App Store build is compiled with `APP_STORE` (`AppEnvironment.isAppStore`). It has no license screen, no
"Check for Updates", and doesn't include Sparkle. Both versions carry `FallDock/PrivacyInfo.xcprivacy`.
`scripts/check-appstore-build.sh` checks all of this, and that the sandboxed app starts; it runs on GitHub
with the tests.

## One-time setup

1. In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list),
   make sure the App ID `com.amol.dockorate` exists (Xcode can make it for you on the first upload).
2. In [App Store Connect](https://appstoreconnect.apple.com) → Apps → **+** → New App: platform macOS, name
   Dockorate, bundle ID `com.amol.dockorate`, SKU anything (say `dockorate`).
3. Sign in to your Apple account in Xcode → Settings → Accounts.

## Each release

1. Bump the build number (target → General → Build) if this version was already uploaded.
2. Run `TEAM_ID=ABCDE12345 scripts/release-appstore.sh`. It checks the build, archives it, and uploads it.
3. In App Store Connect, pick the build for the version and submit it for review.

## What to fill in on App Store Connect

- **Price:** Pricing and Availability → pick a price. No in-app purchases.
- **Category:** Entertainment (it's set in the app too). Lifestyle also fits.
- **App Privacy:** "Data Not Collected". Dockorate has no analytics, no accounts and makes no network requests.
- **Age rating:** answer "None" to everything (4+).
- **Screenshots:** at least one, 16:10, such as 2880 × 1800 or 1440 × 900. A Dock with the harvest on it, the app
  window, and the Background page make a good set. `docs/` has some to start from.
- **Support URL** and **Privacy Policy URL:** both required. A short page on your website saying the app
  collects no data is enough for the privacy policy.
- **Description, keywords, promotional text:** your words. Keywords could be: dock, fall, autumn, pumpkin,
  halloween, seasonal, desktop, wallpaper, decoration, cozy.

## Notes for App Review

Paste this into App Review Information → Notes:

> Dockorate decorates the Dock with a seasonal harvest (pumpkins, leaves and more) drawn in a transparent
> window just above it. It lives in the menu bar; click the pumpkin icon and choose "Open Dockorate…" to see
> all its options.
>
> To place the harvest exactly on the Dock it reads the Dock's own settings (its size, magnification and
> position) through a read-only shared-preference exception for com.apple.dock. It never changes them.
> The exception for com.amol.falldock reads the settings of the app's pre-release name once, to carry them over.
>
> Accessibility permission is optional. Without it the harvest still appears and is sized from the Dock's
> settings. With it, Dockorate reads the positions of the Dock's items so the pumpkins fit between them exactly.
> At Halloween it also checks how long the Mac has been idle (never what was typed or clicked), so ghosts
> can gather over the Dock while nobody's there. It doesn't read or control anything else.
>
> The optional Background feature (off by default) sets the desktop picture to one that matches the theme,
> and puts the person's own picture back when it's switched off.

## Before the first submission, check on your Mac

The sandbox changes what an app may do, and GitHub can only check that the App Store build starts. Before
submitting, run the `DockorateAppStore` scheme from Xcode and check:

- The harvest sits on the Dock in the right place, with and without Accessibility allowed.
- Background puts the theme's picture on the desktop, and your own picture comes back when it's switched off.
- Open at Login works.
- Haunting while you're away: with Halloween on, click Try It on the Customize page and let go of the mouse; the ghosts should gather in a few seconds and scatter when you move it. (It reads the system's idle time with `CGEventSource.secondsSinceLastEventType`, which needs no permission.)

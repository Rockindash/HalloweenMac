# Fall Dock 🎃

A cozy little Mac app that fills the top of your Dock with a fall harvest: flat, hand-drawn pumpkins on a
curling vine, evenly spaced, with hay bales, leaf piles, acorns, a crate of apples, a steaming mug of cider
and a glowing lantern in between. A squirrel stops by now and then.

If your Dock magnifies, everything grows, rises and spreads apart with the icons under the pointer.

Click a pumpkin to smash it. Chunks and seeds go flying, and a new pumpkin grows back a few seconds later.
Click a leaf pile to kick it into the air, the mug for a puff of steam, or the lantern to make it flare up.
Sweep the pointer quickly across the pumpkins to rock them, and get close to the squirrel to scare it off.

![On the Dock](docs/dock-closeup.png)

![Art preview](docs/art-preview.png)

![Cozy extras, drawn over stand-in Dock icons](docs/cozy-preview.png)

![Growing with the Dock's magnification](docs/magnify-preview.png)

## What you need

- A Mac running macOS 13 Ventura or newer.
- **Xcode** (free from the Mac App Store).

## Run it from Xcode

1. Double-click **`FallDock.xcodeproj`** to open the project in Xcode.
2. Press **⌘R** (or the ▶︎ Run button at the top left).
3. A 🎃 appears in your menu bar and pumpkins appear on your Dock. Click one!

To stop it, press **⌘.** in Xcode or choose **Quit Fall Dock** from the 🎃 menu.

### Keep a copy in Applications

In Xcode choose **Product → Archive**, then **Distribute App → Custom → Copy App**, and drag the exported **Fall Dock.app** into your Applications folder. Then turn on **Open at Login** in the 🎃 menu.

## The app window

Open **Fall Dock** from your Applications folder (or choose **Open Fall Dock…** from the 🎃 menu) for the app's own window.
While it's open, Fall Dock shows in the Dock and the app switcher like any app; close it and it goes back to living in the menu bar.
When Fall Dock starts by itself at login, the window stays closed.

- **General**: whether the harvest is showing, pause it for an hour, grow new pumpkins, pick the season, and your smash count.
- **Settings**: open at login, show or hide the 🎃 in the menu bar, the smash sound, Reduce Motion, and privacy.
- **Dock**: what Fall Dock sees of your Dock (position, auto-hide, icon size, magnification, its length and whether that's measured or estimated), the Accessibility permission for an exact fit, and how full the harvest is.
- **Fall**: the current season's own tab, with a preview, the vine and falling leaves, and each cozy extra (hay bales, leaf piles, acorns, the mug, the lantern, the apples and the squirrel) switched on or off one by one. As more seasons arrive, this tab follows the one you pick.

## The 🎃 menu

- **Show Pumpkins**: hides or shows everything.
- **Vines**: a single pumpkin vine along the Dock, behind the pumpkins, with fine ridges, two-tone curls and buds.
- **Cozy Extras**: the hay bales, leaf piles, acorns, apples, mug, lantern and the squirrel. The lantern glows brighter in the evening.
- **Falling Leaves**: a leaf drifts down onto the Dock every few seconds.
- **Smash Sound**: a soft, squishy thump when you smash a pumpkin.
- **How Full**: A Few, Plenty or Overflowing, which sets how closely pumpkins and extras are packed. They always stay the same size: when the Dock gets longer or shorter (adding apps, or changing its size in System Settings), pumpkins and extras grow in or shrink away at the end instead of everything stretching.
- **Grow New Pumpkins**: a fresh set of pumpkins.
- **Pause for 1 Hour**: hides everything for an hour, for presentations and screen sharing (or **Resume** early).
- **Fit Pumpkins to Dock Exactly…**: by default the app estimates how wide your Dock is. If the pumpkins hang past the ends of your Dock, allow Fall Dock under System Settings → Privacy & Security → Accessibility and it will measure the Dock exactly. It only reads the Dock's size.
- **Open at Login**: starts Fall Dock when you log in (use the copy in Applications).
- **Welcome to Fall Dock…**: shows the welcome window again. It opens by itself the first time.

## Good to know

- Pumpkins only show when the Dock is at the **bottom** of the screen. They hide and come back with the Dock (for example in full-screen apps), and follow it to another display.
- Clicks only stop at a pumpkin or a cozy extra. Everywhere else, the Dock and your windows work normally.
- With **Reduce Motion** on (System Settings → Accessibility → Display), nothing moves by itself: no wobbling, falling leaves, steam or squirrel. Things still react when you click them.
- Fall Dock checks for the Dock often only while the pointer is near the bottom of the screen, so it uses very little battery while the Dock is hidden.
- Magnification follows the Dock's own setting (System Settings → Desktop & Dock → Magnification).
- All the art is drawn in code (see `FallDock/Art/Art.swift` and `FallDock/Art/CozyArt.swift`), in the flat style of a hand-drawn harvest wagon, using six colors. You can change them in `Palette` near the top of the file.

## How it works

Like Festivitas, Fall Dock doesn't change the Dock itself. It floats a transparent, click-through window just above the Dock, on every desktop.

| File | What it does |
|---|---|
| `App/FallDockApp.swift` | Starts the app (SwiftUI) and puts the 🎃 menu in the menu bar |
| `App/MenuContent.swift` | The 🎃 menu (SwiftUI) |
| `App/AppModel.swift` | What the menu shows and changes |
| `App/Settings.swift` | Remembers your menu choices |
| `App/Welcome.swift` | The welcome window shown on first launch |
| `App/MainWindow.swift` | The app window and its toolbar tabs |
| `App/MainTabs.swift` | The General, Settings, Dock and season tabs |
| `Overlay/DockLocator.swift` | Works out where the Dock is, which display it's on and whether it's showing |
| `Overlay/OverlayController.swift` | Places the transparent window and lets clicks reach a pumpkin only when the pointer is over one |
| `Overlay/PumpkinScene.swift` | Pumpkins, the vine, following the Dock's magnification, wobbling, smashing, regrowing and falling leaves (SpriteKit) |
| `Overlay/PumpkinScene+Cozy.swift` | The cozy extras and the squirrel |
| `Overlay/DockSprite.swift` | The Dock's magnification curve, and the base class for everything that sits on the Dock |
| `Art/Art.swift` | Draws the pumpkins, the vine and the leaves |
| `Art/CozyArt.swift` | Draws the hay bales, leaf piles, acorns, apples, mug, lantern and squirrel |
| `Art/SmashSound.swift` | Makes the smash sound from scratch |

The menu and app are SwiftUI. The overlay above the Dock uses AppKit and SpriteKit, because SwiftUI windows can't float above the Dock or let clicks pass through them.

## The app icon

The icon is drawn by the app's own art code. To redraw it after changing the art, run:

```sh
scripts/make-icon.sh
```

## Releasing

To let other people download Fall Dock, it has to be signed with a Developer ID and notarized by Apple.

One-time setup:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Xcode → Settings → Accounts, select your team, click **Manage Certificates…**, and add a **Developer ID Application** certificate.
3. Save your notarization login in the keychain (use an [app-specific password](https://support.apple.com/102654)):

   ```sh
   xcrun notarytool store-credentials FallDock --apple-id you@example.com --team-id ABCDE12345
   ```

Then, for each release, set the version in Xcode (target → General → Version) and run:

```sh
TEAM_ID=ABCDE12345 scripts/release.sh
```

It builds, signs, notarizes and staples the app, and leaves a zip in `build/release/` to put on your website.

## Not done yet

- Docks on the left or right edge. Auto-hiding Docks aren't tested yet.
- Payments and license keys, automatic updates (Sparkle) and crash reporting.

# Dockorate 🎃

*Decorate your Dock for every season.*

A cozy little Mac app that decorates the top of your Dock for the season. Fall is the first: a harvest of flat, hand-drawn pumpkins on a
curling vine, evenly spaced, with hay bales, leaf piles, acorns, a crate of apples, a steaming pumpkin spice latte
and a glowing lantern in between. A squirrel stops by now and then: it picks up an acorn and carries it
back the way it came (with the acorns switched off, it just hops across).

If your Dock magnifies, everything grows, rises and spreads apart with the icons under the pointer.

Click a pumpkin to smash it. Chunks and seeds go flying, and a new pumpkin grows back a few seconds later.
Click a leaf pile to kick it into the air, the latte for a puff of steam, or the lantern to make it flare up.
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

To stop it, press **⌘.** in Xcode or choose **Quit Dockorate** from the 🎃 menu.

### Keep a copy in Applications

In Xcode choose **Product → Archive**, then **Distribute App → Custom → Copy App**, and drag the exported **Dockorate.app** into your Applications folder. Then turn on **Open at Login** in the 🎃 menu.

## The app window

Open **Dockorate** from your Applications folder (or choose **Open Dockorate…** from the 🎃 menu) for the app's own window.
While it's open, Dockorate shows in the Dock and the app switcher like any app; close it and it goes back to living in the menu bar.
When Dockorate starts by itself at login, the window stays closed.

- **Home**: a live little harvest on a pretend Dock (click its pumpkins to smash them), whether the harvest is on your Dock right now, your smash count, and buttons to pause it for an hour, grow new pumpkins, or show or hide it.
- **Customize**: the vine, falling leaves and cozy extras, with a picture tile for each extra (hay bales, leaf piles, acorns, the latte, the lantern, the apples and the squirrel) to switch it on or off. With falling leaves on:
  - **Amount**: how many leaves fall, from a few to lots. The mark in the middle is the usual amount, and the slider snaps to it.
  - **Fill the whole screen** (off by default): leaves drift down across the whole screen the Dock is on and settle behind the Dock, instead of only just above it.
- **Settings**:
  - **General**: open at login, the 🎃 in the menu bar, and the smash sound.
  - **Dock**: how full the harvest is, and the Accessibility permission for an exact fit.
  - **Reset**: reset the smash count, or reset everything (every option back to how it started, the smash count back to zero, and a fresh harvest; open at login stays as it is). Both ask first.
  - **About**: the version, the welcome window again, and Quit.

## The 🎃 menu

- **Open Dockorate…**: the app window.
- **Show Pumpkins**: hides or shows everything.
- **Vines**: a single pumpkin vine along the Dock, behind the pumpkins, with fine ridges, two-tone curls and buds.
- **Cozy Extras**: the hay bales, leaf piles, acorns, apples, pumpkin spice latte, lantern and the squirrel. The lantern glows brighter in the evening.
- **Falling Leaves**: leaves drift down onto the Dock (how many, and whether they fill the whole screen, is set in Customize).
- **Smash Sound**: a soft, squishy thump when you smash a pumpkin.
- **How Full**: A Few, Plenty or Overflowing, which sets how closely pumpkins and extras are packed. They always stay the same size: when the Dock gets longer or shorter (adding apps, or changing its size in System Settings), pumpkins and extras grow in or shrink away at the end instead of everything stretching.
- **Grow New Pumpkins**: a fresh set of pumpkins.
- **Pause for 1 Hour**: hides everything for an hour, for presentations and screen sharing (or **Resume** early).
- **Fit Pumpkins to Dock Exactly…**: by default the app estimates how wide your Dock is. If the pumpkins hang past the ends of your Dock, allow Dockorate under System Settings → Privacy & Security → Accessibility and it will measure the Dock exactly. It only reads the Dock's size.
- **Open at Login**: starts Dockorate when you log in (use the copy in Applications).
- **Welcome to Dockorate…**: shows the welcome window again. It opens by itself the first time.

If you hide the 🎃 (Settings → General), open Dockorate from Applications to get back to the window.

## Good to know

- Pumpkins only show when the Dock is at the **bottom** of the screen. They hide and come back with the Dock (for example in full-screen apps), and follow it to another display.
- Clicks only stop at a pumpkin or a cozy extra. Everywhere else, the Dock and your windows work normally.
- With **Reduce Motion** on (System Settings → Accessibility → Display), nothing moves by itself: no wobbling, falling leaves, steam or squirrel. Things still react when you click them.
- **Fill the whole screen** uses a second see-through, click-through window over the Dock's screen. It hides with the harvest and stops drawing while hidden, but while it shows it uses a few percent of CPU, so it's off by default.
- Dockorate checks for the Dock often only while the pointer is near the bottom of the screen, so it uses very little battery while the Dock is hidden.
- Magnification follows the Dock's own setting (System Settings → Desktop & Dock → Magnification).
- The harvest follows your Mac's **Light or Dark** setting (System Settings → Appearance): rich, deep colors on a dark Dock, and softer, lighter ones on a light Dock. It switches straight away, keeping the same pumpkins.
- All the art is drawn in code (see `FallDock/Art/Art.swift` and `FallDock/Art/CozyArt.swift`), in the flat style of a hand-drawn harvest wagon, using six colors. You can change them in `Palette` near the top of the file.

## How it works

Like Festivitas, Dockorate doesn't change the Dock itself. It floats a transparent, click-through window just above the Dock, on every desktop.

| File | What it does |
|---|---|
| `App/FallDockApp.swift` | Starts the app (SwiftUI) and puts the 🎃 menu in the menu bar |
| `App/MenuContent.swift` | The 🎃 menu (SwiftUI) |
| `App/AppModel.swift` | What the menu shows and changes |
| `App/Settings.swift` | Remembers your choices, and resets them |
| `App/Welcome.swift` | The welcome window shown on first launch |
| `App/MainWindow.swift` | The app window |
| `App/MainView.swift` | The window's sidebar, and the Home and Settings pages |
| `App/MainTabs.swift` | The Customize page, the cards and rows the pages are built from, and the live little harvest |
| `Overlay/DockLocator.swift` | Works out where the Dock is, which display it's on and whether it's showing |
| `Overlay/OverlayController.swift` | Places the transparent window and lets clicks reach a pumpkin only when the pointer is over one |
| `Overlay/PumpkinScene.swift` | Pumpkins, the vine, following the Dock's magnification, wobbling, smashing, regrowing and falling leaves (SpriteKit) |
| `Overlay/PumpkinScene+Cozy.swift` | The cozy extras and the squirrel |
| `Overlay/ScreenLeafScene.swift` | Leaves falling across the whole screen, for Fill the whole screen |
| `Overlay/DockSprite.swift` | The Dock's magnification curve, and the base class for everything that sits on the Dock |
| `Art/Art.swift` | Draws the pumpkins, the vine and the leaves |
| `Art/CozyArt.swift` | Draws the hay bales, leaf piles, acorns, apples, pumpkin spice latte, lantern and squirrel |
| `Art/SmashSound.swift` | Makes the smash sound from scratch |

The menu and app are SwiftUI. The overlay above the Dock uses AppKit and SpriteKit, because SwiftUI windows can't float above the Dock or let clicks pass through them.

## The app icon

The icon is `FallDock/Icon.icon`, an Icon Composer file. Open it in Icon Composer (Xcode > Open Developer Tool) to edit it. Xcode builds every icon size from it, including the older-style icon for macOS 13 to 15.

## Releasing

To let other people download Dockorate, it has to be signed with a Developer ID and notarized by Apple.

One-time setup:

1. Join the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Xcode → Settings → Accounts, select your team, click **Manage Certificates…**, and add a **Developer ID Application** certificate.
3. Save your notarization login in the keychain (use an [app-specific password](https://support.apple.com/102654)):

   ```sh
   xcrun notarytool store-credentials Dockorate --apple-id you@example.com --team-id ABCDE12345
   ```

Then, for each release, set the version in Xcode (target → General → Version) and run:

```sh
TEAM_ID=ABCDE12345 scripts/release.sh
```

It builds, signs, notarizes and staples the app, and leaves a zip and a disk image in `build/release/` to put on
your website. The disk image opens a fall-themed window that asks people to drag Dockorate into Applications;
`scripts/make-dmg.sh` makes it (it can also wrap any build, signed or not), and `scripts/dmg/background.swift`
draws its background. The first time, macOS may ask to let Terminal control Finder, which lays out the window.

## The project's name

Dockorate was called Fall Dock while it was being built, so the Xcode project, scheme, target and source
folder are still named `FallDock`. Only the app people see is called Dockorate. The first time Dockorate
starts, it brings over the choices and smash count saved by Fall Dock (bundle ID `com.amol.falldock`).

## Not done yet

- Docks on the left or right edge. Auto-hiding Docks aren't tested yet.
- Payments and license keys, automatic updates (Sparkle) and crash reporting.

# Fall Dock 🎃

A cozy little Mac app that puts a harvest of speckled pumpkins, leafy vines, leaves and acorns on top of your Dock.
Click a pumpkin to smash it. Chunks and seeds go flying, and a new pumpkin grows back a few seconds later.

![On the Dock](docs/dock-closeup.png)

![Art preview](docs/art-preview.png)

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

## The 🎃 menu

- **Show Pumpkins**: hides or shows everything.
- **Vines**: a leafy pumpkin vine with blossoms along the Dock.
- **Falling Leaves**: a leaf drifts down onto the Dock every few seconds.
- **Smash Sound**: a soft, squishy thump when you smash a pumpkin.
- **Number of Pumpkins**: A Few (5), Plenty (9) or Overflowing (13).
- **Grow New Pumpkins**: a fresh set of pumpkins.
- **Fit Pumpkins to Dock Exactly…**: by default the app estimates how wide your Dock is. If the pumpkins hang past the ends of your Dock, allow Fall Dock under System Settings → Privacy & Security → Accessibility and it will measure the Dock exactly. It only reads the Dock's size.
- **Open at Login**: starts Fall Dock when you log in (use the copy in Applications).

## Good to know

- Pumpkins only show when the Dock is at the **bottom** of the screen. They hide and come back with the Dock (for example in full-screen apps), and follow it to another display.
- Clicks only stop at a pumpkin. Everywhere else, the Dock and your windows work normally.
- All the art is drawn in code (see `FallDock/Art/Art.swift`), so you can change colors there. The colors are near the top of the file.

## How it works

Like Festivitas, Fall Dock doesn't change the Dock itself. It floats a transparent, click-through window just above the Dock, on every desktop.

| File | What it does |
|---|---|
| `App/FallDockApp.swift` | Starts the app (SwiftUI) and puts the 🎃 menu in the menu bar |
| `App/MenuContent.swift` | The 🎃 menu (SwiftUI) |
| `App/AppModel.swift` | What the menu shows and changes |
| `App/Settings.swift` | Remembers your menu choices |
| `Overlay/DockLocator.swift` | Works out where the Dock is, which display it's on and whether it's showing |
| `Overlay/OverlayController.swift` | Places the transparent window and lets clicks reach a pumpkin only when the pointer is over one |
| `Overlay/PumpkinScene.swift` | Pumpkins, vines, wobbling, smashing, regrowing and falling leaves (SpriteKit) |
| `Art/Art.swift` | Draws the speckled pumpkins, vines, leaves, acorns and berries |
| `Art/SmashSound.swift` | Makes the smash sound from scratch |

The menu and app are SwiftUI. The overlay above the Dock uses AppKit and SpriteKit, because SwiftUI windows can't float above the Dock or let clicks pass through them.

## Not done yet

- Docks on the left or right edge. Auto-hiding Docks aren't tested yet.
- A proper app icon.
- Signing with an Apple Developer account so other people can download it.

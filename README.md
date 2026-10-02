# Fall Dock 🎃

A cozy little Mac app that puts a harvest of speckled pumpkins, leafy vines, leaves and acorns on top of your Dock.
Click a pumpkin to smash it. Chunks and seeds go flying, and a new pumpkin grows back a few seconds later.

![On the Dock](docs/dock-closeup.png)

![Art preview](docs/art-preview.png)

## What you need

- A Mac running macOS 13 Ventura or newer.
- Apple's free developer tools. You don't need the full Xcode app.

## Build and run it (about 5 minutes the first time)

1. **Install Apple's developer tools.** Open the **Terminal** app (press ⌘ Space and type "Terminal"), then paste this and press Return:

   ```
   xcode-select --install
   ```

   Click **Install** in the window that pops up. If it says the tools are already installed, you're all set.

2. **Put the `FallDock` folder somewhere easy**, for example your Desktop.

3. **Build the app.** In Terminal, run:

   ```
   cd ~/Desktop/FallDock
   bash scripts/make-app.sh
   ```

   If you saved the folder somewhere else, change the path in the first line. The first build takes a minute or two.

4. **Open it:**

   ```
   open "build/Fall Dock.app"
   ```

   You'll see a 🎃 in your menu bar and pumpkins sitting on your Dock. Click one!

5. To keep the app, drag `build/Fall Dock.app` into your **Applications** folder. Then turn on **Open at Login** in the 🎃 menu.

### Quick try without making an app

To run it straight from Terminal, use `swift run` inside the `FallDock` folder. Press Ctrl+C to stop it.

## The 🎃 menu

- **Show Pumpkins**: hides or shows everything.
- **Vines**: a leafy pumpkin vine with blossoms along the Dock.
- **Falling Leaves**: a leaf drifts down onto the Dock every few seconds.
- **Smash Sound**: a soft, squishy thump when you smash a pumpkin.
- **Number of Pumpkins**: A Few (5), Plenty (9) or Overflowing (13).
- **Grow New Pumpkins**: a fresh set of pumpkins.
- **Fit Pumpkins to Dock Exactly…**: by default the app estimates how wide your Dock is. If the pumpkins hang past the ends of your Dock, allow Fall Dock under System Settings → Privacy & Security → Accessibility and it will measure the Dock exactly. It only reads the Dock's size.
- **Open at Login**: only shows when you run the built `.app`.

## Good to know

- Pumpkins only show when the Dock is at the **bottom** of the screen and **not set to auto-hide**. They hide when an app goes full screen.
- Clicks only stop at a pumpkin. Everywhere else, the Dock and your windows work normally.
- All the art is drawn in code (see `Sources/FallDock/Art.swift`), so you can change colors there. The colors are near the top of the file.

## How it works

Like Festivitas, Fall Dock doesn't change the Dock itself. It floats a transparent, click-through window just above the Dock, on every desktop.

| File | What it does |
|---|---|
| `FallDockApp.swift` | Starts the app and builds the 🎃 menu bar menu |
| `DockLocator.swift` | Works out where the Dock is and how big it is |
| `OverlayController.swift` | Places the transparent window and lets clicks reach a pumpkin only when the pointer is over one |
| `PumpkinScene.swift` | Pumpkins, wobbling, smashing, regrowing and falling leaves (SpriteKit) |
| `Art.swift` | Draws the speckled pumpkins, leaves, acorns and berries |
| `SmashSound.swift` | Makes the smash sound from scratch |
| `Settings.swift` | Remembers your menu choices |

## Not done yet

- Docks on the left or right edge, and auto-hiding Docks.
- A proper app icon.
- Signing with an Apple Developer account so other people can download it.

# Dockorate website

The landing page for Dockorate, the Mac app that decorates your Dock for every season. Built with React and Vite.

## Run it on your Mac

You need Node.js 18 or newer (`brew install node`, or the installer from nodejs.org).

```
npm install
npm run dev      # live preview at http://localhost:5173
npm run build    # static site in dist/
```

## Where things are

- `src/App.jsx`: page sections, the Buy Now link (`BUY_URL`) and support email (`SUPPORT`)
- `src/harvest.js`: the app's own artwork, ported from the Mac app's Art.swift and CozyArt.swift
- `src/Harvest.jsx`: lays the harvest out on the Dock with the app's rules
- `src/dockicons.jsx`: the stand-in Dock icons
- `src/styles.css`: colours, type, light and dark mode

## Hosting

Every push to `main` builds the site and publishes it with GitHub Pages
(`.github/workflows/deploy.yml`). It goes live at https://rockindash.github.io/DockorateWebsite/.
To use your own domain (for example dockorate.com), add it under Settings → Pages → Custom domain.

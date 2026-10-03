#!/bin/sh
# Redraws the app icon from the app's own art code. Run from anywhere: scripts/make-icon.sh
set -e
cd "$(dirname "$0")/.."
BUILD=$(mktemp -d)
swiftc -O -o "$BUILD/make-icon" scripts/make-icon/main.swift FallDock/Art/Art.swift
"$BUILD/make-icon" FallDock/Assets.xcassets/AppIcon.appiconset
rm -rf "$BUILD"

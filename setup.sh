#!/bin/bash
# Run this once to create the Xcode project.
# Requires: brew install xcodegen

set -e
echo "→ Installing XcodeGen..."
brew install xcodegen

echo "→ Generating Xcode project..."
xcodegen generate

echo "→ Opening Xcode..."
open Poser.xcodeproj

#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/CMM Clone.app"
SRC="$ROOT/Sources/CMMClone"
RES="$ROOT/Resources"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Copy Info.plist
cp "$RES/Info.plist" "$APP/Contents/Info.plist"

# Copy icon
cp "$RES/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# PkgInfo
printf "APPL????" > "$APP/Contents/PkgInfo"

# Compile Swift sources
swiftc \
    -O \
    -target arm64-apple-macosx14.0 \
    -parse-as-library \
    -module-name CMMClone \
    -o "$APP/Contents/MacOS/CMMClone" \
    "$SRC"/*.swift

# Codesign (ad-hoc) so it runs without Gatekeeper complaining
codesign --force --deep --sign - "$APP"

echo "Built: $APP"

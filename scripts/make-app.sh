#!/bin/bash
# Assembles build/Orelhao.app from the SwiftPM binary.
# Ad-hoc signing: enough to run locally with the microphone (TCC) prompt.
# Notarization/hardened runtime are deferred to F5.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Orelhao.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/OrelhaoApp "$APP/Contents/MacOS/Orelhao"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Orelhao</string>
    <key>CFBundleIdentifier</key>
    <string>dev.vplentz.orelhao</string>
    <key>CFBundleName</key>
    <string>Orelhão</string>
    <key>CFBundleDisplayName</key>
    <string>Orelhão</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Orelhão uses the microphone for SIP voice calls.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST

cp "$ROOT/assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Bundle Homebrew dylibs (opus/openssl) → self-contained app, runs on a clean Mac
FRAMEWORKS="$APP/Contents/Frameworks"
mkdir -p "$FRAMEWORKS"
BUNDLED_LIBS=(
  "/opt/homebrew/opt/opus/lib/libopus.0.dylib"
  "/opt/homebrew/opt/openssl@3/lib/libssl.3.dylib"
  "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib"
)
for lib in "${BUNDLED_LIBS[@]}"; do
  cp "$lib" "$FRAMEWORKS/"
  chmod u+w "$FRAMEWORKS/$(basename "$lib")"
done

rewrite_deps() {
  local target="$1"
  otool -L "$target" | awk '/\/opt\/homebrew\//{print $1}' | while read -r dep; do
    install_name_tool -change "$dep" \
      "@executable_path/../Frameworks/$(basename "$dep")" "$target" 2>/dev/null
  done
}
rewrite_deps "$APP/Contents/MacOS/Orelhao"
for dylib in "$FRAMEWORKS"/*.dylib; do
  install_name_tool -id "@executable_path/../Frameworks/$(basename "$dylib")" "$dylib" 2>/dev/null
  rewrite_deps "$dylib"
done

codesign --force --sign - "$FRAMEWORKS"/*.dylib
codesign --force --sign - "$APP"

# Installable DMG (the project's "setup.exe")
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
mkdir -p "$ROOT/dist"
hdiutil create -volname "Orelhão" -srcfolder "$APP" -ov -quiet \
  -format UDZO "$ROOT/dist/Orelhao-$VERSION.dmg"

echo "[make-app] OK → $APP"
echo "[make-app] DMG → dist/Orelhao-$VERSION.dmg"

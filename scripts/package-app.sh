#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="$ROOT/dist/Hyper.app"
ICONSET="$ROOT/dist/Hyper.iconset"
APP_VERSION=${APP_VERSION:-$(cat "$ROOT/VERSION")}
LAUNCH_AGENT_LABEL=${HYPER_LAUNCH_AGENT_LABEL:-com.hypercode.server}

cd "$ROOT"
swift build -c release
rm -rf "$APP"
rm -rf "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$ROOT/.build/release/HyperDesktop" "$APP/Contents/MacOS/HyperDesktop"
sips -z 16 16 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>HyperDesktop</string>
  <key>CFBundleIdentifier</key><string>ru.pismenny.hyper.desktop</string>
  <key>CFBundleName</key><string>Hyper</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$APP_VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon.icns</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>HyperLaunchAgentLabel</key><string>$LAUNCH_AGENT_LABEL</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"

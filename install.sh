#!/bin/zsh
# DNK_Piu Installer: Builds the app, sets up local bundle and hooks.
set -euo pipefail

ROOT="${0:A:h}"
APP="$HOME/Applications/DNK_Piu.app"
BIN="$HOME/.dnk_runtime/piu/bin"

echo "💎 Building DNK_Piu in Release mode..."
swift build -c release --package-path "$ROOT"

BUILT="$(swift build -c release --package-path "$ROOT" --show-bin-path)/DNKPiu"
[[ -x "$BUILT" ]] || { echo "❌ Build failed."; exit 1; }

echo "📦 Installing to $APP..."
pkill -x DNKPiu 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BUILT" "$APP/Contents/MacOS/DNKPiu"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>DNK_Piu</string>
  <key>CFBundleDisplayName</key><string>DNK_Piu</string>
  <key>CFBundleIdentifier</key><string>com.dnk.piu</string>
  <key>CFBundleExecutable</key><string>DNKPiu</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key><string>DNK_Piu uses the microphone for Google Cloud Gemini 3.8 Flash voice dictation.</string>
  <key>NSAppleEventsUsageDescription</key><string>DNK_Piu activates terminal tabs and sessions when you click the jump button.</string>
</dict>
</plist>
PLIST

echo "🔐 Applying Ad-hoc code signature with bundle id and stable designated requirement..."
codesign --force --deep -s - -i com.dnk.piu -r='designated => identifier "com.dnk.piu"' "$APP"

echo "🔗 Setting up runtime hooks in $BIN..."
mkdir -p "$BIN" "$HOME/.dnk_runtime/piu/pending" "$HOME/.dnk_runtime/piu/responses" "$HOME/.dnk_runtime/piu/sessions"
cp "$ROOT/hooks/piu_hook.py" "$BIN/piu_hook.py"
chmod +x "$BIN/piu_hook.py"

echo "✅ DNK_Piu v1.0.0 successfully installed to $APP"
echo "👉 Launch with: open -a '$APP'"

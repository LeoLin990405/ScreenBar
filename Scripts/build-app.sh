#!/bin/bash
# 构建 ScreenBar.app 并安装 + 重载 LaunchAgent(开机自启 + 崩溃自拉起)。
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ScreenBar"
BUNDLE_ID="com.leo.screenbar"
VERSION="5.0.0"
DEST="$HOME/Applications/$APP_NAME.app"
UID_=$(id -u)

echo "==> swift build -c release"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "==> 组装 bundle: $DEST"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources"
cp "$BIN" "$DEST/Contents/MacOS/$APP_NAME"
cat > "$DEST/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST

echo "==> 签名(ad-hoc)"
codesign --force --deep -s - "$DEST"

echo "==> 安装 CLI 软链 ~/bin/screenbar"
mkdir -p "$HOME/bin"
ln -sf "$DEST/Contents/MacOS/$APP_NAME" "$HOME/bin/screenbar"

echo "==> 安装 LaunchAgent + 重启"
PLIST="$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"
cat > "$PLIST" <<LA
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$BUNDLE_ID</string>
  <key>ProgramArguments</key><array><string>$DEST/Contents/MacOS/$APP_NAME</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict></plist>
LA
# 彻底卸载(label + path 两种,清陈旧注册避免 bootstrap I/O error),再加载
launchctl bootout "gui/$UID_/$BUNDLE_ID" 2>/dev/null || true
launchctl bootout "gui/$UID_" "$PLIST" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 2
launchctl bootstrap "gui/$UID_" "$PLIST"
launchctl kickstart -k "gui/$UID_/$BUNDLE_ID"
sleep 2
echo "==> 运行实例: $(pgrep -x $APP_NAME | wc -l | tr -d ' ')  PID=$(pgrep -x $APP_NAME)"
echo "==> 完成 v$VERSION → $DEST"

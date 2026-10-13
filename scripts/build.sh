#!/bin/sh
# Builds Sofaonmac.app into ./build.
# Usage: scripts/build.sh [--run] [--install]   (--install copies the app to /Applications and starts it)
set -e
cd "$(dirname "$0")/.."

[ -f Resources/AppIcon.icns ] || scripts/make-icon.sh

swift build -c release
APP=build/Sofaonmac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --show-bin-path)/Sofaonmac" "$APP/Contents/MacOS/Sofaonmac"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/sofa-*.png "$APP/Contents/Resources/"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

case "$1 $2" in
    *--install*)
        pkill -x Sofaonmac 2>/dev/null && sleep 1 || true
        rm -rf /Applications/Sofaonmac.app
        cp -R "$APP" /Applications/
        rm -rf "$APP"   # only the installed copy should exist
        open /Applications/Sofaonmac.app
        echo "Installed /Applications/Sofaonmac.app" ;;
    *--run*)
        pkill -x Sofaonmac 2>/dev/null && sleep 1 || true
        open "$APP" ;;
esac

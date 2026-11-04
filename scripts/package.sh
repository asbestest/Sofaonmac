#!/bin/sh
# Builds the app and packs it with the instructions into dist/Sofaonmac.zip, ready to send to friends.
set -e
cd "$(dirname "$0")/.."
scripts/build.sh
rm -rf dist
mkdir -p dist/Sofaonmac
cp -R build/Sofaonmac.app dist/Sofaonmac/
cp Resources/Install.txt Resources/Anleitung.txt dist/Sofaonmac/
xattr -cr dist/Sofaonmac
# --norsrc keeps the ._ files of extended attributes out of the zip
ditto -c -k --norsrc --keepParent dist/Sofaonmac dist/Sofaonmac.zip
rm -rf dist/Sofaonmac
echo "Wrote dist/Sofaonmac.zip ($(du -h dist/Sofaonmac.zip | cut -f1))"

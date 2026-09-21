#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
STAGE="$ROOT/dist"
APP="$STAGE/Browser Traffic Control.app"
rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS"
swift build -c release --package-path "$ROOT"
cp "$ROOT/.build/arm64-apple-macosx/release/Browser Traffic Control" "$APP/Contents/MacOS/Browser Traffic Control"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$APP/Contents/Info.plist"
xattr -cr "$APP" 2>/dev/null || true
# Swift's linker signature does not seal the completed app bundle. Re-sign the
# finished bundle so its Info.plist and resources are covered by one valid
# local-installation signature. Release CI replaces this ad-hoc signature with
# the configured Developer ID identity before notarization.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
(cd "$STAGE" && COPYFILE_DISABLE=1 zip -qry -X "Browser-Traffic-Control-$VERSION.zip" "Browser Traffic Control.app")
shasum -a 256 "$STAGE/Browser-Traffic-Control-$VERSION.zip" > "$STAGE/Browser-Traffic-Control-$VERSION.zip.sha256"

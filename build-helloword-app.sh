#!/usr/bin/env bash
# Rebuilds HelloWord.app as an AppleScript applet that handles Finder "Open With".
# Re-applies the icon, identifier, and document-type registration on top of osacompile's output.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/HelloWord.app"
PB=/usr/libexec/PlistBuddy

# Preserve the existing icon (canonical source: repo root, else the current bundle).
ICON="$ROOT/helloword.icns"
[ -f "$ICON" ] || ICON="$APP/Contents/Resources/helloword.icns"
TMPICON="$(mktemp /tmp/hwicon.XXXXXX).icns"
cp "$ICON" "$TMPICON"

BUILD="$(mktemp -d /tmp/hwapp.XXXXXX)/HelloWord.app"
osacompile -o "$BUILD" "$ROOT/helloword.applescript"

# Icon
cp "$TMPICON" "$BUILD/Contents/Resources/helloword.icns"
PLIST="$BUILD/Contents/Info.plist"
$PB -c "Set :CFBundleName helloword" "$PLIST"
$PB -c "Add :CFBundleDisplayName string helloword" "$PLIST" 2>/dev/null || $PB -c "Set :CFBundleDisplayName helloword" "$PLIST"
$PB -c "Add :CFBundleIdentifier string com.helloword.app" "$PLIST" 2>/dev/null || $PB -c "Set :CFBundleIdentifier com.helloword.app" "$PLIST"
$PB -c "Add :CFBundleIconFile string helloword" "$PLIST" 2>/dev/null || $PB -c "Set :CFBundleIconFile helloword" "$PLIST"
$PB -c "Add :NSHighResolutionCapable bool true" "$PLIST" 2>/dev/null || true
$PB -c "Add :LSMinimumSystemVersion string 10.13" "$PLIST" 2>/dev/null || true

# Document types: .md / .markdown / .txt, role Editor, Alternate rank (appears in "Open With").
$PB -c "Add :CFBundleDocumentTypes array" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 'Text / Markdown Document'" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions array" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:0 string md" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:1 string markdown" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeExtensions:2 string txt" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string net.daringfireball.markdown" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.plain-text" "$PLIST"

plutil -lint "$PLIST"

# Swap into place
rm -rf "$APP"
mv "$BUILD" "$APP"

# Re-sign (ad-hoc). osacompile signs the droplet, but our PlistBuddy edits change
# Info.plist afterward, which invalidates that signature — macOS then refuses to launch
# the app ("invalid Info.plist (plist or signature have been modified)"). Re-signing
# reseals the modified Info.plist so the bundle launches.
codesign --force --sign - "$APP"

# Register with LaunchServices so Finder shows it in "Open With".
LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
[ -x "$LSREG" ] && "$LSREG" -f "$APP"

echo "Built $APP"

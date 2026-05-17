#!/bin/bash
# wrap_apk.sh
# Fully automates wrapping ANY .apk file into a native macOS .app

APK_PATH=$1

if [ -z "$APK_PATH" ]; then
    echo "Usage: ./wrap_apk.sh <path_to_apk>"
    echo "Example: ./wrap_apk.sh ~/Downloads/twitter.apk"
    exit 1
fi

AAPT="/usr/local/share/android-commandlinetools/build-tools/34.0.0/aapt"
ADB="/usr/local/share/android-commandlinetools/platform-tools/adb"
EMULATOR="/usr/local/share/android-commandlinetools/emulator/emulator"

if [ ! -f "$AAPT" ]; then
    echo "Error: Android build-tools (aapt) not found. Run sdkmanager 'build-tools;34.0.0'"
    exit 1
fi

echo "======================================"
echo "📦 Arca Wrapper - Analyzing APK..."
echo "======================================"

APP_NAME=$($AAPT dump badging "$APK_PATH" | grep "application-label:" | head -n 1 | cut -d"'" -f2)
PACKAGE_NAME=$($AAPT dump badging "$APK_PATH" | grep "package: name=" | cut -d"'" -f2)
ICON_RES_PATH=$($AAPT dump badging "$APK_PATH" | grep "application-icon-" | tail -n 1 | cut -d"'" -f2)

if [ -z "$APP_NAME" ]; then APP_NAME="Arca App"; fi
if [ -z "$PACKAGE_NAME" ]; then echo "Error: Could not extract package name."; exit 1; fi

echo "App Name: $APP_NAME"
echo "Package:  $PACKAGE_NAME"

echo "======================================"
echo "🚀 Step 1: Booting Emulator & Installing..."
echo "======================================"
$ADB kill-server
$EMULATOR -avd applet_test -accel auto -gpu host -no-window -no-audio -memory 512 &
EMU_PID=$!

echo "Waiting for Android OS to fully boot (this can take 30-60 seconds)..."
$ADB wait-for-device
while [ "$($ADB shell getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
    sleep 2
done
sleep 5 # Give PackageManager an extra moment to settle

echo "Installing $APP_NAME..."
$ADB install "$APK_PATH"

echo "======================================"
echo "📸 Step 2: Creating Golden Snapshot..."
echo "======================================"
echo "Launching app..."
$ADB shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 4 # Let it load

echo "Saving frozen state..."
$ADB emu avd snapshot save ready
sleep 2

echo "Shutting down emulator..."
$ADB emu kill
wait $EMU_PID 2>/dev/null

echo "======================================"
echo "🍏 Step 3: Generating macOS .app..."
echo "======================================"
RUNNER_APP=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/*/AppletRunner.app" -type d | grep -v "Index.noindex" | head -n 1)

if [ -z "$RUNNER_APP" ]; then
    echo "Error: Xcode template not built. Open AppletRunner in Xcode and hit Cmd+B."
    exit 1
fi

OUTPUT_DIR="$HOME/Desktop/${APP_NAME}.app"
rm -rf "$OUTPUT_DIR"
cp -r "$RUNNER_APP" "$OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR/Contents/Resources"
echo -e "$APP_NAME\n$PACKAGE_NAME" > "$OUTPUT_DIR/Contents/Resources/arca_config.txt"

if [ -n "$ICON_RES_PATH" ]; then
echo "Extracting native icon from APK..."
    ICON_PATH="/tmp/arca_icon.png"
    unzip -p "$APK_PATH" "$ICON_RES_PATH" > "$ICON_PATH"
    
    if [ -s "$ICON_PATH" ]; then
        ICONSET_DIR="/tmp/arca_icon.iconset"
        rm -rf "$ICONSET_DIR"
        mkdir -p "$ICONSET_DIR"
        
        sips -z 256 256 "$ICON_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
        iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null
        plutil -replace CFBundleIconFile -string "AppIcon" "$OUTPUT_DIR/Contents/Info.plist"
        rm -rf "$ICONSET_DIR" "$ICON_PATH"
    fi
fi

# Update Info.plist so the macOS Menu Bar shows the actual App Name instead of AppletRunner
plutil -replace CFBundleName -string "$APP_NAME" "$OUTPUT_DIR/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "$APP_NAME" "$OUTPUT_DIR/Contents/Info.plist"

codesign --force --deep -s - "$OUTPUT_DIR" >/dev/null 2>&1

echo "======================================"
echo "✅ SUCCESS! Wrapper created at:"
echo "👉 $OUTPUT_DIR"
echo "======================================"

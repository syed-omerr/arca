#!/bin/bash
# 04_create_dmg.sh
# Packages a macOS .app bundle into a distributable .dmg installer

APP_PATH=$1

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Usage: ./04_create_dmg.sh <path_to_app>"
    echo "Example: ./04_create_dmg.sh ~/Desktop/\"My Calculator.app\""
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
STAGING_DIR="/tmp/${APP_NAME}_dmg_staging"

echo "1. Preparing DMG staging area..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "2. Copying app to staging area..."
cp -r "$APP_PATH" "$STAGING_DIR/"

echo "3. Creating Applications folder shortcut..."
# This creates the standard drag-and-drop installer experience
ln -s /Applications "$STAGING_DIR/Applications"

OUTPUT_DMG="$HOME/Desktop/${APP_NAME}.dmg"

echo "4. Generating compressed DMG image..."
rm -f "$OUTPUT_DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$OUTPUT_DMG" >/dev/null

# Clean up staging area
rm -rf "$STAGING_DIR"

echo "=================================================="
echo "Done! Your distributable DMG is ready at:"
echo "$OUTPUT_DMG"
echo ""
echo "You can upload this file to GitHub Releases!"

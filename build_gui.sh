#!/bin/bash
echo "Building Arca SwiftUI GUI..."

APP_DIR="Arca.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "Compiling Swift code..."
swiftc -parse-as-library ArcaBundleCreator.swift -o "$APP_DIR/Contents/MacOS/Arca"

echo "Generating Info.plist..."
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Arca</string>
    <key>CFBundleIdentifier</key>
    <string>com.arca.bundlecreator</string>
    <key>CFBundleName</key>
    <string>Arca</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Arca needs access to your Desktop to save the finished Mac apps.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Arca needs access to your Downloads folder to read APKs and run the wrapper script.</string>
</dict>
</plist>
EOF

echo "Embedding wrapper script into App bundle..."
cp wrap_apk.sh "$APP_DIR/Contents/Resources/wrap_apk.sh"

echo "Signing application..."
codesign --force --deep -s - "$APP_DIR"

echo "✅ Arca GUI built successfully at: $(pwd)/$APP_DIR"

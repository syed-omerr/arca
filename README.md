# Arca 📦

Arca is a high-performance native macOS engine that instantly wraps any Android APK into a standalone, fully-interactive macOS `.app` bundle.

By combining headless Android emulation with a lightning-fast native SwiftUI window shell and golden snapshots, Arca achieves near-instant boot times (~2 seconds) and full 60fps interactivity.

## ✨ Features
- **Universal Wrapper**: Feed it any `.apk`, and it will automatically extract the App Name, Package Name, and Icon.
- **Golden Snapshots**: Bypasses the Android boot sequence entirely. Apps open instantly.
- **Native macOS Shell**: SwiftUI Obsidian-styled shell translates Mac mouse clicks and drag-swipes perfectly into Android touch inputs.
- **Auto-DMG Packaging**: Fully integrated GitHub actions pipeline to package your engine into a distributable installer.

## 🚀 First-Time Setup
If you are running this for the first time on a fresh Mac:
1. Open terminal and run: `./setup.sh`
2. Wait while it automatically installs Homebrew, the Android Command Line Tools, and generates your virtual device.
3. Run `./01_apply_avd_config.sh` to optimize the emulator for high-performance headless execution.

## 📦 How to Wrap an APK
To convert any Android app into a Mac app, you no longer need the command line!
1. Open **arca** (`Arca.app`) from your Desktop.
2. Drag and drop any `.apk` file into the dashed box.
3. The engine will instantly boot the emulator, install the app, extract the native Android icons/names, take a golden snapshot, and spit out a fully native Mac `.app` on your Desktop!

## 🌐 Distribution (DMG)
To package the wrapper tool for public distribution:
```bash
./04_create_dmg.sh
```
Or simply tag your git repository with `v1.x` and the GitHub Actions pipeline will automatically compile and publish the DMG to the Releases page!

## ⚠️ Important Note on Gatekeeper
Because the generated apps are signed ad-hoc, macOS Gatekeeper may show a "damaged" warning when you first open an app downloaded from the internet. 
**To open the app for the first time:**
1. **Right-click** (or Control-click) the `.app`.
2. Click **Open**.
3. Confirm the dialog. 
*(You only have to do this once per app!)*

## Architecture
- **Language**: Swift 6, Bash
- **UI Framework**: SwiftUI
- **Emulation**: Google Android Emulator (Headless Gfxstream)
- **Input Bridge**: Persistent ADB Shell Pipe (`input tap`)
- **Display Streaming**: `adb exec-out screencap` buffered to `NSImage`

## 🛠 Troubleshooting & Known Issues
- **Google Play Services:** Arca currently uses the AOSP (Android Open Source Project) emulator image for maximum speed and minimum bloat. APKs that strictly require Google Play Services to function may crash or fail to load.
- **"Operation Not Permitted":** If the wrapper script fails to read your APK, ensure the `Arca.app` has been granted access to your Downloads folder or Desktop in your Mac's Privacy & Security settings.
- **Performance:** For heavily graphic-intensive games, the `screencap` buffer may introduce minor visual tearing. 

## 🤝 Contributing & License
Arca is open-source under the **MIT License**. We welcome contributions! If you're a developer:
1. Fork the repository.
2. Build the `Arca.app` shell locally using `./build_gui.sh`.
3. Submit a Pull Request with architectural improvements (such as integrating `gRPC` for streaming or sandboxing the emulator further).

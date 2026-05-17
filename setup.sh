#!/bin/bash
# setup.sh
# Arca First-Time Setup Script
# Installs Android Command Line Tools, SDK, and configures the AVD.

echo "=========================================================="
echo "🍏 Arca First-Time Setup"
echo "This will download the necessary Android components (~2GB)."
echo "=========================================================="

if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ ! -d "/usr/local/share/android-commandlinetools" ] && [ ! -d "/opt/homebrew/share/android-commandlinetools" ]; then
    echo "📦 Installing Android Command Line Tools..."
    brew install --cask android-commandlinetools
fi

# Detect architecture for brew path
if [ "$(uname -m)" = "arm64" ]; then
    SDKMANAGER="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
    AVDMANAGER="/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/avdmanager"
else
    SDKMANAGER="/usr/local/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager"
    AVDMANAGER="/usr/local/share/android-commandlinetools/cmdline-tools/latest/bin/avdmanager"
fi

echo "📥 Downloading Android 34 System Image (this may take a few minutes)..."
yes | "$SDKMANAGER" "system-images;android-34;default;x86_64" > /dev/null
yes | "$SDKMANAGER" "platform-tools" "emulator" > /dev/null

echo "📱 Creating 'applet_test' Virtual Device..."
yes | "$AVDMANAGER" create avd -n applet_test -k "system-images;android-34;default;x86_64" --device "pixel" --force > /dev/null

echo "=========================================================="
echo "✅ Setup Complete! You can now use Arca to wrap and run APKs."
echo "=========================================================="

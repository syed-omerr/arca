#!/bin/bash
# 01_apply_avd_config.sh
# Applies performance-critical settings to the AVD config.ini for the arca project.

AVD_NAME="applet_test"
CONFIG_PATH="$HOME/.android/avd/${AVD_NAME}.avd/config.ini"

if [ ! -f "$CONFIG_PATH" ]; then
    echo "Error: $CONFIG_PATH not found. Have you created the AVD yet?"
    echo "If not, run the commands from your lala.txt first."
    exit 1
fi

echo "Backing up original config..."
cp "$CONFIG_PATH" "${CONFIG_PATH}.backup"

echo "Applying arca performance settings..."

# Function to set or replace a key-value pair in config.ini
set_config() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" "$CONFIG_PATH"; then
        # Replace existing
        sed -i '' "s|^${key}=.*|${key}=${value}|" "$CONFIG_PATH"
    else
        # Append new
        echo "${key}=${value}" >> "$CONFIG_PATH"
    fi
}

set_config "hw.ramSize" "512"
set_config "hw.cpu.ncore" "2"
set_config "hw.gpu.enabled" "yes"
set_config "hw.gpu.mode" "host"
set_config "disk.dataPartition.size" "1G"
set_config "vm.heapSize" "128"
set_config "hw.keyboard" "yes"
set_config "hw.mainKeys" "no"
set_config "showDeviceFrame" "no"


echo "Done! The AVD is now optimized for arca."

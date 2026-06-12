#!/bin/bash
set -e

# Terminate execution on error and print details
error_handler() {
  echo -e "\n\033[0;31m[ERROR] Installation failed. Please check the logs above.\033[0m"
}
trap 'error_handler' ERR

# Premium ASCII Art Header
echo -e "\033[1;36m"
echo "    👻  G H O S T   C O D E R  👻"
echo "========================================="
echo "   macOS Premium Installer & Setup Tool"
echo "========================================="
echo -e "\033[0m"

# Step 1: Detect Latest Release
echo -e "\033[1;34m[1/5]\033[0m Fetching latest release information from GitHub..."
LATEST_RELEASE=$(curl -s https://api.github.com/repos/mkshaonexe/Ghost-coder/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -z "$LATEST_RELEASE" ]; then
  LATEST_RELEASE="v1.2.1"
  echo "  * Falling back to release version: $LATEST_RELEASE"
else
  echo "  * Found latest release: $LATEST_RELEASE"
fi

# Step 2: Download the app package
TEMP_DIR=$(mktemp -d)
ZIP_PATH="${TEMP_DIR}/Ghost_Coder_macOS.zip"
DOWNLOAD_URL="https://github.com/mkshaonexe/Ghost-coder/releases/download/${LATEST_RELEASE}/Ghost_Coder_macOS.zip"

echo -e "\033[1;34m[2/5]\033[0m Downloading Ghost Coder package..."
echo "  * URL: $DOWNLOAD_URL"
curl -L -o "$ZIP_PATH" "$DOWNLOAD_URL"

# Step 3: Extract the zip
echo -e "\033[1;34m[3/5]\033[0m Extracting Ghost Coder.app..."
cd "$TEMP_DIR"
unzip -q "Ghost_Coder_macOS.zip"

# Step 4: Install to Applications folder
echo -e "\033[1;34m[4/5]\033[0m Installing to /Applications..."
TARGET_APP="/Applications/Ghost Coder.app"

# Remove existing version if present
if [ -d "$TARGET_APP" ] || [ -e "$TARGET_APP" ]; then
  echo "  * Removing existing Ghost Coder version..."
  if rm -rf "$TARGET_APP" 2>/dev/null; then
    echo "  * Existing version removed."
  else
    echo "  * Privileges required to remove existing app bundle. Requesting root permission..."
    sudo rm -rf "$TARGET_APP"
  fi
fi

# Move the new bundle
if cp -R "Ghost Coder.app" "/Applications/" 2>/dev/null; then
  echo "  * App bundle copied successfully."
else
  echo "  * Privileges required to write to /Applications. Requesting root permission..."
  sudo cp -R "Ghost Coder.app" "/Applications/"
fi

# Step 5: Strip Gatekeeper Quarantine Attributes
echo -e "\033[1;34m[5/5]\033[0m Clearing macOS Gatekeeper quarantine flags..."
if xattr -cr "$TARGET_APP" 2>/dev/null; then
  echo "  * Gatekeeper restrictions removed successfully."
else
  echo "  * Privileges required to modify attributes. Requesting root permission..."
  sudo xattr -cr "$TARGET_APP"
  echo "  * Gatekeeper restrictions removed."
fi

# Clean up temp files
rm -rf "$TEMP_DIR"

# Launch the Application
echo -e "\n\033[1;32m=== Installation Complete! ===\033[0m"
echo -e "Launching Ghost Coder...\n"
open "/Applications/Ghost Coder.app"

echo -e "\033[1;33m⚠️  ATTENTION REQUIRED: Accessibility Permissions\033[0m"
echo -e "Ghost Coder requires Accessibility permissions to intercept keystrokes."
echo -e "If prompted, please open System Settings and authorize it:"
echo -e "  \033[1mSystem Settings ➔ Privacy & Security ➔ Accessibility ➔ Enable 'Ghost Coder'\033[0m"
echo -e "----------------------------------------------------------------------"

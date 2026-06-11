#!/bin/bash
set -e

echo "=== Building Ghost Coder v1.1.0 ==="
rm -rf "Ghost Coder/build"
rm -f Ghost_Coder_macOS.zip Ghost_Coder_macOS.dmg

xcodebuild -project "Ghost Coder/Ghost Coder.xcodeproj" -scheme "Ghost Coder" -configuration Release build CONFIGURATION_BUILD_DIR=build/Release

echo "=== Packaging as ZIP ==="
cd "Ghost Coder/build/Release"
zip -r -y "../../../Ghost_Coder_macOS.zip" "Ghost Coder.app"
cd ../../..

echo "=== Packaging as DMG ==="
rm -rf build/dmg_tmp
mkdir -p build/dmg_tmp
cp -R "Ghost Coder/build/Release/Ghost Coder.app" build/dmg_tmp/
ln -s /Applications build/dmg_tmp/Applications
hdiutil create -volname "Ghost Coder" -srcfolder build/dmg_tmp -ov -format UDZO Ghost_Coder_macOS.dmg
rm -rf build/dmg_tmp

echo "=== Creating Tag and GitHub Release ==="
# Make sure we have the latest tags
git fetch --tags

# Add build assets to gitignore if not already ignored
if ! grep -q "Ghost_Coder_macOS.zip" .gitignore; then
  echo "Ghost_Coder_macOS.zip" >> .gitignore
fi
if ! grep -q "Ghost_Coder_macOS.dmg" .gitignore; then
  echo "Ghost_Coder_macOS.dmg" >> .gitignore
fi
if ! grep -q "build/" .gitignore; then
  echo "build/" >> .gitignore
fi

# Ensure build artifacts are ignored and not tracked
git rm -r --cached "Ghost Coder/build" || true
git rm -r --cached "Ghost_Coder_macOS.zip" || true
git rm -r --cached "Ghost_Coder_macOS.dmg" || true
git rm -r --cached "build" || true

# Commit gitignore changes if any
git add .gitignore
git commit -m "Update gitignore for build artifacts" || true
git push origin main || true

# Tag the commit
git tag -d v1.1.0 || true
git push origin :refs/tags/v1.1.0 || true
git tag v1.1.0
git push origin v1.1.0

# Create Github Release using gh
echo "=== Publishing to GitHub Releases ==="
gh release delete v1.1.0 --yes || true
gh release create v1.1.0 Ghost_Coder_macOS.zip Ghost_Coder_macOS.dmg \
  --title "v1.1.0 — Production Release" \
  --notes "This release implements the new production installer pipeline. Standard installation can now be completed via a single Terminal command."

echo "=== Release published successfully! ==="

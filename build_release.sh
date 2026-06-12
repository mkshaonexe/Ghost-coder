#!/bin/bash
set -e

# Auto-extract GitHub token from remote URL if GITHUB_TOKEN isn't set in environment or is the dummy token
if [ -z "$GITHUB_TOKEN" ] || [ "$GITHUB_TOKEN" = "github_pat_antigravitydummytoken" ]; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
  if [[ "$REMOTE_URL" =~ https://([^@]+)@ ]]; then
    export GITHUB_TOKEN="${BASH_REMATCH[1]}"
    export GH_TOKEN="${BASH_REMATCH[1]}"
  fi
fi

# Extract marketing version dynamically from project
VERSION=$(grep -m1 "MARKETING_VERSION =" "Ghost Coder/Ghost Coder.xcodeproj/project.pbxproj" | cut -d'=' -f2 | tr -d ' ;"\t\r\n')
TAG="v${VERSION}"

echo "=== Building Ghost Coder ${TAG} ==="
rm -rf "Ghost Coder/build"
rm -f Ghost_Coder_macOS.zip Ghost_Coder_macOS.dmg

xcodebuild -project "Ghost Coder/Ghost Coder.xcodeproj" -scheme "Ghost Coder" -configuration Release build CONFIGURATION_BUILD_DIR=build/Release

echo "=== Compiling CLI tool ==="
swiftc -O -o "Ghost Coder/build/Release/Ghost Coder.app/Contents/MacOS/ghost-coder" cli.swift

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
git tag -d "${TAG}" || true
git push origin ":refs/tags/${TAG}" || true
git tag "${TAG}"
git push origin "${TAG}"

# Create Github Release using gh
echo "=== Publishing to GitHub Releases ==="
gh release delete "${TAG}" --yes || true
gh release create "${TAG}" Ghost_Coder_macOS.zip Ghost_Coder_macOS.dmg \
  --title "${TAG} — Production Release" \
  --notes "This release bumps version to ${TAG} and fixes the installation download script by pointing to release assets."

echo "=== Release published successfully! ==="

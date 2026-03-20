#!/bin/bash

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./rl.sh <version> (e.g. ./rl.sh 1.2.0)"
  exit 1
fi

echo "🔴 Releasing Lal Bus v$VERSION..."

# 1. Update version in pubspec.yaml
sed -i "s/^version: .*/version: $VERSION+$(date +%s)/" pubspec.yaml
echo "✓ Updated version to $VERSION"

# 2. Update version in settings screen
sed -i "s/Version [0-9]*\.[0-9]*\.[0-9]*/Version $VERSION/" lib/screens/settings_screen.dart
echo "✓ Updated version in app"

# 3. Build release APK
echo "🔨 Building APK..."
flutter build apk --release
if [ $? -ne 0 ]; then
  echo "✗ Build failed!"
  exit 1
fi
echo "✓ APK built"

# 4. Commit and push source code
git add .
git commit -m "🔴 Lal Bus v$VERSION"
git push origin main
echo "✓ Source code pushed"

# 5. Create GitHub release with APK
gh release create v$VERSION \
  build/app/outputs/flutter-apk/app-release.apk \
  --title "🔴 Lal Bus v$VERSION" \
  --notes "## Lal Bus v$VERSION

### Install
Download the APK below and install on your Android device."

if [ $? -eq 0 ]; then
  echo "✓ GitHub release created"
  echo ""
  echo "🎉 Done! Lal Bus v$VERSION released."
  echo "👉 https://github.com/MasadMoral/lal-bus/releases/tag/v$VERSION"
else
  echo "✗ GitHub release failed. APK is at: build/app/outputs/flutter-apk/app-release.apk"
fi

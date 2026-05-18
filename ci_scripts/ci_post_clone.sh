#!/bin/sh

# Xcode Cloud — post-clone hook for the Train Cosy Flutter app.
#
# Xcode Cloud runs xcodebuild against ios/Runner.xcworkspace but has no Flutter
# tooling on the runner. This script installs Flutter, resolves Dart packages,
# installs CocoaPods, and pins the iOS build number to CI_BUILD_NUMBER so each
# archive uploads to App Store Connect without "duplicate version" rejections.

set -eu
set -x

FLUTTER_CHANNEL="stable"
FLUTTER_INSTALL_DIR="$HOME/flutter"

echo "==> Installing Flutter ($FLUTTER_CHANNEL)"
git clone --depth 1 --branch "$FLUTTER_CHANNEL" \
  https://github.com/flutter/flutter.git "$FLUTTER_INSTALL_DIR"
export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
flutter --version

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> flutter precache --ios"
flutter precache --ios

echo "==> flutter pub get"
flutter pub get

# Pin the iOS CFBundleVersion to Xcode Cloud's auto-incrementing build number.
# Flutter's Info.plist references $(FLUTTER_BUILD_NUMBER), which is resolved
# from ios/Flutter/Generated.xcconfig at archive time.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  CONFIG="ios/Flutter/Generated.xcconfig"
  echo "==> Pinning FLUTTER_BUILD_NUMBER to $CI_BUILD_NUMBER in $CONFIG"
  if grep -q '^FLUTTER_BUILD_NUMBER=' "$CONFIG"; then
    sed -i '' "s/^FLUTTER_BUILD_NUMBER=.*/FLUTTER_BUILD_NUMBER=$CI_BUILD_NUMBER/" "$CONFIG"
  else
    echo "FLUTTER_BUILD_NUMBER=$CI_BUILD_NUMBER" >> "$CONFIG"
  fi
fi

echo "==> pod install"
cd ios
pod install

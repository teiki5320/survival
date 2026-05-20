#!/bin/sh

# Xcode Cloud — post-clone hook for the Train Cosy Flutter app.
#
# Xcode Cloud runs xcodebuild against ios/Runner.xcworkspace but has no Flutter
# tooling on the runner. This script installs Flutter, resolves Dart packages,
# wires plugin integration into the iOS project, and pins the iOS build number
# to CI_BUILD_NUMBER so each archive uploads to App Store Connect without
# "duplicate version" rejections.

set -eu
set -x

# Pin Flutter to a known-good tag instead of tracking `stable`. Flutter 3.44.0
# (released 2026-05-15) regressed `install_code_assets` with "Unknown architecture
# in otool output: arm64e" during xcodebuild archive. Bump this tag once
# upstream is fixed.
FLUTTER_VERSION="3.43.0"
FLUTTER_INSTALL_DIR="$HOME/flutter"

echo "==> Installing Flutter $FLUTTER_VERSION"
git clone --depth 1 --branch "$FLUTTER_VERSION" \
  https://github.com/flutter/flutter.git "$FLUTTER_INSTALL_DIR"
export PATH="$FLUTTER_INSTALL_DIR/bin:$PATH"
flutter --version

cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "==> flutter precache --ios"
flutter precache --ios

echo "==> flutter pub get"
flutter pub get

# Wire plugin integration into the iOS project (Swift Package Manager on
# recent Flutter scaffolds, CocoaPods on older ones) and generate
# ios/Flutter/Generated.xcconfig. Without this step, GeneratedPluginRegistrant.m
# references plugin modules that are never attached to the Xcode project, and
# the archive fails with "Module 'xxx_darwin' not found".
echo "==> flutter build ios --config-only"
flutter build ios --config-only --no-codesign

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

# This project uses Swift Package Manager for Flutter plugins, so no Podfile
# is generated. Only run `pod install` if a Podfile actually exists — useful
# if a future plugin forces a CocoaPods fallback.
if [ -f "ios/Podfile" ]; then
  echo "==> pod install"
  cd ios
  pod install
else
  echo "==> no ios/Podfile (Swift Package Manager integration), skipping pod install"
fi

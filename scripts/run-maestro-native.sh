#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
EXAMPLE_APP_DIR="$ROOT_DIR/example-app"
PLATFORM="${1:-ios}"

find_booted_ios_simulator() {
  xcrun simctl list devices available | sed -nE 's/.*\(([A-F0-9-]+)\) \(Booted\).*/\1/p' | head -n 1
}

find_available_ios_simulator() {
  xcrun simctl list devices available | sed -nE 's/.*iPhone[^)]*\(([A-F0-9-]+)\) \(Shutdown\).*/\1/p' | head -n 1
}

run_ios() {
  SIMULATOR_ID="${MAESTRO_IOS_SIMULATOR_ID:-$(find_booted_ios_simulator)}"
  if [ -z "$SIMULATOR_ID" ]; then
    SIMULATOR_ID="$(find_available_ios_simulator)"
  fi

  if [ -z "$SIMULATOR_ID" ]; then
    echo "No available iOS simulator found." >&2
    exit 1
  fi

  xcrun simctl boot "$SIMULATOR_ID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_ID" -b

  cd "$EXAMPLE_APP_DIR"
  bun install >/dev/null
  bunx cap sync ios >/dev/null

  cd "$EXAMPLE_APP_DIR/ios/App"
  xcodebuild \
    -project App.xcodeproj \
    -scheme App \
    -destination "id=$SIMULATOR_ID" \
    -derivedDataPath "$ROOT_DIR/build/example-ios" \
    build >/dev/null

  APP_PATH="$ROOT_DIR/build/example-ios/Build/Products/Debug-iphonesimulator/App.app"
  APP_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")

  xcrun simctl uninstall "$SIMULATOR_ID" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl install "$SIMULATOR_ID" "$APP_PATH"

  cd "$ROOT_DIR"
  maestro test --platform ios --device "$SIMULATOR_ID" .maestro/example-app-ios.yaml
}

run_android() {
  ANDROID_DEVICE_ID="${MAESTRO_ANDROID_DEVICE_ID:-$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')}"

  if [ -z "$ANDROID_DEVICE_ID" ]; then
    echo "No Android emulator/device detected." >&2
    exit 1
  fi

  cd "$EXAMPLE_APP_DIR"
  bun install >/dev/null
  bunx cap sync android >/dev/null

  cd "$EXAMPLE_APP_DIR/android"
  ./gradlew :app:assembleDebug >/dev/null
  adb -s "$ANDROID_DEVICE_ID" install -r app/build/outputs/apk/debug/app-debug.apk >/dev/null

  cd "$ROOT_DIR"
  maestro test --platform android --device "$ANDROID_DEVICE_ID" .maestro/example-app-android.yaml
}

case "$PLATFORM" in
  ios)
    run_ios
    ;;
  android)
    run_android
    ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    echo "Usage: $0 [ios|android]" >&2
    exit 1
    ;;
esac

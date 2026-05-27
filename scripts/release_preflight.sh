#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PLIST="$ROOT_DIR/iOS/ScreenshotRoll/Info.plist"
EXT_PLIST="$ROOT_DIR/iOS/ShareExtension/Info.plist"
V2_PLIST="$ROOT_DIR/iOS/ScreenshotRollV2/Info.plist"
APP_MANIFEST="$ROOT_DIR/iOS/ScreenshotRoll/PrivacyInfo.xcprivacy"
EXT_MANIFEST="$ROOT_DIR/iOS/ShareExtension/PrivacyInfo.xcprivacy"
V2_MANIFEST="$ROOT_DIR/iOS/ScreenshotRollV2/PrivacyInfo.xcprivacy"
ICON_DIR="$ROOT_DIR/iOS/ScreenshotRoll/Views/Components/Assets.xcassets/AppIcon.appiconset"

failures=0
warnings=0

ok() {
  echo "OK: $*"
}

warn() {
  echo "WARN: $*"
  warnings=$((warnings + 1))
}

fail() {
  echo "FAIL: $*"
  failures=$((failures + 1))
}

echo "Running Screenshot Roll preflight..."

if xcodebuild -version >/dev/null 2>&1; then
  ok "Full Xcode command line tools are available."
else
  fail "xcodebuild is unavailable. Install/select full Xcode before release."
fi

if [ -f "$ROOT_DIR/iOS/project.yml" ]; then
  ok "XcodeGen spec exists."
else
  fail "Missing iOS/project.yml."
fi

if [ -d "$ROOT_DIR/iOS/ScreenshotRoll.xcodeproj" ]; then
  ok "Generated Xcode project exists."
else
  fail "Missing iOS/ScreenshotRoll.xcodeproj. Run ./scripts/generate_xcodeproj.sh."
fi

if [ -f "$APP_PLIST" ] && [ -f "$EXT_PLIST" ]; then
  app_group="$(plutil -extract AppGroupIdentifier raw -o - "$APP_PLIST" 2>/dev/null || true)"
  ext_group="$(plutil -extract AppGroupIdentifier raw -o - "$EXT_PLIST" 2>/dev/null || true)"

  if [ -z "$app_group" ] || [ -z "$ext_group" ]; then
    fail "AppGroupIdentifier missing in one or both primary plist files."
  elif [ "$app_group" = "$ext_group" ]; then
    ok "App Group matches between app and extension."
  else
    fail "App Group differs between app and extension."
  fi
fi

if rg -n "yourcompany" "$ROOT_DIR/iOS" >/dev/null 2>&1; then
  fail "Placeholder identifiers remain under iOS/."
else
  ok "No placeholder identifiers remain under iOS/."
fi

if [ -f "$APP_MANIFEST" ] && [ -f "$EXT_MANIFEST" ] && [ -f "$V2_MANIFEST" ]; then
  ok "Privacy manifests exist for app, extension, and V2."
else
  fail "One or more privacy manifests are missing."
fi

if [ -f "$ICON_DIR/icon-1024.png" ]; then
  ok "1024px App Store icon exists."
else
  fail "Missing 1024px App Store icon."
fi

if [ -f "$ROOT_DIR/iOS/ScreenshotRoll/LaunchScreen.storyboard" ]; then
  ok "Launch screen storyboard exists."
else
  fail "Missing launch screen storyboard."
fi

for plist in "$APP_PLIST" "$EXT_PLIST" "$V2_PLIST"; do
  if plutil -lint "$plist" >/dev/null 2>&1; then
    ok "Valid plist: $plist"
  else
    fail "Invalid plist: $plist"
  fi
done

if rg -n "isPurchased: Bool = true" "$ROOT_DIR/iOS/ScreenshotRoll/Services/Pricing/StoreService.swift" >/dev/null 2>&1; then
  fail "StoreService is still hardcoded unlocked."
else
  ok "StoreService is not hardcoded unlocked."
fi

echo
echo "Preflight summary: $failures failure(s), $warnings warning(s)."

if [ "$failures" -gt 0 ]; then
  exit 1
fi

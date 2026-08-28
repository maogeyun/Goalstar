#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Archive lives under system temp so it does not inflate the repo
ARCHIVE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/goalstar-archive.XXXXXX")"
ARCHIVE_PATH="$ARCHIVE_DIR/Goalstar.xcarchive"
trap 'rm -rf "$ARCHIVE_DIR"' EXIT

echo "==> Regenerate project (if xcodegen present)"
if [[ -x ./tools/xcodegen ]]; then
  ./tools/xcodegen generate
elif command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

echo "==> Simulator build (no signing; default DerivedData)"
xcodebuild -project Goalstar.xcodeproj -scheme Goalstar \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

echo "==> Release archive (generic iOS, allow provisioning updates)"
xcodebuild -project Goalstar.xcodeproj -scheme Goalstar \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

echo "==> Bundle checks"
APP="$ARCHIVE_PATH/Products/Applications/Goalstar.app"
test -d "$APP" || { echo "Missing app in archive"; exit 1; }
test -f "$APP/PrivacyInfo.xcprivacy" || { echo "Missing PrivacyInfo.xcprivacy in archive"; exit 1; }
test -d "$APP/PlugIns/GoalstarWidgets.appex" || { echo "Missing GoalstarWidgets.appex"; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$APP/Info.plist" | grep -q false
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist" | grep -q '2.0'
/usr/libexec/PlistBuddy -c 'Print :NSSupportsLiveActivities' "$APP/Info.plist" | grep -q true

echo "OK: release verification passed"

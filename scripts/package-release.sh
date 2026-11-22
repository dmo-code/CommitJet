#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version> (for example: 1.0.0)" >&2
  exit 2
fi

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must use semantic version format, for example 1.0.0." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR:-/tmp}/CommitJetReleaseDerived}"
OUTPUT_DIR="$ROOT_DIR/.build/releases"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/CommitJet.app"
ZIP_PATH="$OUTPUT_DIR/CommitJet-$VERSION-macOS.zip"

mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$ROOT_DIR/CommitJet.xcodeproj" \
  -scheme CommitJet \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION=1 \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Build succeeded but the app was not found at: $APP_PATH" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
(cd "$OUTPUT_DIR" && shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$ZIP_PATH").sha256")

echo "Created: $ZIP_PATH"
echo "Created: $ZIP_PATH.sha256"

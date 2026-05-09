#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Karlpogi11/LabelMerger"
RELEASE_ASSET_URL="${REPO_URL}/releases/latest/download/LabelMerger-macOS.zip"
INSTALL_DIR="${HOME}/Applications"
INSTALL_APP_PATH="${INSTALL_DIR}/LabelMerger.app"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${INSTALL_DIR}"

echo "Installing LabelMerger into ${INSTALL_APP_PATH}"

download_release() {
  curl -fL "${RELEASE_ASSET_URL}" -o "${TMP_DIR}/LabelMerger-macOS.zip"
  ditto -xk "${TMP_DIR}/LabelMerger-macOS.zip" "${TMP_DIR}/unzipped"
  test -d "${TMP_DIR}/unzipped/LabelMerger.app"
  ditto "${TMP_DIR}/unzipped/LabelMerger.app" "${INSTALL_APP_PATH}"
}

build_from_source() {
  git clone --depth 1 "${REPO_URL}.git" "${TMP_DIR}/repo"

  xcodebuild \
    -project "${TMP_DIR}/repo/LabelMerger.xcodeproj" \
    -scheme LabelMerger \
    -configuration Release \
    -destination 'platform=macOS' \
    -derivedDataPath "${TMP_DIR}/DerivedData" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    build

  test -d "${TMP_DIR}/DerivedData/Build/Products/Release/LabelMerger.app"
  ditto "${TMP_DIR}/DerivedData/Build/Products/Release/LabelMerger.app" "${INSTALL_APP_PATH}"
}

rm -rf "${INSTALL_APP_PATH}"

if download_release; then
  echo "Installed from latest GitHub release."
else
  echo "Latest release asset not found. Building from source instead..."
  build_from_source
fi

xattr -dr com.apple.quarantine "${INSTALL_APP_PATH}" >/dev/null 2>&1 || true

echo "Done. App installed locally at ${INSTALL_APP_PATH}"

#!/usr/bin/env bash
# Cloud Agent bootstrap for the Goalstar iOS project.
#
# NOTE: Goalstar is a native iOS/SwiftUI app. A full build/run requires
# macOS + Xcode + the iOS Simulator (xcodebuild, xcodegen, iOS SDK,
# SwiftUI/SwiftData/WidgetKit/ActivityKit/UIKit). None of these exist on
# Linux, so Cloud Agents cannot compile or run the app here. This script
# installs the open-source Swift toolchain for Linux so the platform-agnostic
# Swift sources can be parsed / type-checked and editing tooling works.
set -euo pipefail

SWIFT_VERSION="6.1.2"
SWIFT_HOME="/opt/swift"
SWIFT_BIN="${SWIFT_HOME}/usr/bin"

install_system_deps() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
    libgcc-13-dev libncurses-dev libpython3-dev libsqlite3-0 \
    libstdc++-13-dev libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
}

install_swift() {
  if [ -x "${SWIFT_BIN}/swift" ] && "${SWIFT_BIN}/swift" --version 2>/dev/null | grep -q "${SWIFT_VERSION}"; then
    echo "Swift ${SWIFT_VERSION} already installed at ${SWIFT_HOME}"
    return
  fi
  local url="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  echo "Downloading Swift ${SWIFT_VERSION} for Ubuntu 24.04..."
  curl -fL --retry 4 --retry-delay 4 -o "${tmp}/swift.tar.gz" "${url}"
  sudo mkdir -p "${SWIFT_HOME}"
  sudo tar xzf "${tmp}/swift.tar.gz" -C "${SWIFT_HOME}" --strip-components=1
  rm -rf "${tmp}"
}

add_to_path() {
  local profile="${HOME}/.bashrc"
  if ! grep -q "${SWIFT_BIN}" "${profile}" 2>/dev/null; then
    echo "export PATH=\"${SWIFT_BIN}:\$PATH\"" >> "${profile}"
  fi
}

install_system_deps
install_swift
add_to_path

"${SWIFT_BIN}/swift" --version
echo "Swift toolchain ready. Reminder: building/running Goalstar itself requires macOS + Xcode."

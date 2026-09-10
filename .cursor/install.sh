#!/usr/bin/env bash
# Cloud Agent bootstrap for the Goalstar project.
#
# IMPORTANT: Goalstar is a native iOS / SwiftUI app. A full build & run
# (xcodebuild + iOS Simulator) requires macOS + Xcode and the Apple SDKs
# (SwiftUI, SwiftData, UIKit, WidgetKit, ActivityKit, AppIntents, StoreKit,
# UserNotifications). None of these exist on Linux, so a Cloud Agent cannot
# compile or launch the full app here.
#
# What this script CAN do on Linux is install the open-source Swift toolchain
# so that:
#   - editing tooling (sourcekit-lsp) works,
#   - Swift syntax is validated,
#   - platform-agnostic, Foundation-only sources can actually be compiled.
#
# The script is idempotent: re-running it is a no-op once the toolchain is in
# place.
set -euo pipefail

SWIFT_VERSION="6.1.2"
SWIFT_HOME="/opt/swift"
SWIFT_BIN="${SWIFT_HOME}/usr/bin"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

install_system_deps() {
  log "Installing system dependencies for the Swift runtime"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 \
    libgcc-13-dev libncurses-dev libpython3-dev libsqlite3-0 \
    libstdc++-13-dev libxml2-dev libz3-dev pkg-config tzdata unzip zlib1g-dev
}

install_swift() {
  if [ -x "${SWIFT_BIN}/swift" ] && "${SWIFT_BIN}/swift" --version 2>/dev/null | grep -q "${SWIFT_VERSION}"; then
    log "Swift ${SWIFT_VERSION} already installed at ${SWIFT_HOME}"
    return
  fi
  local url="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu24.04.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  log "Downloading Swift ${SWIFT_VERSION} for Ubuntu 24.04"
  curl -fL --retry 4 --retry-delay 4 -o "${tmp}/swift.tar.gz" "${url}"
  sudo rm -rf "${SWIFT_HOME}"
  sudo mkdir -p "${SWIFT_HOME}"
  log "Extracting toolchain to ${SWIFT_HOME}"
  sudo tar xzf "${tmp}/swift.tar.gz" -C "${SWIFT_HOME}" --strip-components=1
  rm -rf "${tmp}"
}

link_swift() {
  # Expose the toolchain on the default PATH for every shell (interactive or
  # not) without depending on profile files being sourced.
  log "Linking swift binaries into /usr/local/bin"
  for bin in swift swiftc sourcekit-lsp; do
    if [ -x "${SWIFT_BIN}/${bin}" ]; then
      sudo ln -sf "${SWIFT_BIN}/${bin}" "/usr/local/bin/${bin}"
    fi
  done
  # Also add to ~/.bashrc for interactive convenience.
  local profile="${HOME}/.bashrc"
  if ! grep -q "${SWIFT_BIN}" "${profile}" 2>/dev/null; then
    echo "export PATH=\"${SWIFT_BIN}:\$PATH\"" >> "${profile}"
  fi
}

install_system_deps
install_swift
link_swift

log "Swift toolchain ready"
swift --version
echo
echo "Reminder: building / running the full Goalstar iOS app requires macOS + Xcode."

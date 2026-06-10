#!/bin/bash
# Downloads and builds PJSIP (arm64, host-only).
# Universal binary (arm64+x86_64) is deferred to F5 — see project tasks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PJ_VERSION="2.17"
SRC="$ROOT/third_party/pjproject-$PJ_VERSION"
TARBALL="$ROOT/third_party/pjproject-$PJ_VERSION.tar.gz"
LOG_PREFIX="[build-pjsip]"

if [ ! -d "$SRC" ]; then
  mkdir -p "$ROOT/third_party"
  if [ ! -f "$TARBALL" ]; then
    echo "$LOG_PREFIX downloading pjproject $PJ_VERSION"
    curl -fsSL -o "$TARBALL" \
      "https://github.com/pjsip/pjproject/archive/refs/tags/$PJ_VERSION.tar.gz"
  fi
  tar xzf "$TARBALL" -C "$ROOT/third_party"
fi

OPUS_PREFIX="$(brew --prefix opus)"
SSL_FLAG=""
if OPENSSL_PREFIX="$(brew --prefix openssl@3 2>/dev/null)" && [ -d "$OPENSSL_PREFIX" ]; then
  SSL_FLAG="--with-ssl=$OPENSSL_PREFIX"
fi

cd "$SRC"

# Must exist before configure (pjlib won't build without it)
touch pjlib/include/pj/config_site.h

echo "$LOG_PREFIX configure (opus=$OPUS_PREFIX ssl=${SSL_FLAG:-auto})"
# Audio-only for the MVP: video would drag SDL2/ffmpeg from Homebrew into the bundle
./configure --with-opus="$OPUS_PREFIX" $SSL_FLAG CFLAGS="-O2" \
  --disable-video --disable-sdl --disable-ffmpeg --disable-vpx --disable-openh264

echo "$LOG_PREFIX make dep"
make dep

echo "$LOG_PREFIX make -j$(sysctl -n hw.ncpu)"
make -j"$(sysctl -n hw.ncpu)"

echo "$LOG_PREFIX OK — pjsua binaries:"
ls pjsip-apps/bin/

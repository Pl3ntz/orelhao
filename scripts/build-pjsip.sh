#!/bin/bash
# Compila PJSIP 2.17 para o spike F0 (arm64, host-only).
# Universal binary (arm64+x86_64) fica para a F5 — ver tasks do projeto.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/third_party/pjproject-2.17"
LOG_PREFIX="[build-pjsip]"

OPUS_PREFIX="$(brew --prefix opus)"
SSL_FLAG=""
if OPENSSL_PREFIX="$(brew --prefix openssl@3 2>/dev/null)" && [ -d "$OPENSSL_PREFIX" ]; then
  SSL_FLAG="--with-ssl=$OPENSSL_PREFIX"
fi

cd "$SRC"

# Obrigatório existir antes do configure (pjlib não compila sem ele)
touch pjlib/include/pj/config_site.h

echo "$LOG_PREFIX configure (opus=$OPUS_PREFIX ssl=${SSL_FLAG:-auto})"
# Áudio-only no MVP: vídeo arrastaria SDL2/ffmpeg do Homebrew pro bundle
./configure --with-opus="$OPUS_PREFIX" $SSL_FLAG CFLAGS="-O2" \
  --disable-video --disable-sdl --disable-ffmpeg --disable-vpx --disable-openh264

echo "$LOG_PREFIX make dep"
make dep

echo "$LOG_PREFIX make -j$(sysctl -n hw.ncpu)"
make -j"$(sysctl -n hw.ncpu)"

echo "$LOG_PREFIX OK — binários pjsua:"
ls pjsip-apps/bin/

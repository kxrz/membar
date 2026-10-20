#!/bin/zsh
# MemBar installer: builds from source on your Mac. No binary download, no admin rights.
#   curl -fsSL https://raw.githubusercontent.com/kxrz/membar/main/install.sh | zsh
set -euo pipefail

APP_DIR="${MEMBAR_APP_DIR:-$HOME/Applications}"
BIN_DIR="${MEMBAR_BIN_DIR:-$HOME/.local/bin}"
APP="$APP_DIR/MemBar.app"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "MemBar needs Apple's free Command Line Tools to build. Run this, then try again:"
  echo "  xcode-select --install"
  exit 1
fi

# Source: this checkout, or a fresh copy of main when piped from curl
SRC="${0:A:h}"
if [[ ! -f "$SRC/Sources/main.swift" ]]; then
  SRC="$(mktemp -d)"
  curl -fsSL https://github.com/kxrz/membar/archive/refs/heads/main.tar.gz | tar -xz -C "$SRC" --strip-components 1
fi

echo "Building MemBar…"
pkill -x MemBar 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BIN_DIR"
swiftc -O "$SRC"/Sources/*.swift -o "$APP/Contents/MacOS/MemBar"
cp "$SRC/Info.plist" "$APP/Contents/"
cp -R "$SRC"/Resources/* "$APP/Contents/Resources/"
codesign --force --sign - "$APP" 2>/dev/null

# `mem` in the terminal
printf '#!/bin/sh\nexec "%s/Contents/MacOS/MemBar" mem "$@"\n' "$APP" > "$BIN_DIR/mem"
chmod +x "$BIN_DIR/mem"

"$APP/Contents/MacOS/MemBar" --enable-login
open "$APP"

echo "✓ MemBar is in your menu bar and will open at login."
echo "✓ Type 'mem' in a terminal for the same reading."
[[ ":$PATH:" == *":$BIN_DIR:"* ]] || echo "  (add $BIN_DIR to your PATH first: echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc)"

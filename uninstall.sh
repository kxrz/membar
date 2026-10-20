#!/bin/zsh
# Removes MemBar, its `mem` command and its login item
APP="${MEMBAR_APP_DIR:-$HOME/Applications}/MemBar.app"
BIN_DIR="${MEMBAR_BIN_DIR:-$HOME/.local/bin}"

[[ -x "$APP/Contents/MacOS/MemBar" ]] && "$APP/Contents/MacOS/MemBar" --disable-login
pkill -x MemBar 2>/dev/null
rm -rf "$APP" "$BIN_DIR/mem"
echo "✓ MemBar removed."

#!/bin/zsh
set -euo pipefail

APP="$HOME/Applications/DNK_Piu.app"
pkill -x DNKPiu 2>/dev/null || true
rm -rf "$APP"
echo "✅ DNK_Piu successfully uninstalled."

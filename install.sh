#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UUID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["uuid"])' "$ROOT/applet/metadata.json")"
DEST="$HOME/.local/share/cinnamon/applets/$UUID"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/comfyui-cinnamon-applet/config"

mkdir -p "$DEST/scripts" "$(dirname "$CONFIG")"

cp "$ROOT/applet/"* "$DEST/"
cp "$ROOT/scripts/comfyui-applet.sh" "$DEST/scripts/"
chmod +x "$DEST/scripts/comfyui-applet.sh"

if [[ ! -f "$CONFIG" ]]; then
    cp "$ROOT/config/config.example" "$CONFIG"
    echo "Created configuration: $CONFIG"
    echo "Edit PROJECT_DIR to point to your Docker Compose project."
fi

echo "Installed applet: $DEST"
echo "Enable it in Cinnamon's Applets settings, then reload Cinnamon."

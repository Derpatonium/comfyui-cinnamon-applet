#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/comfyui-cinnamon-applet/config"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Configuration missing: $CONFIG_FILE" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_FILE"

: "${PROJECT_DIR:?PROJECT_DIR is not configured}"
: "${COMFYUI_URL:?COMFYUI_URL is not configured}"

BROWSER="${BROWSER:-brave-browser}"
APP_WM_CLASS="${APP_WM_CLASS:-127.0.0.1.Brave-browser}"
BROWSER_WM_CLASS="${BROWSER_WM_CLASS:-brave-browser.Brave-browser}"
TERMINAL="${TERMINAL:-terminator}"
TERMINAL_WM_CLASS="${TERMINAL_WM_CLASS:-terminator.Terminator}"
TERMINAL_LAYOUT="${TERMINAL_LAYOUT:-ComfyUI-Docker}"
TERMINAL_GEOMETRY="${TERMINAL_GEOMETRY:-}"

service_ready() {
    python3 - "$COMFYUI_URL" <<'PY' 2>/dev/null
import sys
import urllib.request
urllib.request.urlopen(sys.argv[1], timeout=2).close()
PY
}

list_windows() {
    wmctrl -lx | awk \
        -v app="$APP_WM_CLASS" \
        -v browser="$BROWSER_WM_CLASS" '
    $3 == app || ($3 == browser && tolower($0) ~ /comfyui/) {
        title = $5
        for (i = 6; i <= NF; i++)
            title = title " " $i
        print $1 "|" title
    }'
}

focus_window() {
    wmctrl -ia "$1"
}

ensure_comfyui() {
    [[ -d "$PROJECT_DIR" ]] || {
        echo "Docker project directory not found: $PROJECT_DIR" >&2
        return 1
    }

    cd "$PROJECT_DIR"
    docker compose up -d

    python3 - "$COMFYUI_URL" <<'PY'
import sys
import time
import urllib.request

url = sys.argv[1]

for _ in range(90):
    try:
        urllib.request.urlopen(url, timeout=1).close()
        break
    except Exception:
        time.sleep(1)
else:
    raise SystemExit("ComfyUI did not become available within 90 seconds.")
PY
}

open_comfyui() {
    if ! service_ready; then
        ensure_comfyui
    fi

    local dedicated
    dedicated="$(wmctrl -lx | awk -v target="$APP_WM_CLASS" \
        '$3 == target {print $1; exit}')"

    if [[ -n "$dedicated" ]]; then
        focus_window "$dedicated"
        return
    fi

    local existing
    existing="$(list_windows | head -n1 | cut -d'|' -f1)"

    if [[ -n "$existing" ]]; then
        focus_window "$existing"
        return
    fi

    "$BROWSER" --app="$COMFYUI_URL" --class=ComfyUI \
        >/dev/null 2>&1 &
}

open_terminator() {
    local existing
    existing="$(wmctrl -lx | awk -v target="$TERMINAL_WM_CLASS" \
        '$3 == target {print $1; exit}')"

    if [[ -n "$existing" ]]; then
        focus_window "$existing"
        return
    fi

    local args=(--layout="$TERMINAL_LAYOUT" --maximise)

    if [[ -n "$TERMINAL_GEOMETRY" ]]; then
        args+=(--geometry="$TERMINAL_GEOMETRY")
    fi

    "$TERMINAL" "${args[@]}" >/dev/null 2>&1 &
}

cycle_windows() {
    mapfile -t windows < <(list_windows | cut -d'|' -f1)

    if (( ${#windows[@]} == 0 )); then
        local was_running=1

        if ! service_ready; then
            was_running=0
            ensure_comfyui
        fi

        open_comfyui

        if (( was_running == 0 )); then
            open_terminator
        fi
        return
    fi

    local active
    active="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')"

    local next=0

    for i in "${!windows[@]}"; do
        if [[ "${windows[$i]}" == "$active" ]]; then
            next=$(( (i + 1) % ${#windows[@]} ))
            break
        fi
    done

    focus_window "${windows[$next]}"
}

case "${1:-}" in
    click) cycle_windows ;;
    list-windows) list_windows ;;
    focus-window)
        [[ "${2:-}" =~ ^0x[0-9a-fA-F]+$ ]] || exit 2
        focus_window "$2"
        ;;
    open-comfyui) open_comfyui ;;
    open-terminator) open_terminator ;;
    *)
        echo "Usage: $0 {click|list-windows|focus-window ID|open-comfyui|open-terminator}" >&2
        exit 2
        ;;
esac

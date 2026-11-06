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

PROJECT="$PROJECT_DIR"
URL="$COMFYUI_URL"
BROWSER="${BROWSER:-brave-browser}"
APP_CLASS="${APP_WM_CLASS:-127.0.0.1.Brave-browser}"
TERMINAL="${TERMINAL:-terminator}"
TERMINAL_WM_CLASS="${TERMINAL_WM_CLASS:-terminator.Terminator}"
TERMINAL_LAYOUT="${TERMINAL_LAYOUT:-ComfyUI-Docker}"
TERMINAL_GEOMETRY="${TERMINAL_GEOMETRY:-}"
TERM_ROLE="${TERMINAL_ROLE:-ComfyUI-Docker}"
WATCH_LOCK="$HOME/.cache/comfyui-docker-watch.lock"
STATUS_FILE="$HOME/.cache/comfyui-docker-starting"
WINDOW_FILE="$HOME/.cache/comfyui-docker-window"

service_ready() {
    python3 - "$URL" <<'PYREADY' 2>/dev/null
import sys
import urllib.request

urllib.request.urlopen(sys.argv[1], timeout=1).close()
PYREADY
}

print_status() {
    if [[ -e "$STATUS_FILE" ]]; then
        echo starting
        return
    fi

    local state
    state="$(docker inspect --format '{{.State.Status}}' comfyui 2>/dev/null || true)"

    case "$state" in
        running)
            if service_ready; then
                echo running
            else
                echo starting
            fi
            ;;
        created|restarting|paused)
            echo starting
            ;;
        *)
            echo stopped
            ;;
    esac
}

list_windows() {
    wmctrl -lx | awk -v target="$APP_CLASS" '
        $3 == target {
            title = $5
            for (i = 6; i <= NF; i++) title = title " " $i
            print $1 "|" title
        }'
}

focus_window() {
    wmctrl -ia "$1"
}

find_terminal() {
    while read -r id; do
        [[ -n "$id" ]] || continue
        role="$(xprop -id "$id" WM_WINDOW_ROLE 2>/dev/null || true)"
        if [[ "$role" == *"\"$TERM_ROLE\""* ]]; then
            printf '%s\n' "$id"
            return
        fi
    done < <(wmctrl -lx | awk -v target="$TERMINAL_WM_CLASS" '$3 == target {print $1}')
}

close_terminal() {
    local id
    id="$(find_terminal)"
    if [[ -n "$id" ]]; then
        wmctrl -ic "$id"
    fi
}

ensure_comfyui() {
    cd "$PROJECT"
    docker compose up -d

    echo "Waiting for ComfyUI..."
    python3 - "$URL" <<'PY'
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

open_terminator() {
    local existing
    existing="$(find_terminal)"

    if [[ -n "$existing" ]]; then
        focus_window "$existing"
        return
    fi

    local args=(--no-dbus
        --role="$TERM_ROLE"
        --title="ComfyUI Docker"
        --layout="$TERMINAL_LAYOUT")

    if [[ -n "$TERMINAL_GEOMETRY" ]]; then
        args+=(--geometry="$TERMINAL_GEOMETRY")
    fi

    args+=(--maximise)
    "$TERMINAL" "${args[@]}" >/dev/null 2>&1 &

    for _ in {1..10}; do
        sleep 1
        existing="$(find_terminal)"
        if [[ -n "$existing" ]]; then
            return
        fi
    done

    echo "Could not find the dedicated ComfyUI terminal window." >&2
    return 1
}

open_browser() {
    local existing
    existing="$(list_windows | head -n1 | cut -d'|' -f1)"

    if [[ -n "$existing" ]]; then
        focus_window "$existing"
        printf '%s\n' "$existing"
        return
    fi

    "$BROWSER" --app="$URL" >/dev/null 2>&1 &

    for _ in {1..20}; do
        sleep 1
        existing="$(list_windows | head -n1 | cut -d'|' -f1)"
        if [[ -n "$existing" ]]; then
            focus_window "$existing"
            printf '%s\n' "$existing"
            return
        fi
    done

    echo "Could not find the ComfyUI browser window." >&2
    return 1
}

watch_window() {
    mkdir -p "$HOME/.cache"
    exec 9>"$WATCH_LOCK"
    flock -n 9 || return 0

    local id
    local missing_since=0

    while true; do
        id="$(cat "$WINDOW_FILE" 2>/dev/null || true)"

        if [[ ! "$id" =~ ^0x[0-9a-fA-F]+$ ]]; then
            return 0
        fi

        if wmctrl -lx 2>/dev/null | awk -v id="$id" -v app="$APP_CLASS" '
            $1 == id && $3 == app { found=1 }
            END { exit !found }
        '; then
            missing_since=0
        else
            if (( missing_since == 0 )); then
                missing_since=$SECONDS
            elif (( SECONDS - missing_since >= 30 )); then
                # Only stop if this is still the latest tracked window.
                if [[ "$(cat "$WINDOW_FILE" 2>/dev/null || true)" == "$id" ]] &&
                   ! wmctrl -lx 2>/dev/null | awk -v id="$id" -v app="$APP_CLASS" '
                       $1 == id && $3 == app { found=1 }
                       END { exit !found }
                   '; then
                    cd "$PROJECT"
                    docker compose stop comfyui
                    rm -f "$STATUS_FILE" "$WINDOW_FILE"
                    close_terminal
                    return
                fi
                missing_since=0
            fi
        fi
        sleep 2
    done
}
start_comfyui() {
    mkdir -p "$HOME/.cache"
    touch "$STATUS_FILE"

    if ! ensure_comfyui; then
        rm -f "$STATUS_FILE"
        return 1
    fi
    rm -f "$STATUS_FILE"

    local window
    window="$(open_browser)"
    open_terminator

    nohup "$0" watch-window \
        >/dev/null 2>&1 </dev/null &
}

close_comfyui() {
    rm -f "$STATUS_FILE"
    while IFS='|' read -r id title; do
        [[ -n "$id" ]] && wmctrl -ic "$id"
    done < <(list_windows)

    cd "$PROJECT"
    docker compose stop comfyui
    close_terminal
}

cycle_windows() {
    mapfile -t windows < <(list_windows | cut -d'|' -f1)
    (( ${#windows[@]} > 0 )) || return 0

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
    start|open-comfyui)
        start_comfyui
        ;;
    click)
        cycle_windows
        ;;
    list-windows)
        list_windows
        ;;
    status)
        print_status
        ;;
    focus-window)
        [[ "${2:-}" =~ ^0x[0-9a-fA-F]+$ ]] || exit 2
        focus_window "$2"
        ;;
    open-terminator)
        open_terminator
        ;;
    close-comfyui)
        close_comfyui
        ;;
    watch-window)
        watch_window "$@"
        ;;
    *)
        echo "Usage: $0 {start|click|list-windows|focus-window ID|open-terminator|close-comfyui}" >&2
        exit 2
        ;;
esac

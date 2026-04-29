#!/usr/bin/env sh
set -eu

APPDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
HOST="localhost"
PORT="${LONEWOLF_HTTP_PORT:-8797}"
NO_BROWSER=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --host)
            HOST="${2:?Missing value for --host}"
            shift 2
            ;;
        --port)
            PORT="${2:?Missing value for --port}"
            shift 2
            ;;
        --no-browser)
            NO_BROWSER=1
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN=$(command -v python3)
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN=$(command -v python)
else
    echo "Python 3 is required to launch the Lone Wolf web scaffold." >&2
    exit 1
fi

if ! command -v pwsh >/dev/null 2>&1; then
    echo "PowerShell 7 (pwsh) is required to launch the Lone Wolf web scaffold." >&2
    exit 1
fi

URL="http://$HOST:$PORT/"

if [ "$NO_BROWSER" -eq 0 ]; then
    (
        sleep 2
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$URL" >/dev/null 2>&1 || true
        elif command -v open >/dev/null 2>&1; then
            open "$URL" >/dev/null 2>&1 || true
        fi
    ) &
fi

printf '\nLone Wolf web scaffold\n'
printf 'URL: %s\n\n' "$URL"

cd "$APPDIR"
exec "$PYTHON_BIN" "$APPDIR/web/app_server.py" --host "$HOST" --port "$PORT"

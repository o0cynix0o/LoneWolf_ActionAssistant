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
CONTROL_HOST="$HOST"
if [ "$CONTROL_HOST" = "0.0.0.0" ] || [ "$CONTROL_HOST" = "::" ] || [ "$CONTROL_HOST" = "[::]" ]; then
    CONTROL_HOST="localhost"
fi
SHUTDOWN_URL="http://$CONTROL_HOST:$PORT/api/shutdown"
SERVER_PID=""

shutdown_server() {
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        "$PYTHON_BIN" - "$SHUTDOWN_URL" <<'PY' >/dev/null 2>&1 || true
import sys
import urllib.request

request = urllib.request.Request(sys.argv[1], data=b"{}", method="POST")
request.add_header("Content-Type", "application/json")
urllib.request.urlopen(request, timeout=5).read()
PY
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

trap shutdown_server INT TERM EXIT

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
printf 'Press Enter in this window to stop the web server.\n\n'

cd "$APPDIR"
"$PYTHON_BIN" "$APPDIR/web/app_server.py" --host "$HOST" --port "$PORT" &
SERVER_PID=$!

read _ || true
shutdown_server
trap - INT TERM EXIT

#!/usr/bin/env bash
# Reproducible build: imports assets, exports the Windows client and the Linux x86_64 dedicated server.
# Requires Godot 4.3-stable on PATH as `godot` (or GODOT=...) with matching export templates installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
python3 -I "$ROOT/tools/import_assets.py"
mkdir -p "$ROOT/build/windows" "$ROOT/build/linux_server"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Client" "$ROOT/build/windows/OperationBlackout.exe"
"$GODOT" --headless --path "$ROOT/game" --export-release "Linux Dedicated Server" "$ROOT/build/linux_server/blackout_server.x86_64"
cat > "$ROOT/build/linux_server/run_server.sh" <<'RUN'
#!/usr/bin/env bash
# Launch the headless dedicated server. Extra args are passed through (e.g. --port=7777 --data-dir=/srv/blackout).
DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$DIR/blackout_server.x86_64" --headless -- --server "$@"
RUN
chmod +x "$ROOT/build/linux_server/run_server.sh"
ls -la "$ROOT/build/windows" "$ROOT/build/linux_server"

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

# Package: Windows client zip is served by the dedicated server's download site (<server dir>/downloads/).
DIST="$ROOT/build/dist"
mkdir -p "$DIST" "$ROOT/build/linux_server/downloads"
rm -f "$DIST"/*.zip "$ROOT/build/linux_server/downloads"/*.zip
cat > "$ROOT/build/windows/README.txt" <<'TXT'
Operation: Blackout - Windows client
Keep OperationBlackout.exe and OperationBlackout.pck in the same folder.
Run OperationBlackout.exe -> JOIN SERVER -> enter the address shown on the server's download page (host:7777).
DEPLOY (SOLO / LOCAL) starts a private local server for solo play.
TXT
(cd "$ROOT/build/windows" && zip -q -9 "$DIST/OperationBlackout-Windows.zip" OperationBlackout.exe OperationBlackout.pck README.txt)
cp "$DIST/OperationBlackout-Windows.zip" "$ROOT/build/linux_server/downloads/"
cat > "$ROOT/build/linux_server/README.txt" <<'TXT'
Operation: Blackout - Linux x86_64 dedicated server
Start:   ./run_server.sh --port=7777 --http-port=8080 --data-dir=./server_data
Players: open http://<server-ip>:8080/ to download the Windows client, then JOIN SERVER <server-ip>:7777.
Firewall: allow UDP 7777 (game) and TCP 8080 (download site). Use --no-web to disable the site.
Files in ./downloads/ (.zip/.7z/.gz/.txt) are offered on the site.
TXT
(cd "$ROOT/build" && rm -rf OperationBlackout-Server && cp -r linux_server OperationBlackout-Server && rm -rf OperationBlackout-Server/server_data \
  && zip -q -9 -r "$DIST/OperationBlackout-Server-Linux.zip" OperationBlackout-Server && rm -rf OperationBlackout-Server)
ls -la "$DIST"

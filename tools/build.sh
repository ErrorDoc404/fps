#!/usr/bin/env bash
# Reproducible build: imports assets, exports the Windows client and the Linux dedicated servers
# (x86_64 and ARM64), then packages zips in build/dist/. Each server zip includes the Windows client
# in downloads/ so the server's download website can serve it.
# Requires Godot 4.3-stable on PATH as `godot` (or GODOT=...) with matching export templates installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
DIST="$ROOT/build/dist"
python3 -I "$ROOT/tools/import_assets.py"
mkdir -p "$ROOT/build/windows" "$DIST"
rm -f "$DIST"/*.zip
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Client" "$ROOT/build/windows/OperationBlackout.exe"

cat > "$ROOT/build/windows/README.txt" <<'TXT'
Operation: Blackout - Windows client
Keep OperationBlackout.exe and OperationBlackout.pck in the same folder.
Run OperationBlackout.exe -> JOIN SERVER -> enter the address shown on the server's download page (host:7777).
DEPLOY (SOLO / LOCAL) starts a private local server for solo play.
TXT
(cd "$ROOT/build/windows" && zip -q -9 "$DIST/OperationBlackout-Windows.zip" OperationBlackout.exe OperationBlackout.pck README.txt)

# build_server <preset> <out dir> <binary name> <arch label> <zip name>
build_server() {
  local preset="$1" dir="$ROOT/build/$2" bin="$3" arch="$4" zipname="$5"
  mkdir -p "$dir/downloads"
  rm -f "$dir/downloads"/*.zip
  "$GODOT" --headless --path "$ROOT/game" --export-release "$preset" "$dir/$bin"
  cat > "$dir/run_server.sh" <<RUN
#!/usr/bin/env bash
# Launch the headless dedicated server. Extra args are passed through (e.g. --port=7777 --http-port=8080).
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
chmod +x "\$DIR/$bin" 2>/dev/null || true
cd "\$DIR"
exec "\$DIR/$bin" --headless -- --server "\$@"
RUN
  chmod +x "$dir/run_server.sh" "$dir/$bin"
  cat > "$dir/README.txt" <<TXT
Operation: Blackout - Linux $arch dedicated server
Start:   ./run_server.sh --port=7777 --http-port=8080 --data-dir=./server_data
Players: open http://<server-ip>:8080/ to download the Windows client, then JOIN SERVER <server-ip>:7777.
Firewall: allow UDP 7777 (game) and TCP 8080 (download site). Use --no-web to disable the site.
Files in ./downloads/ (.zip/.7z/.gz/.txt) are offered on the site.
TXT
  cp "$DIST/OperationBlackout-Windows.zip" "$dir/downloads/"
  (cd "$ROOT/build" && rm -rf OperationBlackout-Server && cp -r "$dir" OperationBlackout-Server && rm -rf OperationBlackout-Server/server_data \
    && zip -q -9 -r "$DIST/$zipname" OperationBlackout-Server && rm -rf OperationBlackout-Server)
}
build_server "Linux Dedicated Server" linux_server blackout_server.x86_64 x86_64 OperationBlackout-Server-Linux.zip
build_server "Linux Dedicated Server ARM64" linux_server_arm64 blackout_server.arm64 "ARM64 (aarch64: Ampere, Graviton, Raspberry Pi 4/5)" OperationBlackout-Server-Linux-ARM64.zip
ls -la "$DIST"

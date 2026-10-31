# Build & Run Instructions

## Requirements
- Godot **4.3-stable** (standard, non-.NET) — https://godotengine.org/download/archive/4.3-stable/
- Godot 4.3 export templates (Editor → Manage Export Templates, or extract `Godot_v4.3-stable_export_templates.tpz`
  into `~/.local/share/godot/export_templates/4.3.stable/`)
- Python 3 (asset import + test report parsing)

## Build everything
```bash
tools/build.sh
```
Outputs:
- `build/windows/OperationBlackout.exe` + `OperationBlackout.pck` — Windows x86_64 client
- `build/linux_server/blackout_server.x86_64` + `.pck` + `run_server.sh` — Linux x86_64 dedicated server

Packaged downloads (also committed in `dist/`):
- `build/dist/OperationBlackout-Server-Linux.zip`: x86_64 (Intel/AMD) server, `run_server.sh`, and `downloads/OperationBlackout-Windows.zip`
- `build/dist/OperationBlackout-Server-Linux-ARM64.zip`: the same for ARM64 / aarch64 (Ampere, AWS Graviton, Oracle Ampere A1, Raspberry Pi 4/5)
- `build/dist/OperationBlackout-Windows.zip`: the client on its own

## Run the dedicated server + download site (Linux)
```bash
unzip OperationBlackout-Server-Linux.zip && cd OperationBlackout-Server
./run_server.sh --port=7777 --http-port=8080 --data-dir=./server_data
```
Players open `http://<server-ip>:8080/`, download the Windows client, then JOIN SERVER `<server-ip>:7777`.
The site shows live server status (`/status.json`) and serves every `.zip/.7z/.gz/.txt` in `./downloads/`.
Options: `--port`, `--http-port` (default 8080), `--downloads-dir` (default `<exe dir>/downloads`), `--no-web`,
`--data-dir` (profiles + realm id), `--log-file`, `--exit-when-empty`, `--max-idle=<sec>`,
`--allow-test-commands` (never in production), `--verbose`. Open **UDP 7777** and **TCP 8080**.

## Run the client (Windows)
Run `OperationBlackout.exe`. Main menu → **JOIN SERVER** → `host:7777`, or **DEPLOY (SOLO / LOCAL)** which launches a local
headless dedicated server from the same executable and connects to it.
Multiple clients on one PC: `OperationBlackout.exe -- --profile=Second`.

### Pterodactyl panel
Import `deploy/pterodactyl/egg-operation-blackout.json` (Admin → Nests → Import Egg). Or set it up by hand:
1. Server with 1 allocation (game UDP + website TCP on the same number), image `ghcr.io/parkervcp/yolks:debian`.
2. Upload and unarchive the zip that matches the node CPU (ARM64 for Ampere).
3. Startup: `bash OperationBlackout-Server/run_server.sh --port={{SERVER_PORT}} --http-port=same --data-dir=./server_data` (`same` = website on TCP with the game port number; never 8080, which Wings uses)
4. Done text: `dedicated server started`; stop command: `^C`.

## Run from source
```bash
godot --path game                                     # client
godot --headless --path game -- --server --port=7777  # dedicated server
```

## Automated verification
```bash
tools/run_coop_test.sh                                              # source: 1 server + 4 headless clients
tools/run_coop_test.sh build/linux_server/blackout_server.x86_64 build/linux_server/blackout_server.x86_64  # exported build
```
Prints per-bot pass counts; exits non-zero on any failed check. Reports/logs in `build/test/`.

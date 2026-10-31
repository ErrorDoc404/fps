# Technical Architecture

Godot 4.3 · GDScript · ENet. One project (`game/`) produces both the Windows client and the Linux dedicated server;
the role is chosen at boot (`core/Boot.gd`): `--server` or a headless launch → `server/ServerMain.gd`, otherwise → `ui/App.gd`.

## Repository layout
```
SourceFiles/            original Synty asset pack (read-only)
tools/                  import_assets.py, build.sh, run_coop_test.sh
docs/                   all design / status documentation
game/
  autoload/             Log, GameData, Settings, Net, Session (singletons)
  core/                 Boot, Args, Geo (primitive mesh helpers)
  data/                 weapons, classes, equipment, enemies, missions, progression, player rules (JSON)
  server/               ServerMain, ProfileStore (persistence/progression), RateLimiter
  player/               Player, PlayerMotor, PlayerHealth, PlayerInventory,
                        LocalController (input+prediction), FirstPersonRig, RemotePresentation, SoldierModel
  weapons/              ViewModel (first-person weapon/arms builder), EquipmentSystem
  ai/                   Enemy (perception, state machine, navigation, firing, client puppet)
  mission/              MissionDirector (objectives, extraction, failure, results)
  world/                World (scene root for a mission, all world RPCs), IndustrialMap, Fx
  ui/                   UiKit, App, MainMenu, LobbyScreen, SettingsPanel, Hud, Minimap, Compass, PauseMenu, ResultsScreen
  audio/                Sfx (procedural sound generation + 2D/3D playback)
  tests/                AutoTest (headless/rendered scripted client)
```

## Logical systems → modules
| Spec system | Module(s) |
|---|---|
| Game Core | Boot, Args, Log, GameData, Settings |
| Player / Movement / Camera | Player, PlayerMotor, LocalController, FirstPersonRig |
| Combat / Weapons / Inventory | World.c_fire (hitscan), PlayerInventory, ViewModel, EquipmentSystem |
| Classes | data/classes.json (modifiers, equipment, allowed categories) consumed by Player/Session/Director |
| Health | PlayerHealth (armor absorption, downed, bleed-out, elimination) |
| Squad | Session (membership, leader transfer, readiness, kick, chat) |
| Missions / Objectives / Extraction | MissionDirector + data/missions.json |
| AI | Enemy + World AI hooks (alerts, noise, LOS incl. smoke) |
| Networking | Net (transport), Session + World RPCs, snapshot replication |
| UI | ui/* using UiKit + Synty sprites |
| Audio | Sfx |
| Progression / Persistence / Backend | ProfileStore (server-side), Session.finish_mission |

## Player architecture (gameplay vs presentation)
```
Player (CharacterBody3D)            ← gameplay: motor state, health, inventory (server-authoritative)
 ├─ Shape (capsule, resized by stance)
 ├─ Controller   (local client only) ← input, prediction, reconciliation, fire requests
 ├─ Rig          (local client only) ← Camera3D, view model (arms + weapon), sway/bob/recoil/ADS, muzzle flash
 └─ Remote       (other clients only)← SoldierModel third-person body, poses, name tag
```
The server instantiates only the gameplay node; no camera/visual nodes exist on the server.

## Network model
- **Transport**: ENet, default port 7777 (UDP). Max 4 squad members (+2 slots so "squad full" can be reported).
- **Handshake**: peer connects → server sends `s_realm(realm_id)` → client sends `c_hello(version, profile_id, secret, name)`
  → server authenticates via ProfileStore (trust-on-first-use secret, stored client-side per realm; server stores only its SHA-256)
  → `s_welcome`. Unauthenticated peers are dropped after 10 s.
- **Lobby** (`Session`): requests `c_set_class`, `c_set_loadout`, `c_set_ready`, `c_select_mission` (leader), `c_deploy` (leader),
  `c_kick` (leader), `c_chat`; the server validates and broadcasts `s_lobby`.
- **Mission** (`/root/World` on both sides):
  - Client → server: `c_input` every physics tick (unreliable-ordered; seq, move, yaw, pitch, buttons, stance);
    reliable `c_fire(yaw,pitch)`, `c_reload`, `c_switch`, `c_fire_mode`, `c_equipment`.
  - Server → clients: `s_snapshot` at 20 Hz (all players + enemies + extraction progress), reliable events
    (`s_shot`, `s_hit`, `s_damaged`, `s_objectives`, `s_event`, `s_throw/s_detonate/s_smoke`, `s_flashed`), owner-only `s_inventory`.
- **Prediction**: the owning client runs `PlayerMotor.step` with the same input frame it sends; the server simulates every input
  frame exactly once (no extrapolation, drains ≤3/tick). Snapshots carry the last processed `seq`; the client compares with its
  history and applies soft (25%) or hard (>2 m) correction. Measured drift after movement in the test: 0.000 m on LAN.
- **Interpolation**: remote players and enemies render 100 ms in the past between snapshots.
- **Interactions** (revive, objective terminals) are server-driven: holding E sets an input bit; the server finds the target
  (range, facing, objective state), accumulates progress, and completes it. Clients compute the same query only for prompts.

## Server authority & security
Damage (server raycast with server-side spread), ammo, fire rate (`next_fire_time` + token bucket), reload timing, equipment counts
and cooldowns, interaction range/facing, revive, objective completion, extraction, rewards (computed by MissionDirector, granted once
per `session_id` per profile), loadout ownership (unlock level / class category) and session membership are all server-side.
Client input values are sanitised (finite, clamped pitch, normalised move). Chat/lobby/actions are rate-limited.
Test commands (`c_test`) are ignored unless the server is started with `--allow-test-commands`.

## Rooms (multi-squad dedicated server)
One server process hosts many **rooms** (`server/Room.gd`); each room is a squad of 1–4 operators with its own lobby, leader,
optional password (stored as a salted SHA-256), selected operation and mission. Limits: `--max-rooms`, `--max-players` (ENet peers).
- **Browser**: `c_list_rooms(filters)` → `s_room_list(rooms, server_info)`. Filters (CS:GO-style): text search (room or leader),
  operation, not full, has players, no password, not in mission. Sorted by players then name. Joining a full room or using a wrong password
  is rejected with `s_notice`. Empty rooms are closed automatically.
- **Isolation**: on the server each room's World lives in `/root/Rooms/R<id>` = a `SubViewport` with `own_world_3d`, so every mission has
  its own physics space and navigation map. Clients put their World at the same path (`/root/Rooms/R<id>/World`, plain Node holder),
  so RPCs route to the correct room. Every World RPC checks that the sender is a member of *that* room.
- **Server browser (client)**: Favorites and History tabs; each entry is queried over HTTP `/status.json` (name, rooms, players,
  version/protocol) and the round-trip time is shown as ping.

## Session lifecycle (implemented)
1. Client authenticates (realm + secret) → 2. browses rooms and joins or creates one → 3. room leader selects operation →
4. all ready → leader deploys → 5. server builds World, bakes navmesh, spawns players/AI → 6. clients build the same map and
report `c_world_ready` → 7. server streams state → 8. objectives → extraction → 9. MissionDirector computes results →
10. ProfileStore persists XP/credits/history → 11. `s_results` → 12. server returns to lobby (same process, next operation) →
13. `--exit-when-empty` / `--max-idle` shut the server down gracefully.
Matchmaking/allocation: for the MVP a squad connects directly to a server address, or "Deploy (Solo)" spawns a local dedicated
server process. A fleet allocator (e.g. Edgegap/Agones/Hathora) is planned for M7 and only needs to start `run_server.sh` per squad.

## Reconnection
During a mission a disconnecting member's operator stays in the world (flagged disconnected, excluded from extraction/failure
checks). If the same profile reconnects it re-binds to its slot (`Session.disconnected`) and receives a full world sync.

## Data-driven design
Weapons, classes, equipment, enemies, missions/objectives/enemy groups/radio lines, progression curve/rewards and all player tuning
(speeds, stamina, armor absorb, revive times) are JSON in `game/data/`. Adding a weapon or objective requires no code.

## Download website (`server/WebPortal.gd`)
The dedicated server embeds a minimal HTTP/1.1 server (Godot `TCPServer`, non-blocking, ≤32 connections, 30 s idle timeout,
streams files in chunks of up to 1 MB per frame per connection). Routes: `/` (download page with live status and join instructions),
`/status.json`, `/downloads/<name>`. Only GET/HEAD are accepted. A file is served only if its name exactly matches an entry in the
downloads directory listing, so path traversal is not possible. Disable it with `--no-web`.

## Logging & operations
`Log` emits `timestamp LEVEL [tag] message {json}`; `--log-file=` mirrors to a file. The server logs a health line every 30 s
(members, phase, FPS, memory, object count) and handles SIGTERM/close via graceful shutdown that notifies clients.

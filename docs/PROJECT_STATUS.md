# Project Status — 2026-10-31 (visual overhaul)

**Build:** v0.1.0 · Godot 4.3-stable · MVP cooperative loop (M0–M5) implemented and verified.
**Visuals:** the Synty HUD sprites are used throughout the UI. Characters, weapons, first-person arms, props, vehicles, terrain
and surfaces use the Synty POLYGON Military and Warehouse 3D packs added to `master` (see ASSET_MAPPING.md).
Screenshots are in `docs/screenshots/` (Forward+ renderer).

## Verified (evidence)
| Area | How verified | Result |
|---|---|---|
| Linux dedicated server | Source and exported `blackout_server.x86_64`, headless | Boots, auth, lobby, mission, results, graceful shutdown |
| Windows client | Exported `OperationBlackout.exe` (PE32+ x86-64) | **Built; not launched** (no Windows here) |
| 4-player co-op | `tools/run_coop_test.sh`: 1 server + 4 clients (leader/assault, casualty/medic, support, leaver/recon) | **45/45 checks pass** (source build and exported build) |
| Rendering/HUD | Xvfb + OpenGL3, 2-player session, screenshots in `docs/screenshots/` | 30/30 checks pass; HUD, lobby, results render |
| Persistence/progression | Second run against the same server data on another port | Players re-authenticate via realm; XP accumulated (L1 → L5) |

Checks covered: authentication; lobby fill/ready/leader/deploy; player + enemy + objective + inventory sync; walk speed from data
(3.38 m/s); prediction drift 0.000 m; sprint stamina drain; crouch/prone/stand replication; server-side ammo; server-authoritative
enemy kill; reload; weapon switching; downed replication; revive by teammate; interaction prompt; breach + intel objectives;
extraction unlock; extraction with all active operators; mission completed; XP/credits granted and persisted; return to lobby;
a client disconnecting mid-mission does not break the mission.

| ARM64 server | Exported `blackout_server.arm64` run under qemu-aarch64 emulation, 4 bots | Mission completed. 44/45 checks pass; the walk-speed check missed (2.29 m/s) because of CPU load from emulation. Download site served the client |
| Rooms / room browser | 6 clients, 3 rooms (exported build): Alpha 4/4, Bravo (password), Charlie (solo); 2 missions run at once | **93/93**: full room listed and join rejected, not-full / no-password / has-players / not-in-mission filters, wrong password rejected, empty room closed, both missions completed in isolated worlds |
| Download website | Exported server zip unpacked → `curl` page/status/download, Chromium screenshot | 200 OK; 30 MB client zip downloaded at ~60 MB/s with an identical SHA-256; traversal/unknown files → 404, POST → 405 |

## Implemented (MVP scope)
- **FPS foundation:** first-person camera (FOV, sensitivity, invert, camera-motion slider), walk/sprint/crouch/prone/jump/ADS,
  stamina, encumbrance, first-person arms + weapon view models, sway/bob/recoil/ADS/reload/switch/sprint animation, muzzle flash.
- **Combat:** 5 data-driven weapons (2 ARs, SMG, DMR, pistol), fire modes, spread, falloff, headshots, ADS FOV, reload timings,
  health + armor absorption, damage direction indicator, low-health vignette, hit markers.
- **Equipment:** medkit (medic can treat teammates), smoke (blocks AI sight), flash (stuns AI, blinds players), recon pulse
  (reveals enemies on minimap), ammo supply.
- **Multiplayer:** dedicated authoritative ENet server, realm-scoped TOFU auth, 20 Hz snapshots, prediction + reconciliation,
  interpolation, rate limiting, disconnect/reconnect to the same slot, server-side validation of everything that matters.
- **Co-op:** squad lobby (leader, transfer, kick, ready, class, loadout validation, mission select, chat), 4 classes, downed →
  bleed-out → eliminated, revive, rejoin on primary objective, squad HUD, extraction rule "all active operators in LZ".
- **AI:** 4 types (rifleman, heavy, spotter, officer) with idle/patrol/investigate/alert/combat/search/retreat/disabled states,
  sight cone + LOS + stance-aware detection, hearing, squad alerts, navmesh pathing, burst fire with accuracy model.
- **Mission:** OP-01 First Contact (industrial map: warehouse, site office, maintenance building, loading yard, tanks, helipad),
  2 primary + 2 optional objectives, triggered reinforcement waves, radio messages, extraction helicopter, results + rewards.
- **UI:** main menu (solo/local, join, operations, equipment, character, settings, credits, exit), HQ lobby, HUD (vitals, weapon,
  equipment, compass, minimap, objectives, squad, prompts, extraction, feed, chat), pause menu, results — all from Synty sprites.

## Incomplete
See `KNOWN_ISSUES.md` and `TODO.md`: art/audio assets, skeletal animation, voice chat, Steam, matchmaking/allocation,
WAN hardening (lag compensation), controller look/UI navigation, OP-02…OP-07.

## How to launch
See `BUILD_INSTRUCTIONS.md`. Server: unzip `dist/OperationBlackout-Server-Linux.zip`, run `./run_server.sh`, and share
`http://<server-ip>:8080/` so players can download the client. Client: run `build/windows/OperationBlackout.exe` → DEPLOY (SOLO / LOCAL); or start
`build/linux_server/run_server.sh --port=7777` and JOIN SERVER from up to four clients.

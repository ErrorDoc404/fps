# Known Issues & Limitations

## Content / presentation
- **No 3D art or audio was supplied.** Environments, operators, enemies, weapons and arms are graybox primitives built in code;
  sounds are procedurally synthesised. Animations are procedural poses (no skeletal rigs).
- First-person arms are simple blocks; reload is a procedural dip + magazine drop.
- The `.unitypackage` named in the spec is not in the repository (only the source sprites are), so no Synty Unity prefabs/layouts were used.

## Networking
- Verified on localhost/LAN only. WAN latency, jitter and packet loss have not been tested; reconciliation uses position-only
  correction (velocity not reconciled).
- No lag compensation for hitscan: the server raycasts against current (not rewound) enemy positions. Fine at LAN latency,
  will under-register at high ping against moving targets.
- Remote players in mid-air freeze briefly if their input stream stalls (the server never extrapolates inputs).
- Authentication is trust-on-first-use per server realm; there is no platform (Steam) identity yet. Losing the local
  `user://auth_*.cfg` file locks the player out of that server's profile.
- No matchmaking/allocation service: squads connect to a server address or use the local solo server.
- Voice chat is not implemented (text squad chat only). Mute controls not yet implemented.

## Gameplay
- AI has no cover selection or flanking; it engages from its position or advances (heavy) and retreats once at low health.
- Navigation mesh is baked at mission start on the server (~1 s for OP-01).
- Controller: actions are bound to gamepad buttons/axes, but right-stick look and UI focus navigation are not implemented.
- `kill_all_enemies` used by tests credits kills to the test player (test-only command, disabled by default).
- Only OP-01 is playable; OP-02…07 are listed but locked.

## Download website
- Plain HTTP (no TLS). Put it behind a reverse proxy (nginx/Caddy) for HTTPS on public hosts.
- No download resume (Range requests) or bandwidth limiting.
- `dist/` zips are committed to git (~85 MB). Move them to GitHub Releases or object storage once the repo is used long-term.

## Engine / tooling
- Headless clients print `Parameter "m" is null` from Godot's dummy renderer (mesh queries with no GPU). Not present with a real renderer.
- Windows build is cross-exported from Linux and has **not been launched on Windows** in this environment (no Windows/Wine available).
- Rendered verification ran with Mesa llvmpipe (OpenGL 3 compatibility renderer) under Xvfb at low frame rates; the Forward+ (Vulkan)
  renderer has not been visually verified here.
- Input is sampled once per client physics tick. On machines that cannot hold 60 FPS (e.g. the llvmpipe test renderer at ~5 FPS),
  Godot caps catch-up physics steps per frame, so the client sends fewer input frames and moves slower than real time
  (measured 1.6 m/s instead of 3.4 m/s under llvmpipe; 3.38 m/s at full rate). Planned fix: time-stamped inputs with variable dt.
- When a client disconnects abruptly, the server may log `Unable to send packet on channel 0` for a few reliable RPCs sent
  in the window before ENet reports the disconnect. Harmless.

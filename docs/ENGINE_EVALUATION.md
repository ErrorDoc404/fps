# Engine Evaluation

## Decision: **Godot 4.3 (stable)**, GDScript, built-in ENet high-level multiplayer

## Candidates

| Criterion | Unreal Engine 5 | Godot 4.3 | Unity 2022 LTS | Custom (e.g. Bevy / raylib + ENet) |
|---|---|---|---|---|
| FPS capabilities | Best in class (Lyra, CMC, GAS) | Good: CharacterBody3D, raycasts, physics layers | Very good | Must be built |
| Rendering quality | Highest (Nanite/Lumen) | Good (Forward+, SSAO, glow, volumetric fog) | Very good (URP/HDRP) | Low without major work |
| Character controller | CharacterMovementComponent w/ prediction | CharacterBody3D (move_and_slide); prediction written by us | CharacterController; prediction via Netcode/3rd party | From scratch |
| Animation | Excellent | Good (AnimationTree) | Excellent | Minimal |
| Dedicated server | Yes, needs **source build** of the engine for server targets | Yes: same binary runs `--headless`; export templates included | Yes (Dedicated Server build target) | Yes |
| Linux server deploy | Yes (source build + cross toolchain) | Yes, official Linux x86_64 templates | Yes | Yes |
| Multiplayer | Replication graph, mature | ENet + RPC + MultiplayerSynchronizer; prediction is DIY | Netcode for GameObjects / Mirror / FishNet | DIY |
| Asset import / UI | UMG; PNG import fine | PNG import automatic; Control nodes + StyleBoxTexture fit tinted sprite kits well | uGUI; the Synty Unity package would map directly | DIY |
| Performance | Heavy client, very scalable | Light; adequate for 4-player co-op + ~20 AI | Good | Depends |
| Development complexity | High (C++, long compiles, 100+ GB toolchain) | Low; text-based scenes/scripts, seconds to run | Medium | Very high |
| Build automation | UAT/BuildGraph; heavy | `godot --headless --export-release` (single 50 MB binary) | Unity CLI needs licence activation | Cargo/CMake |
| Long-term maintenance | Strong vendor | MIT licence, active, no royalties | Licence/pricing risk | All on us |
| **Runs in this CI/dev container** | No (no engine, ~100 GB, no GPU) | **Yes — downloaded, builds and runs** | **No — download hosts blocked (HTTP 403), licence activation required** | Yes, but slow to reach quality |

## Reasoning
1. **Verifiability.** The spec requires milestones to be *built, launched and verified*. Godot is the only full engine that can be
   downloaded, imported, run headless, rendered under Xvfb, and exported to Windows + Linux inside this environment. Unity's
   download hosts are blocked by the network policy and it requires licence activation; UE5 requires a source build for
   dedicated servers and far more disk/GPU than available.
2. **Dedicated server**: one codebase/binary; `--headless -- --server` gives an authoritative Linux server with no rendering.
3. **Code-first**: scenes, UI and levels are built in GDScript, so every system is reviewable text with no editor-only state.
4. **Asset fit**: the supplied Synty source sprites are white tintable PNGs, which map directly onto `StyleBoxTexture`,
   `TextureRect` and `TextureProgressBar` with `modulate`/`tint`.
5. Licence: MIT, no royalties, Steam-compatible (GodotSteam is the planned integration).

## Networking decision
Built-in **ENet** (`ENetMultiplayerPeer`) + RPCs. Custom snapshot replication (20 Hz) with client-side prediction and
reconciliation for the local player, interpolation (100 ms buffer) for remote entities, reliable RPCs for discrete actions.
`MultiplayerSynchronizer` was not used: explicit snapshots give control over bandwidth and authority.

## Limitations / risks
- Rendering ceiling below UE5 (acceptable for the stylised tactical look of the supplied HUD kit).
- No built-in network prediction framework: implemented in `PlayerMotor` + `LocalController` (documented in TECHNICAL_ARCHITECTURE.md).
- No 3D character/environment assets were supplied: graybox geometry and procedural soldier models are used.
- Steam integration needs the GodotSteam GDExtension (M7).

## Dependencies
- Godot 4.3-stable editor binary + 4.3 export templates (Windows x86_64, Linux x86_64).
- Python 3 (asset import script, test report parsing). Xvfb only for rendered screenshot tests.

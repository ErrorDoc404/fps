# Asset Compatibility

| Package | Present? | Usable in Godot? | Notes |
|---|---|---|---|
| `INTERFACE_Military_Combat_HUD_Source_Sprites_v2` (extracted into `SourceFiles/`) | **Yes** (2,127 PNG + 3 TTF + OFL.txt) | **Yes** | Engine-independent PNGs import natively. Primary UI source. |
| `INTERFACE_Military_Combat_HUD_Unity_2022_3_v1_0_3.unitypackage` | **No** — not in the repository | n/a | Unity prefabs, `.meta`, animation clips and layouts are therefore unavailable. Even if supplied, prefabs/animators are Unity-specific and would not import; only its textures would be reusable (already covered by the source sprites). |

## Format findings
- All sprites are RGBA PNG, mostly **white on transparent** (`_Clean`) with `_Underlay` drop-shadow layers and `_Stroke`
  outline variants → designed to be tinted at runtime. Godot `modulate`, `tint_progress` and `StyleBoxTexture.modulate_color` are used.
- Weapon icons are 2048×1024 (`_Clean`, `_Side`, `_Underlay`) plus 1024×1024 previews: displayed scaled with `STRETCH_KEEP_ASPECT_CENTERED`.
- Fonts: Oxanium Light/Medium/Bold TTF (SIL OFL) — imported as Godot `FontFile`.
- `Samples/` are reference screenshots/portraits from the vendor; used only for visual reference, not shipped.
- No animation assets (sprite sheets, Lottie, Unity clips) exist → HUD animation done in code (tweens, progress fills, rotation).
- No 3D models, no audio. Gameplay visuals are graybox primitives; audio is procedurally generated (`audio/Sfx.gd`).

## Preservation
- `SourceFiles/` is never modified. `tools/import_assets.py` copies only referenced files into
  `game/assets/ui/synty/<same relative path>` and writes `MANIFEST.txt`. Filenames are preserved.
- Licence: Synty Store EULA — the sprites may be used in the shipped game but must not be redistributed as a standalone asset pack.
  Keep the repository private or exclude `SourceFiles/` from any public mirror.

# Asset Mapping

Imported path = `game/assets/ui/synty/<Rel>`; source = `SourceFiles/Sprites/<Rel>` (or `SourceFiles/<Rel>` for `Core/` and `Fonts/`).
Constants live in `game/ui/UiKit.gd`; data-driven icons in `game/data/*.json`. Full copied list: `game/assets/ui/synty/MANIFEST.txt`.

| Game element | Sprite (Rel) | Usage |
|---|---|---|
| Buttons, line edits | `HUD/SPR_HUD_MilitaryCombat_Background_Octagon_02_Clean.png` | 9-slice `StyleBoxTexture`, tinted per state |
| Panels | `HUD/SPR_HUD_MilitaryCombat_Background_DogEar_01.png` | 9-slice panel background |
| Section headers | `HUD/SPR_HUD_MilitaryCombat_Header_Trapezoid_01_Clean.png` | accent bar |
| Health / armor / stamina / XP / extraction bars | `HUD/SPR_HUD_MilitaryCombat_Bar_Angled_01_Clean.png` | `TextureProgressBar` under + fill |
| Vitals + weapon panels | `HUD/SPR_HUD_MilitaryCombat_Background_Angled_03_Gradient.png` | backdrop |
| Objective panel, compass bg | `HUD/SPR_HUD_MilitaryCombat_Gradient_Horizontal_01.png` | backdrop |
| Low-health vignette, menu vignette | `HUD/SPR_HUD_MilitaryCombat_Vignette_Background_01.png` | red-tinted overlay |
| Crosshair | `HUD/SPR_HUD_MilitaryCombat_Reticle_Crosshair_Medium_01.png` | hip-fire reticle |
| Hit marker | `HUD/SPR_HUD_MilitaryCombat_Reticle_Bracket_Small_01.png` | white / amber (headshot) / red (kill) |
| Interaction / medkit progress | `HUD/SPR_HUD_MilitaryCombat_LoadingIcon_01_Ring_Clean.png` | radial `TextureProgressBar` |
| Interaction key cap | `Core/Icons_Input/MouseKeyboard/ICON_Input_PC_Button_Clean.png` | with "E" label |
| Compass ticks | `HUD/SPR_HUD_MilitaryCombat_Compass_Bar_01_Clean.png` | drawn per 15° |
| Minimap frame | `HUD/SPR_HUD_MilitaryCombat_Ring_Medium_01_Clean.png` | ring overlay |
| Minimap player arrow | `HUD/SPR_HUD_MilitaryCombat_Map_Player_01_Clean.png` | |
| Minimap squad / enemy dots | `HUD/SPR_HUD_MilitaryCombat_Map_Circle_Small_01_Clean.png` | blue squad, red revealed enemy |
| Objective list states | `HUD/SPR_HUD_MilitaryCombat_Objective_Active_01_Clean.png`, `..._Inactive_01_Clean.png` | |
| World-space objective marker | `HUD/SPR_HUD_MilitaryCombat_Worldspace_Objective_01_Clean.png` | projected with distance |
| Objective on map/compass | `Icons_Map/ICON_MilitaryCombat_Map_Objective_01_Clean.png` | |
| Extraction | `Icons_Map/ICON_MilitaryCombat_Map_Helicopter_01_Clean.png` | banner, compass, minimap |
| Locked operation | `Icons_Map/ICON_MilitaryCombat_Map_Lock_01_Clean.png` | |
| Damage direction | `FX/SPR_FX_MilitaryCombat_DamageDirection_01_Main.png` | rotated toward attacker |
| Menu scanlines | `FX/SPR_FX_MilitaryCombat_Comms_Scanlines_Medium_01.png` | tiled, 5% alpha |
| Menu greeble | `HUD/SPR_HUD_MilitaryCombat_Greeble_TechyWriting_01.png` | |
| Lobby hazard strip | `HUD/SPR_HUD_MilitaryCombat_Background_HazardStripes_01.png` | |
| Health / armor / downed / dead | `Icons_Status/ICON_MilitaryCombat_Status_{Health_01,Armour_01,Down_01,Dead_01}_Clean.png` | HUD + squad list |
| Stamina | `Icons_Stats/ICON_MilitaryCombat_Stat_Speed_01_Clean.png` | |
| XP / credits / trophy | `Icons_Status/..._XP_01_Clean.png`, `Icons_Inventory/..._Currency_02_Clean.png`, `..._Trophy_01_Clean.png` | lobby + results |
| Weapons (data) | `Icons_Weapons/ICON_SM_Wep_{Rifle_Assault_01_BattleRoyale, Preset_A_Rifle_01_Military, SubMGun_01_BattleRoyale, Sniper_Lite_01_BattleRoyale, Pistol_01_Military}_Clean.png` | `weapons.json` `icon` |
| Equipment (data) | `Icons_Inventory/..._Healing_01`, `..._GrenadeSmoke_01`, `..._GrenadeFlashbang_01`, `..._Ammo_Bullets_01`, `Icons_Special/..._Drone_01` (`_Clean`) | `equipment.json` |
| Classes (data) | rifle / healing / drone / ammo icons above | `classes.json` |
| Fonts | `Fonts/Oxanium/Oxanium-Medium.ttf`, `Oxanium-Bold.ttf` (+ `OFL.txt`) | theme default + headings |

Unused but suitable for later: `Badges/` (squad insignias, titles), `Icons_WeaponMods/` (customisation), `Icons_Input/*` (controller prompts),
`HUD/..._Reticle_Sniper_*` + `..._Vignette_Scope01` (scope overlay), `HUD/..._WeaponWheel_*`.

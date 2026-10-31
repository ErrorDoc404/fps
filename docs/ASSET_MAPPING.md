# Asset Mapping

Imported path = `game/assets/ui/synty/<Rel>`. The source is `SourceFiles/Sprites/<Rel>`, or `SourceFiles/<Rel>` for
`Core/`, `Fonts/` and `Samples/`. `tools/import_assets.py` scans the code and data for referenced paths and copies only those
files, byte-identical. The one exception is the 5040×2160 sample screenshots, which are saved as 1920 px wide converted copies.
The full list is in `game/assets/ui/synty/MANIFEST.txt` (110 files).
Sprite constants live in `game/ui/UiKit.gd`; data-driven icons and renders live in `game/data/*.json`.

## What the supplied pack actually contains (audit)
| Folder | Files | Actual content (inspected visually) | Classification |
|---|---|---|---|
| `Sprites/HUD` | 196 | White tintable HUD shapes: bars, frames, reticles, compass, map markers, objectives, vignettes, loading icons | 2D UI |
| `Sprites/MilitaryCombat` | 110 | Textured metal UI frames, boxes, bars, dials, sockets, greebles | 2D UI (textured) |
| `Sprites/Icons_Weapons` | 216 | Weapon icons: white `_Clean`/`_Underlay`, plus **full-colour renders** and `_Side` renders of Synty weapon models | 2D renders |
| `Sprites/Icons_Resources` | 192 | **Full-colour renders** of Synty props and kit: helmets, pouches, ammo boxes, medical box, laptop, grenades, radios | 2D renders |
| `Sprites/Icons_Inventory`, `Icons_Status`, `Icons_Stats`, `Icons_Map`, `Icons_Special` | 348 | White icon sets (clean / stroke / underlay) | 2D UI |
| `Sprites/Icons_WeaponMods` | 149 | Weapon attachment/mod icons | 2D UI |
| `Sprites/Badges` | 376 | Rank chevrons, rank insignia (bronze/silver/gold), shields, wings, emblem elements (skulls, stars, crates, rifles) | 2D UI |
| `Sprites/FX` | 19 | Blood splats, broken glass, glows, damage direction, scanlines, static | 2D FX |
| `Sprites/Cursors` | 3 | Pointer + crosshair cursors | 2D UI |
| `Core/Icons_Input` | 497 | Keyboard/mouse, Xbox, PlayStation, Switch, Steam Deck, generic pad prompts | 2D UI |
| `Core/Icons_Social`, `Core/Branding` | 10 | Social icons, Synty branding (not used: vendor branding) | 2D UI |
| `Samples` | 11 | 4 operator portraits, 5 gameplay screenshots, 1 top-down map, 1 branding | 2D reference art |
| `Fonts/Oxanium` | 3 + licence | Oxanium Light / Medium / Bold (SIL OFL) | Font |
| **3D models / environment textures / audio** | **0** | None supplied (no `.fbx/.glb/.obj`, no material textures, no `.wav/.ogg`); the `.unitypackage` is absent | — |

## UI integration
| Game element | Supplied asset(s) | How it is used |
|---|---|---|
| Panels (all menus, HUD cards, popups) | `MilitaryCombat/..._Box_Medium_03.png` | 9-slice `StyleBoxTexture` (margins 46 px) |
| Buttons | `MilitaryCombat/..._Bar_Small_01.png` | 9-slice, tinted per state (normal, hover, pressed, disabled) |
| Text fields, dropdowns, tooltips, scrollbar tracks | `MilitaryCombat/..._Box_Small_02.png` | 9-slice inset, tinted dark |
| Focus outline | `HUD/..._Frame_DogEar_02_Thin.png` | 9-slice, accent tint |
| Check boxes, filter toggles | `HUD/..._Objective_Active_01_Clean.png`, `..._Objective_Inactive_01_Clean.png` | Theme icons (resized, tinted) |
| Slider grabber and track, dropdown arrow | `HUD/..._Map_Circle_Small_01_Clean.png`, `..._Bar_Angled_01_Clean.png`, `..._Arrow_01_Clean.png` | Theme icons and styleboxes |
| Menu backdrops | `Samples/..._ExampleScreenshot_{FirstPerson,3rdPerson,Survival,LooterShooter,Downed}.png` | Main menu / deployment, lobby, browsers, results (complete/failed); darkened, with vignette and scanlines |
| Top rail on main menu | `MilitaryCombat/..._Bar_Large_01.png` | Stretched strip |
| Menu decoration | `HUD/..._Greeble_TechyWriting_01.png`, `HUD/..._Background_HazardStripes_01.png`, `FX/..._Comms_Scanlines_Medium_01.png`, `HUD/..._Vignette_Background_01.png` | Overlays |
| Task Force emblem | `Badges/..._Badge_Wings_02_Gold.png` | Main menu |
| Class portraits (lobby cards, roster, squad HUD, results) | `Samples/..._Example_CharacterPortrait_01..04.png` | Assault=02, Medic=01, Recon=03, Support=04, inside `MilitaryCombat/..._Frame_Medium_12.png` |
| Player rank (lobby roster, results) | `Badges/..._Badge_Element_Rank_01..10_{Bronze,Silver,Gold}.png` | Level 1–3 bronze, 4–6 silver, 7+ gold |
| Class icons | rifle / healing / drone / ammo icons (`classes.json`) | Class buttons |
| Weapon cards (loadout, armory, unlock) | `Icons_Weapons/ICON_SM_Wep_*` full-colour renders (`weapons.json` `render`) | Button icons and textures |
| Weapon on HUD | `Icons_Weapons/*_Clean.png` (`weapons.json` `icon`) | White HUD style |
| Equipment sockets (HUD, loadout) | `MilitaryCombat/..._Socket_Frame_01.png`, `..._Socket_Background_01.png` + `Icons_Resources` renders: MedicalBox_02, Grenade_Smoke_01, Flashbang_01, Radio_01, AmmoBox_04 (`equipment.json` `render`) | Hex sockets with count and key |
| Health / armour / stamina / XP / extraction bars | `HUD/..._Bar_Angled_01_Clean.png` | `TextureProgressBar` |
| Vitals and weapon panels | `HUD/..._Background_Angled_03_Gradient.png` | Backdrop |
| Objectives panel, compass backing | `HUD/..._Gradient_Horizontal_01.png` | Backdrop |
| Crosshair, hit marker | `HUD/..._Reticle_Crosshair_Medium_01.png`, `..._Reticle_Bracket_Small_01.png` | |
| DMR scope | `HUD/..._Vignette_Scope01.png`, `..._Reticle_Sniper_Ring_01.png`, `..._Reticle_Sniper_Crosshair_01.png` | Full-screen overlay while aiming the Longbow (view model hidden) |
| Interaction ring, key cap | `HUD/..._LoadingIcon_01_Ring_Clean.png`, `Core/Icons_Input/MouseKeyboard/ICON_Input_PC_Button_Clean.png` | |
| Deploy loading spinner | `HUD/..._LoadingIcon_01_Arrows_Clean.png` | Rotating |
| Compass ticks | `HUD/..._Compass_Bar_01_Clean.png` | |
| Minimap bezel, player arrow, dots | `MilitaryCombat/..._Dial_Large_01.png`, `HUD/..._Map_Player_01_Clean.png`, `..._Map_Circle_Small_01_Clean.png` | |
| Objective markers | `HUD/..._Worldspace_Objective_01_Clean.png`, `Icons_Map/..._Map_Objective_01_Clean.png`, `..._Map_Helicopter_01_Clean.png`, `..._Map_Lock_01_Clean.png` | World, compass and minimap markers; locked operations |
| Status icons | `Icons_Status/..._{Health,Armour,Down,Dead,XP}_01_Clean.png`, `Icons_Stats/..._Speed_01_Clean.png`, `Icons_Inventory/..._{Currency_02,Trophy_01}_Clean.png` | |
| Damage direction | `FX/..._DamageDirection_01_Main.png` | Rotated toward the attacker |
| Mouse cursor | `Cursors/SPR_MouseCursor_MilitaryCombat_Pointer_01.png` | `Input.set_custom_mouse_cursor` |
| Font | `Fonts/Oxanium/Oxanium-Medium.ttf`, `Oxanium-Bold.ttf` | Theme default and headings |

## Supplied sprites used inside the 3D world (client only)
| Use | Asset | Node |
|---|---|---|
| Dominion banners, chest insignia, painted emblem | `Badges/..._Badge_Element_SnakeSkull_01_Silver.png` | `Sprite3D` on banners and enemy vests, `Decal` on a container |
| Task Force class patches on operators' shoulders | `Badges/..._Element_Rifles_01/Target_01/Crate_01_Silver.png`, `Icons_Resources/..._Patch_Medic_02_BattleRoyale.png` | `Sprite3D` |
| Helicopter roundel | `Badges/..._Badge_Element_Star_01_Silver.png` | `Sprite3D` |
| Floor hazard markings | `HUD/..._Background_HazardStripes_01.png` | `Decal` (tinted yellow) |
| Oil stains / grime | `FX/..._BloodSplats_01/02.png` | `Decal` (tinted dark brown) |
| Broken glass under the office window | `FX/..._BrokenGlass_01.png` | `Decal` |
| Signage (danger, power, site office, LZ) | `Icons_Map/..._{Danger,Lightning,Home,Helicopter}_01_Clean.png` | `Sprite3D` on sign boards |
| Intel laptop screen | `HUD/..._Greeble_TechyWriting_01.png` | `Sprite3D`, unshaded |
| Site office wall map | `Samples/..._Example_Map_01.png` | `Sprite3D` |
| Muzzle flash | `FX/..._Glow_01.png` | Additive billboard |

## Procedural replacements (no matching supplied asset exists)
| Need | Implementation | File |
|---|---|---|
| Environment architecture, props, vehicles | Chamfered low-poly meshes in the Synty POLYGON style | `world/IndustrialMap.gd`, `world/Props.gd`, `core/Geo.gd` |
| Surface textures (concrete, asphalt, ground, painted and corrugated metal, rust, wood, fabric, polymer, gunmetal, camo) | Noise-generated albedo detail + normal maps, triplanar PBR | `world/Mat.gd` |
| Operators and Dominion units | Procedural characters: camo uniforms, plate carriers, pouches, helmets / hood / beret, knee pads, backpacks | `player/SoldierModel.gd` |
| Weapons (first and third person) | Detailed procedural models whose silhouettes follow the supplied `Icons_Weapons/*_Side.png` renders | `weapons/WeaponModel.gd`, `weapons/ViewModel.gd` |
| Extraction helicopter | Procedural utility helicopter | `world/Fx.gd` |
| Audio | Procedurally synthesised | `audio/Sfx.gd` |

Available but not yet used: `Icons_WeaponMods/` (attachments UI), controller prompt sets in `Core/Icons_Input/*`
(for when controller UI navigation is added), additional `Badges/` shields and wings (titles and insignias), and
`HUD/..._WeaponWheel_*`.

## Synty POLYGON 3D packs (added on `master` in commit bf37cb0)
Source paths: `PM/` = `assets/POLYGON_Military_SourceFiles_v4/SourceFiles/`, `PW/` = `assets/POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles/`.
`tools/import_assets.py` copies only the referenced files into `game/assets/polygon/` (88 files, ~10 MB). The 4096 px atlases are
saved as 2048 px converted copies; full list in `game/assets/polygon/MANIFEST.txt`. The FBX files reference missing `.psd` textures,
so `core/Poly.gd` assigns the matching PNG atlas from `MaterialList_PolygonMilitary.txt`.

| Game element | Synty asset | Notes |
|---|---|---|
| Task Force operators | `PM/Chr/SK_Chr_Soldier_Male_01` (Assault), `Soldier_Female_01` (Medic), `Ghillie_Male_01` (Recon), `Soldier_Male_02` (Support), atlas `Texture_01_A` | Helmets, goggles and headset from `SM_Chr_Attach_*` attached to the `head` bone |
| Dominion units | `Insurgent_Male_01` + `Helmet_02` (Rifleman), `Soldier_Male_02` + `Helmet_10`/`Visor` on `Texture_02_A` (Heavy), `Ghillie_Male_01` on `Texture_02_A` (Spotter), `Leader_Male_01` + `Hair_Male_02` (Officer) | |
| First-person arms | Same operator model as the player's class; chest, head and legs collapsed by bone scale | Two-bone IK onto the weapon grip and handguard, true arm length |
| Weapons | VK-7 = `SM_Wep_Preset_B_Rifle_01`, RK-12 = `Preset_A_Rifle_01`, Kestrel = `Preset_A_SMG_01`, Longbow = `Preset_A_Sniper_01`, P9 = `SM_Wep_Pistol_01` (+ Mag / Sight / Sight_Glass / Charge / Slide / Trigger parts), atlas `Weapons_01` (`Weapons_04` for the Longbow) | Sights mounted on the rail; magazine on its own node for reload animation |
| Containers | `PW/FBX/SM_Prop_Shipping_Container_01` | fitted to the existing colliders |
| Jersey barriers / HESCO | `SM_Prop_Barrier_01`, `SM_Prop_Barrier_Base_Row_01` | |
| Trucks | `SM_Veh_Truck_01` (atlas `Land_Vehicles_05`) | |
| Crates, barrels, pallets, sacks, tyres, wire spool | `SM_Prop_Crate_Cube_01`, `Crate_Wood_01`, `Barrel_01`, `Pallet_01`, `Sack_Large_01`, `Tire_01`, `WireSpool_01` | |
| Light poles, generator, guard tower, water tanks, fences, razor wire, satellite dish | `SM_Prop_LightPole_01`, `Generator_Large_01`, `SM_Bld_GuardTower_01`, `WaterTank_01`, `Fence_01`, `RazorWire_01`, `Satellite_Dish_01` | |
| Office | `SM_Prop_Desk_01`, `Chair_01`, `Lockers_01`, `Gunrack_01`, `PW/.../SM_Prop_Mission_Board_01` | |
| Scrap / debris | `SM_Prop_Vehicle_Debris_01`, `Rubble_Pile_01` | |
| Helipad, extraction helicopter | `SM_Env_Helipad_01`, `SM_Veh_Helicopter_Transport_01` (atlas `Veh_Heli_01_A`) | |
| Horizon, outskirts | `SM_Env_Mountain_01–03`, `SM_Env_Rock_01/02`, `SM_Env_Bush_Small_01` | |
| Signage, AC | `PW/.../SM_Prop_Danger_Sign_01`, `SM_Prop_Airconditioner_01` | |
| Wall, ground and road surfaces | `PW/Textures/Corrigated_Iron_01_Tan` + `_Normals` (warehouse), `Brick_Large_01` + `_Normals` (maintenance), `Dirt_Dry_01` (ground), `PM/Textures/Road_Texture` (apron/road) | triplanar tiled (`Mat.tiled`) |

Still procedural (no matching model in the packs): forklift, warehouse rack frames, storage tanks, server rack, intel laptop
(with a supplied HUD sprite screen), warehouse shell walls (with Synty textures).

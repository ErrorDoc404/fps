class_name UiKit
## Shared UI toolkit: Synty Military Combat HUD sprites (tinted white sprites), Oxanium font, theme and widgets.
## Sprite paths are relative to res://assets/ui/synty/ which mirrors the original SourceFiles/ layout.

const ROOT := "res://assets/ui/synty/"
const BG := Color(0.05, 0.06, 0.05, 0.88)
const PANEL := Color(0.09, 0.1, 0.09, 0.92)
const ACCENT := Color(0.96, 0.73, 0.26)
const TEXT := Color(0.9, 0.92, 0.86)
const DIM := Color(0.6, 0.63, 0.58)
const OK := Color(0.47, 0.86, 0.42)
const BAD := Color(0.92, 0.32, 0.26)
const ARMOR := Color(0.42, 0.7, 0.95)

# Sprite map (see docs/ASSET_MAPPING.md)
const SPR_BUTTON := "HUD/SPR_HUD_MilitaryCombat_Background_Octagon_02_Clean.png"
const SPR_PANEL := "HUD/SPR_HUD_MilitaryCombat_Background_DogEar_01.png"
const SPR_PANEL_FRAME := "HUD/SPR_HUD_MilitaryCombat_Frame_DogEar_02_Thin.png"
const SPR_HEADER := "HUD/SPR_HUD_MilitaryCombat_Header_Trapezoid_01_Clean.png"
const SPR_BAR := "HUD/SPR_HUD_MilitaryCombat_Bar_Angled_01_Clean.png"
const SPR_BAR_GRAD := "HUD/SPR_HUD_MilitaryCombat_Bar_Angled_01_Gradient.png"
const SPR_ANGLED_BG := "HUD/SPR_HUD_MilitaryCombat_Background_Angled_03_Gradient.png"
const SPR_GRAD_H := "HUD/SPR_HUD_MilitaryCombat_Gradient_Horizontal_01.png"
const SPR_VIGNETTE := "HUD/SPR_HUD_MilitaryCombat_Vignette_Background_01.png"
const SPR_CROSSHAIR := "HUD/SPR_HUD_MilitaryCombat_Reticle_Crosshair_Medium_01.png"
const SPR_DOT := "HUD/SPR_HUD_MilitaryCombat_Reticle_Dot_Small_01.png"
const SPR_HITMARK := "HUD/SPR_HUD_MilitaryCombat_Reticle_Bracket_Small_01.png"
const SPR_RING := "HUD/SPR_HUD_MilitaryCombat_LoadingIcon_01_Ring_Clean.png"
const SPR_COMPASS_TICK := "HUD/SPR_HUD_MilitaryCombat_Compass_Bar_01_Clean.png"
const SPR_MAP_PLAYER := "HUD/SPR_HUD_MilitaryCombat_Map_Player_01_Clean.png"
const SPR_MAP_DOT := "HUD/SPR_HUD_MilitaryCombat_Map_Circle_Small_01_Clean.png"
const SPR_MAP_RING := "HUD/SPR_HUD_MilitaryCombat_Ring_Medium_01_Clean.png"
const SPR_OBJ_ACTIVE := "HUD/SPR_HUD_MilitaryCombat_Objective_Active_01_Clean.png"
const SPR_OBJ_INACTIVE := "HUD/SPR_HUD_MilitaryCombat_Objective_Inactive_01_Clean.png"
const SPR_OBJ_WORLD := "HUD/SPR_HUD_MilitaryCombat_Worldspace_Objective_01_Clean.png"
const SPR_DAMAGE_DIR := "FX/SPR_FX_MilitaryCombat_DamageDirection_01_Main.png"
const SPR_SCANLINES := "FX/SPR_FX_MilitaryCombat_Comms_Scanlines_Medium_01.png"
const SPR_TECHY := "HUD/SPR_HUD_MilitaryCombat_Greeble_TechyWriting_01.png"
const SPR_HAZARD := "HUD/SPR_HUD_MilitaryCombat_Background_HazardStripes_01.png"
const ICON_HEALTH := "Icons_Status/ICON_MilitaryCombat_Status_Health_01_Clean.png"
const ICON_ARMOR := "Icons_Status/ICON_MilitaryCombat_Status_Armour_01_Clean.png"
const ICON_DOWN := "Icons_Status/ICON_MilitaryCombat_Status_Down_01_Clean.png"
const ICON_DEAD := "Icons_Status/ICON_MilitaryCombat_Status_Dead_01_Clean.png"
const ICON_STAMINA := "Icons_Stats/ICON_MilitaryCombat_Stat_Speed_01_Clean.png"
const ICON_XP := "Icons_Status/ICON_MilitaryCombat_Status_XP_01_Clean.png"
const ICON_CREDITS := "Icons_Inventory/ICON_MilitaryCombat_Inventory_Currency_02_Clean.png"
const ICON_HELI := "Icons_Map/ICON_MilitaryCombat_Map_Helicopter_01_Clean.png"
const ICON_MAP_OBJ := "Icons_Map/ICON_MilitaryCombat_Map_Objective_01_Clean.png"
const ICON_MAP_DANGER := "Icons_Map/ICON_MilitaryCombat_Map_Danger_01_Clean.png"
const ICON_LOCK := "Icons_Map/ICON_MilitaryCombat_Map_Lock_01_Clean.png"
const ICON_MSG := "Icons_Map/ICON_MilitaryCombat_Map_Message_01_Clean.png"
const ICON_TROPHY := "Icons_Inventory/ICON_MilitaryCombat_Inventory_Trophy_01_Clean.png"
const KEY_E := "Core/Icons_Input/MouseKeyboard/ICON_Input_PC_Button_Clean.png"
const ICON_MAP_HOME := "Icons_Map/ICON_MilitaryCombat_Map_Home_01_Clean.png"
const ICON_MAP_LIGHTNING := "Icons_Map/ICON_MilitaryCombat_Map_Lightning_01_Clean.png"
const BADGE_DOMINION := "Badges/SPR_MilitaryCombat_Badge_Element_SnakeSkull_01_Silver.png"
const SPR_SAMPLE_MAP := "Samples/SPR_HUD_MilitaryCombat_Example_Map_01.png"
const SPR_BOX := "MilitaryCombat/SPR_MilitaryCombat_Box_Medium_03.png"
const SPR_BOX_OLIVE := "MilitaryCombat/SPR_MilitaryCombat_Box_Medium_04.png"
const SPR_BTN := "MilitaryCombat/SPR_MilitaryCombat_Bar_Small_01.png"
const SPR_INSET := "MilitaryCombat/SPR_MilitaryCombat_Box_Small_02.png"
const SPR_RAIL := "MilitaryCombat/SPR_MilitaryCombat_Bar_Large_01.png"
const SPR_TITLE_BAR := "MilitaryCombat/SPR_MilitaryCombat_Bar_08.png"
const SPR_PORTRAIT_FRAME := "MilitaryCombat/SPR_MilitaryCombat_Frame_Medium_12.png"
const SPR_DIAL := "MilitaryCombat/SPR_MilitaryCombat_Dial_Large_01.png"
const SPR_SOCKET := "MilitaryCombat/SPR_MilitaryCombat_Socket_Frame_01.png"
const SPR_SOCKET_BG := "MilitaryCombat/SPR_MilitaryCombat_Socket_Background_01.png"
const SPR_HEX := "HUD/SPR_HUD_MilitaryCombat_Map_Circle_Small_01_Clean.png"
const SPR_ARROW_DOWN := "HUD/SPR_HUD_MilitaryCombat_Arrow_01_Clean.png"
const SPR_LOADING := "HUD/SPR_HUD_MilitaryCombat_LoadingIcon_01_Arrows_Clean.png"
const SPR_SCOPE_VIGNETTE := "HUD/SPR_HUD_MilitaryCombat_Vignette_Scope01.png"
const SPR_SCOPE_CROSS := "HUD/SPR_HUD_MilitaryCombat_Reticle_Sniper_Crosshair_01.png"
const SPR_SCOPE_RING := "HUD/SPR_HUD_MilitaryCombat_Reticle_Sniper_Ring_01.png"
const CURSOR := "Cursors/SPR_MouseCursor_MilitaryCombat_Pointer_01.png"
const SHOT_MENU := "Samples/SPR_HUD_MilitaryCombat_ExampleScreenshot_FirstPerson.png"
const SHOT_LOBBY := "Samples/SPR_HUD_MilitaryCombat_ExampleScreenshot_3rdPerson.png"
const SHOT_BROWSER := "Samples/SPR_HUD_MilitaryCombat_ExampleScreenshot_Survival.png"
const SHOT_RESULTS := "Samples/SPR_HUD_MilitaryCombat_ExampleScreenshot_LooterShooter.png"
const SHOT_FAILED := "Samples/SPR_HUD_MilitaryCombat_ExampleScreenshot_Downed.png"
# Literal paths so tools/import_assets.py can find every referenced sprite.
const PORTRAITS := {
	"assault": "Samples/SPR_HUD_MilitaryCombat_Example_CharacterPortrait_02.png",
	"medic": "Samples/SPR_HUD_MilitaryCombat_Example_CharacterPortrait_01.png",
	"recon": "Samples/SPR_HUD_MilitaryCombat_Example_CharacterPortrait_03.png",
	"support": "Samples/SPR_HUD_MilitaryCombat_Example_CharacterPortrait_04.png",
}
const RANKS := [
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_01_Bronze.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_02_Bronze.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_03_Bronze.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_04_Silver.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_05_Silver.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_06_Silver.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_07_Gold.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_08_Gold.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_09_Gold.png",
	"Badges/SPR_MilitaryCombat_Badge_Element_Rank_10_Gold.png",
]
const FONT_MED := "Fonts/Oxanium/Oxanium-Medium.ttf"
const FONT_BOLD := "Fonts/Oxanium/Oxanium-Bold.ttf"

static var _cache := {}
static var _theme: Theme

static func tex(rel: String) -> Texture2D:
	if _cache.has(rel):
		return _cache[rel]
	var t: Texture2D = load(ROOT + rel) if ResourceLoader.exists(ROOT + rel) else null
	if t == null:
		push_warning("UiKit: missing sprite " + rel)
	_cache[rel] = t
	return t

static func font(bold := false) -> Font:
	return load(ROOT + (FONT_BOLD if bold else FONT_MED))

static func sbox(rel: String, color: Color, margin := 16, content := 10) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(rel)
	sb.modulate_color = color
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_texture_margin(side, margin)
		sb.set_content_margin(side, content)
	return sb

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	# Buttons: Synty bevelled metal bar, tinted per state
	t.set_stylebox("normal", "Button", sbox(SPR_BTN, Color(0.27, 0.3, 0.24), 12, 14))
	t.set_stylebox("hover", "Button", sbox(SPR_BTN, Color(0.42, 0.43, 0.3), 12, 14))
	t.set_stylebox("pressed", "Button", sbox(SPR_BTN, ACCENT.darkened(0.15), 12, 14))
	t.set_stylebox("hover_pressed", "Button", sbox(SPR_BTN, ACCENT, 12, 14))
	t.set_stylebox("focus", "Button", sbox(SPR_PANEL_FRAME, Color(ACCENT, 0.6), 12, 14))
	t.set_stylebox("disabled", "Button", sbox(SPR_BTN, Color(0.14, 0.15, 0.13, 0.9), 12, 14))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", Color(0.08, 0.07, 0.04))
	t.set_color("font_hover_pressed_color", "Button", Color(0.08, 0.07, 0.04))
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.35))
	t.set_constant("h_separation", "Button", 10)
	# Panels: Synty metal-rimmed box
	t.set_stylebox("panel", "PanelContainer", sbox(SPR_BOX, Color(1, 1, 1, 0.96), 46, 26))
	t.set_stylebox("panel", "Panel", sbox(SPR_BOX, Color(1, 1, 1, 0.96), 46, 26))
	# Text input: dark inset box
	t.set_stylebox("normal", "LineEdit", sbox(SPR_INSET, Color(0.06, 0.07, 0.06, 0.95), 8, 10))
	t.set_stylebox("focus", "LineEdit", sbox(SPR_INSET, Color(0.16, 0.15, 0.08, 0.98), 8, 10))
	t.set_stylebox("read_only", "LineEdit", sbox(SPR_INSET, Color(0.06, 0.07, 0.06, 0.6), 8, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", DIM.darkened(0.2))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font(true))
	# Check boxes: Synty objective active/inactive markers
	for st in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckBox", tex_sized(SPR_OBJ_ACTIVE, 18, ACCENT))
	t.set_icon("unchecked", "CheckBox", tex_sized(SPR_OBJ_INACTIVE, 18, DIM))
	t.set_icon("checked", "CheckButton", tex_sized(SPR_OBJ_ACTIVE, 18, ACCENT))
	t.set_icon("unchecked", "CheckButton", tex_sized(SPR_OBJ_INACTIVE, 18, DIM))
	for st in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	for cls in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_pressed_color", cls, ACCENT)
		t.set_color("font_hover_color", cls, ACCENT)
		t.set_color("font_hover_pressed_color", cls, ACCENT)
	# Option / popup menus
	t.set_stylebox("normal", "OptionButton", sbox(SPR_INSET, Color(0.1, 0.11, 0.09, 0.95), 8, 12))
	t.set_stylebox("hover", "OptionButton", sbox(SPR_INSET, Color(0.18, 0.18, 0.12, 0.98), 8, 12))
	t.set_stylebox("pressed", "OptionButton", sbox(SPR_INSET, Color(0.18, 0.18, 0.12, 0.98), 8, 12))
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_icon("arrow", "OptionButton", tex_sized(SPR_ARROW_DOWN, 14, ACCENT))
	t.set_stylebox("panel", "PopupMenu", sbox(SPR_BOX, Color(1, 1, 1, 0.98), 30, 14))
	t.set_stylebox("hover", "PopupMenu", sbox(SPR_INSET, Color(ACCENT, 0.35), 6, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# Sliders + scroll bars: Synty angled bar track, hex grabber
	t.set_icon("grabber", "HSlider", tex_sized(SPR_HEX, 18, ACCENT))
	t.set_icon("grabber_highlight", "HSlider", tex_sized(SPR_HEX, 20, Color(1, 0.9, 0.6)))
	t.set_stylebox("slider", "HSlider", sbox(SPR_BAR, Color(0.2, 0.22, 0.18), 10, 3))
	var fill := sbox(SPR_BAR, ACCENT.darkened(0.25), 10, 3)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("scroll", "VScrollBar", sbox(SPR_INSET, Color(0.05, 0.05, 0.05, 0.6), 4, 2))
	t.set_stylebox("grabber", "VScrollBar", sbox(SPR_BTN, Color(0.4, 0.42, 0.32), 6, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", sbox(SPR_BTN, ACCENT, 6, 2))
	t.set_stylebox("grabber_pressed", "VScrollBar", sbox(SPR_BTN, ACCENT, 6, 2))
	# SpinBox arrows
	t.set_icon("updown", "SpinBox", tex_sized(SPR_ARROW_DOWN, 14, ACCENT))
	t.set_stylebox("panel", "TooltipPanel", sbox(SPR_INSET, Color(0.05, 0.06, 0.05, 0.95), 8, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t

## Texture resized (and optionally tinted) for theme icons that are drawn at native size.
static func tex_sized(rel: String, px: int, tint := Color.WHITE) -> Texture2D:
	var key := "%s@%d|%s" % [rel, px, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var src := tex(rel)
	if src == null:
		return null
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(px, int(round(px * float(img.get_height()) / img.get_width())), Image.INTERPOLATE_LANCZOS)
	if tint != Color.WHITE:
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, img.get_pixel(x, y) * tint)
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

## Full-screen menu backdrop: a supplied Synty sample screenshot, darkened, with vignette + scanlines.
static func backdrop(parent: Control, shot_rel: String, darkness := 0.62) -> void:
	var base := ColorRect.new()
	base.color = Color(0.03, 0.035, 0.03)
	parent.add_child(full_rect(base))
	var shot := TextureRect.new()
	shot.texture = tex(shot_rel)
	shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	shot.modulate = Color(1, 1, 1, 1.0 - darkness * 0.35)
	parent.add_child(full_rect(shot))
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.02, darkness)
	parent.add_child(full_rect(shade))
	var vig := TextureRect.new()
	vig.texture = tex(SPR_VIGNETTE)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.modulate = Color(0, 0, 0, 0.85)
	parent.add_child(full_rect(vig))
	var scan := TextureRect.new()
	scan.texture = tex(SPR_SCANLINES)
	scan.stretch_mode = TextureRect.STRETCH_TILE
	scan.modulate = Color(0.6, 0.7, 0.5, 0.06)
	parent.add_child(full_rect(scan))
	for c in parent.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Rank insignia for a profile level (Synty rank badges: bronze 1-3, silver 4-6, gold 7+).
static func rank_badge(level: int) -> String:
	return RANKS[clampi(level, 1, RANKS.size()) - 1]

## Operator portrait per class (supplied Synty example character portraits).
static func portrait(class_id: String) -> String:
	return PORTRAITS.get(class_id, PORTRAITS["assault"])

## Full-colour weapon render (Icons_Weapons without the _Clean suffix) for cards and loadout.
static func weapon_render(weapon_id: String) -> String:
	return GameData.weapon(weapon_id).get("render", GameData.weapon(weapon_id).get("icon", ""))

## Portrait inside a Synty metal frame; `selected` adds the accent rim.
static func portrait_card(class_id: String, size: float, selected := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	var bg := TextureRect.new()
	bg.texture = tex(SPR_INSET)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.modulate = Color(0.1, 0.12, 0.1) if not selected else Color(0.32, 0.27, 0.12)
	c.add_child(full_rect(bg))
	var pic := TextureRect.new()
	pic.texture = tex(portrait(class_id))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	c.add_child(full_rect(pic))
	pic.offset_left = size * 0.08; pic.offset_top = size * 0.1; pic.offset_right = -size * 0.08; pic.offset_bottom = -size * 0.06
	var fr := TextureRect.new()
	fr.texture = tex(SPR_PORTRAIT_FRAME)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fr.modulate = Color(1, 1, 1) if not selected else Color(1.0, 0.85, 0.45)
	c.add_child(full_rect(fr))
	for n in [bg, pic, fr]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

## Hex equipment socket (Synty socket frame + background) holding an item render, with a count label.
static func socket(item_rel: String, size: float, count_text := "", tip := "", dim := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.tooltip_text = tip
	var bg := TextureRect.new()
	bg.texture = tex(SPR_SOCKET_BG)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.add_child(full_rect(bg))
	var it := TextureRect.new()
	it.texture = tex(item_rel)
	it.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	it.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	it.modulate = Color(1, 1, 1, 0.35) if dim else Color.WHITE
	c.add_child(full_rect(it))
	it.offset_left = size * 0.16; it.offset_top = size * 0.16; it.offset_right = -size * 0.16; it.offset_bottom = -size * 0.16
	var fr := TextureRect.new()
	fr.texture = tex(SPR_SOCKET)
	fr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c.add_child(full_rect(fr))
	for n in [bg, it, fr]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if count_text != "":
		var l := label(count_text, int(size * 0.24), ACCENT if not dim else DIM, true)
		l.position = Vector2(size * 0.62, size * 0.66)
		c.add_child(l)
	return c

static func equip_render(equip_id: String) -> String:
	return GameData.equip(equip_id).get("render", GameData.equip(equip_id).get("icon", ""))

static func label(text: String, size := 18, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l

static func icon(rel: String, size: float, color := TEXT) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(rel)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

static func bar(color: Color, size: Vector2) -> TextureProgressBar:
	var b := TextureProgressBar.new()
	b.texture_under = tex(SPR_BAR)
	b.texture_progress = tex(SPR_BAR)
	b.tint_under = Color(0.0, 0.0, 0.0, 0.55)
	b.tint_progress = color
	b.nine_patch_stretch = true
	b.stretch_margin_left = 12
	b.stretch_margin_right = 12
	b.custom_minimum_size = size
	b.max_value = 100
	b.value = 100
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func button(text: String, cb: Callable, min_w := 220.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 46)
	b.pressed.connect(func():
		Sfx.play_2d("ui", -10.0)
		cb.call())
	return b

static func panel(min_size := Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p

static func header(text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var bar_r := TextureRect.new()
	bar_r.texture = tex(SPR_HEADER)
	bar_r.modulate = ACCENT
	bar_r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_r.custom_minimum_size = Vector2(8, 28)
	box.add_child(bar_r)
	box.add_child(label(text.to_upper(), 24, ACCENT, true))
	return box

static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

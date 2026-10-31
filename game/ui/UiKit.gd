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
	t.set_stylebox("normal", "Button", sbox(SPR_BUTTON, Color(0.16, 0.18, 0.15, 0.95), 14, 12))
	t.set_stylebox("hover", "Button", sbox(SPR_BUTTON, Color(0.3, 0.27, 0.15, 0.98), 14, 12))
	t.set_stylebox("pressed", "Button", sbox(SPR_BUTTON, ACCENT.darkened(0.3), 14, 12))
	t.set_stylebox("focus", "Button", sbox(SPR_BUTTON, Color(ACCENT, 0.35), 14, 12))
	t.set_stylebox("disabled", "Button", sbox(SPR_BUTTON, Color(0.1, 0.1, 0.1, 0.7), 14, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.BLACK)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_stylebox("panel", "PanelContainer", sbox(SPR_PANEL, PANEL, 24, 18))
	t.set_stylebox("normal", "LineEdit", sbox(SPR_BUTTON, Color(0.03, 0.035, 0.03, 0.95), 14, 10))
	t.set_stylebox("focus", "LineEdit", sbox(SPR_BUTTON, Color(ACCENT, 0.4), 14, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", font())
	t.set_font("bold_font", "RichTextLabel", font(true))
	for st in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_pressed_color", "CheckBox", ACCENT)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_color("font_hover_pressed_color", "CheckBox", ACCENT)
	var grab := sbox(SPR_BUTTON, ACCENT, 6, 6)
	t.set_icon("grabber", "HSlider", tex(SPR_MAP_DOT))
	t.set_icon("grabber_highlight", "HSlider", tex(SPR_MAP_DOT))
	t.set_stylebox("slider", "HSlider", sbox(SPR_BAR, Color(0.25, 0.27, 0.23), 8, 4))
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	_theme = t
	return t

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

extends Control
## Main menu: deploy solo (local dedicated server), join server, operations, equipment, character, settings, credits, exit.

var app: Node
var _content: Control
var _addr: LineEdit

func _init(a: Node) -> void:
	app = a
	UiKit.full_rect(self)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.045)
	add_child(UiKit.full_rect(bg))
	var vig := TextureRect.new()
	vig.texture = UiKit.tex(UiKit.SPR_VIGNETTE)
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.modulate = Color(0.0, 0.0, 0.0, 0.8)
	add_child(UiKit.full_rect(vig))
	var scan := TextureRect.new()
	scan.texture = UiKit.tex(UiKit.SPR_SCANLINES)
	scan.stretch_mode = TextureRect.STRETCH_TILE
	scan.modulate = Color(0.6, 0.7, 0.5, 0.05)
	add_child(UiKit.full_rect(scan))
	var techy := UiKit.icon(UiKit.SPR_TECHY, 300, Color(UiKit.ACCENT, 0.25))
	techy.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	techy.position -= Vector2(340, 120)
	add_child(techy)

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_top = 70
	root.offset_right = -80
	root.offset_bottom = -60
	root.add_theme_constant_override("separation", 60)
	add_child(root)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	left.add_child(UiKit.label("OPERATION:", 34, UiKit.DIM, true))
	left.add_child(UiKit.label("BLACKOUT", 72, UiKit.ACCENT, true))
	left.add_child(UiKit.label("Four operators. One mission. No one left behind.", 18, UiKit.DIM))
	var sp := Control.new()
	sp.custom_minimum_size.y = 30
	left.add_child(sp)
	left.add_child(UiKit.button("DEPLOY (SOLO / LOCAL)", func(): app.play_solo(), 320))
	left.add_child(UiKit.button("JOIN SERVER", func(): _show(_join_panel()), 320))
	left.add_child(UiKit.button("OPERATIONS", func(): _show(_operations_panel()), 320))
	left.add_child(UiKit.button("EQUIPMENT", func(): _show(_equipment_panel()), 320))
	left.add_child(UiKit.button("CHARACTER", func(): _show(_character_panel()), 320))
	left.add_child(UiKit.button("SETTINGS", func(): _show(preload("res://ui/SettingsPanel.gd").new()), 320))
	left.add_child(UiKit.button("CREDITS", func(): _show(_credits_panel()), 320))
	left.add_child(UiKit.button("EXIT", func(): get_tree().quit(), 320))
	left.add_child(UiKit.label("v%s  ·  Callsign: %s" % [ProjectSettings.get_setting("application/config/version"), Settings.get_v("player_name")], 14, UiKit.DIM))
	_content = MarginContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_content)
	_show(_operations_panel())

func _show(c: Control) -> void:
	for ch in _content.get_children():
		ch.queue_free()
	_content.add_child(c)

func _join_panel() -> Control:
	var p := UiKit.panel(Vector2(560, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiKit.header("Join dedicated server"))
	v.add_child(UiKit.label("Enter the address of an Operation: Blackout dedicated server (host:port).", 16, UiKit.DIM))
	_addr = LineEdit.new()
	_addr.text = Settings.get_v("last_server")
	_addr.custom_minimum_size = Vector2(400, 44)
	v.add_child(_addr)
	v.add_child(UiKit.button("CONNECT", func(): app.join(_addr.text.strip_edges())))
	return p

func _operations_panel() -> Control:
	var p := UiKit.panel(Vector2(640, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.header("Operations"))
	for id in ["op01", "op02", "op03", "op04", "op05", "op06", "op07"]:
		var m := GameData.mission(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiKit.icon(UiKit.ICON_MAP_OBJ if m.get("playable", false) else UiKit.ICON_LOCK, 30, UiKit.ACCENT if m.get("playable", false) else UiKit.DIM))
		var col := VBoxContainer.new()
		col.add_child(UiKit.label("%s  %s" % [m["code"], m["name"]], 20, UiKit.TEXT if m.get("playable", false) else UiKit.DIM, true))
		var d := UiKit.label("%s — %s" % [m.get("environment", ""), m["briefing"]], 14, UiKit.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 520
		col.add_child(d)
		row.add_child(col)
		v.add_child(row)
	v.add_child(UiKit.label("Only OP-01 is deployable in this build. Further operations unlock in campaign milestone M6.", 14, UiKit.ACCENT))
	return p

func _equipment_panel() -> Control:
	var p := UiKit.panel(Vector2(640, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.header("Armory"))
	for id in GameData.weapons:
		var w := GameData.weapon(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var ic := UiKit.icon(w["icon"], 0, UiKit.TEXT)
		ic.custom_minimum_size = Vector2(120, 60)
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_child(UiKit.label("%s  [%s]" % [w["name"], w["category"].replace("_", " ").to_upper()], 18, UiKit.TEXT, true))
		col.add_child(UiKit.label("DMG %d · %d RPM · MAG %d · RANGE %dm · Unlocks at level %d" % [w["damage"], w["rpm"], w["mag"], w["range"], w["unlock_level"]], 14, UiKit.DIM))
		row.add_child(col)
		v.add_child(row)
	v.add_child(UiKit.label("Loadouts are configured and validated in the HQ squad lobby.", 14, UiKit.ACCENT))
	return p

func _character_panel() -> Control:
	var p := UiKit.panel(Vector2(560, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UiKit.header("Operator profile"))
	v.add_child(UiKit.label("Callsign", 16, UiKit.DIM))
	var name_edit := LineEdit.new()
	name_edit.text = Settings.get_v("player_name")
	name_edit.max_length = 24
	v.add_child(name_edit)
	v.add_child(UiKit.button("SAVE CALLSIGN", func():
		Settings.set_v("player_name", name_edit.text.strip_edges().left(24))
		app.toast("Callsign saved.")))
	v.add_child(UiKit.label("Profile ID: %s" % Settings.get_v("profile_id"), 13, UiKit.DIM))
	v.add_child(UiKit.label("Experience, credits and unlocks are stored by the server you play on.", 14, UiKit.DIM))
	v.add_child(UiKit.label("Outfits and insignias: planned (M6).", 14, UiKit.DIM))
	return p

func _credits_panel() -> Control:
	var p := UiKit.panel(Vector2(560, 0))
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UiKit.header("Credits"))
	for line in ["Operation: Blackout — prototype build", "Engine: Godot 4.3 (MIT)",
			"HUD art: Synty Studios — INTERFACE Military Combat HUD (licensed asset pack)",
			"Font: Oxanium (SIL Open Font License)", "Audio: procedurally generated", "Design & code: Task Force BLACKOUT dev team"]:
		v.add_child(UiKit.label(line, 16))
	return p

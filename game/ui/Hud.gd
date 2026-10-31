extends Control
## In-game HUD built from Synty Military Combat HUD sprites.
## Reads replicated state only (local player mirror, snapshots, objective state) — no gameplay authority.

var world: Node
var chat_open := false

var _hp_bar: TextureProgressBar
var _armor_bar: TextureProgressBar
var _stam_bar: TextureProgressBar
var _hp_label: Label
var _weapon_icon: TextureRect
var _weapon_name: Label
var _ammo: Label
var _reserve: Label
var _mode: Label
var _equip_box: HBoxContainer
var _objectives: VBoxContainer
var _squad: VBoxContainer
var _crosshair: TextureRect
var _hitmark: TextureRect
var _prompt: HBoxContainer
var _prompt_label: Label
var _ring: TextureProgressBar
var _vignette: TextureRect
var _flash: ColorRect
var _downed: Control
var _downed_label: Label
var _extract: HBoxContainer
var _extract_label: Label
var _extract_bar: TextureProgressBar
var _feed: VBoxContainer
var _chat_log: RichTextLabel
var _chat_in: LineEdit
var _intro: Control
var _markers: Control
var _dmg_root: Control
var _hit_t := 0.0
var _flash_t := 0.0
var _squad_rows := {}

func _init(w: Node) -> void:
	world = w
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_vignette = TextureRect.new()
	_vignette.texture = UiKit.tex(UiKit.SPR_VIGNETTE)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.modulate = Color(0.6, 0.0, 0.0, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(_vignette))
	_markers = Control.new()
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(_markers))
	_markers.draw.connect(_draw_markers)
	_dmg_root = Control.new()
	_dmg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(_dmg_root))
	_build_vitals()
	_build_weapon()
	_build_top()
	_build_squad()
	_build_center()
	_build_feed_and_chat()
	_build_overlays()
	world.objectives_changed.connect(_on_objectives)
	world.event_message.connect(_on_event)
	world.local_player_ready.connect(func(p): p.inventory_changed.connect(_on_inventory))
	Session.chat_received.connect(_on_chat)
	_show_intro()

# ------------------------------------------------------------------ construction
func _anchor(c: Control, preset: int, offset: Vector2) -> Control:
	c.set_anchors_preset(preset)
	c.position = offset
	add_child(c)
	return c

func _panel_bg(c: Control, rel: String, color: Color) -> void:
	var bg := TextureRect.new()
	bg.texture = UiKit.tex(rel)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.modulate = color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.move_child(bg, 0)

func _build_vitals() -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(380, 110)
	box.size = box.custom_minimum_size
	_anchor(box, Control.PRESET_BOTTOM_LEFT, Vector2(24, -134))
	box.anchor_top = 1.0; box.anchor_bottom = 1.0
	_panel_bg(box, UiKit.SPR_ANGLED_BG, Color(0.0, 0.0, 0.0, 0.55))
	var v := VBoxContainer.new()
	v.position = Vector2(18, 12)
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var r1 := HBoxContainer.new()
	r1.add_child(UiKit.icon(UiKit.ICON_HEALTH, 28, UiKit.TEXT))
	_hp_bar = UiKit.bar(UiKit.TEXT, Vector2(250, 24))
	r1.add_child(_hp_bar)
	_hp_label = UiKit.label("100", 22, UiKit.TEXT, true)
	r1.add_child(_hp_label)
	v.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_child(UiKit.icon(UiKit.ICON_ARMOR, 24, UiKit.ARMOR))
	_armor_bar = UiKit.bar(UiKit.ARMOR, Vector2(250, 16))
	r2.add_child(_armor_bar)
	v.add_child(r2)
	var r3 := HBoxContainer.new()
	r3.add_child(UiKit.icon(UiKit.ICON_STAMINA, 22, UiKit.DIM))
	_stam_bar = UiKit.bar(Color(0.85, 0.85, 0.7, 0.8), Vector2(180, 8))
	r3.add_child(_stam_bar)
	v.add_child(r3)

func _build_weapon() -> void:
	var box := Control.new()
	box.custom_minimum_size = Vector2(420, 130)
	box.size = box.custom_minimum_size
	_anchor(box, Control.PRESET_BOTTOM_RIGHT, Vector2(-444, -154))
	box.anchor_left = 1.0; box.anchor_right = 1.0; box.anchor_top = 1.0; box.anchor_bottom = 1.0
	_panel_bg(box, UiKit.SPR_ANGLED_BG, Color(0.0, 0.0, 0.0, 0.55))
	_weapon_icon = UiKit.icon(UiKit.SPR_DOT, 0, UiKit.TEXT)
	_weapon_icon.position = Vector2(14, 10)
	_weapon_icon.size = Vector2(170, 70)
	box.add_child(_weapon_icon)
	_weapon_name = UiKit.label("", 15, UiKit.DIM, true)
	_weapon_name.position = Vector2(18, 82)
	box.add_child(_weapon_name)
	_ammo = UiKit.label("30", 46, UiKit.TEXT, true)
	_ammo.position = Vector2(220, 4)
	box.add_child(_ammo)
	_reserve = UiKit.label("/ 120", 22, UiKit.DIM)
	_reserve.position = Vector2(300, 24)
	box.add_child(_reserve)
	_mode = UiKit.label("AUTO", 14, UiKit.ACCENT, true)
	_mode.position = Vector2(224, 62)
	box.add_child(_mode)
	_equip_box = HBoxContainer.new()
	_equip_box.position = Vector2(18, 102)
	_equip_box.add_theme_constant_override("separation", 14)
	box.add_child(_equip_box)

func _build_top() -> void:
	var compass := preload("res://ui/Compass.gd").new()
	compass.world = world
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-280, 14)
	compass.size = Vector2(560, 46)
	add_child(compass)
	var mm := preload("res://ui/Minimap.gd").new()
	mm.world = world
	mm.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mm.position = Vector2(-254, 20)
	mm.size = Vector2(230, 230)
	add_child(mm)
	var ob := Control.new()
	ob.custom_minimum_size = Vector2(380, 200)
	ob.size = ob.custom_minimum_size
	_anchor(ob, Control.PRESET_TOP_LEFT, Vector2(24, 20))
	_panel_bg(ob, UiKit.SPR_GRAD_H, Color(0, 0, 0, 0.45))
	var v := VBoxContainer.new()
	v.position = Vector2(12, 8)
	v.add_theme_constant_override("separation", 4)
	ob.add_child(v)
	var hdr := HBoxContainer.new()
	hdr.add_child(UiKit.icon(UiKit.ICON_MAP_OBJ, 20, UiKit.ACCENT))
	hdr.add_child(UiKit.label("%s  %s" % [world.mission.get("code", ""), world.mission.get("name", "")], 16, UiKit.ACCENT, true))
	v.add_child(hdr)
	_objectives = VBoxContainer.new()
	_objectives.add_theme_constant_override("separation", 3)
	v.add_child(_objectives)

func _build_squad() -> void:
	_squad = VBoxContainer.new()
	_squad.add_theme_constant_override("separation", 6)
	_anchor(_squad, Control.PRESET_CENTER_LEFT, Vector2(24, -40))

func _build_center() -> void:
	_crosshair = UiKit.icon(UiKit.SPR_CROSSHAIR, 44, Color(1, 1, 1, 0.85))
	_anchor(_crosshair, Control.PRESET_CENTER, Vector2(-22, -22))
	_hitmark = UiKit.icon(UiKit.SPR_HITMARK, 40, Color(1, 1, 1, 0))
	_anchor(_hitmark, Control.PRESET_CENTER, Vector2(-20, -20))
	_ring = TextureProgressBar.new()
	_ring.texture_under = UiKit.tex(UiKit.SPR_RING)
	_ring.texture_progress = UiKit.tex(UiKit.SPR_RING)
	_ring.tint_under = Color(0, 0, 0, 0.5)
	_ring.tint_progress = UiKit.ACCENT
	_ring.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_ring.nine_patch_stretch = true
	_ring.size = Vector2(72, 72)
	_ring.max_value = 1.0
	_ring.step = 0.001
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_ring, Control.PRESET_CENTER, Vector2(-36, -36))
	_prompt = HBoxContainer.new()
	_prompt.add_theme_constant_override("separation", 8)
	var key := UiKit.icon(UiKit.KEY_E, 30, UiKit.TEXT)
	var kl := UiKit.label("E", 16, Color.BLACK, true)
	kl.position = Vector2(9, 3)
	key.add_child(kl)
	_prompt.add_child(key)
	_prompt_label = UiKit.label("", 18, UiKit.TEXT, true)
	_prompt.add_child(_prompt_label)
	_anchor(_prompt, Control.PRESET_CENTER, Vector2(-90, 52))
	_extract = HBoxContainer.new()
	_extract.add_theme_constant_override("separation", 10)
	_extract.add_child(UiKit.icon(UiKit.ICON_HELI, 34, UiKit.ACCENT))
	var ev := VBoxContainer.new()
	_extract_label = UiKit.label("EXTRACTION", 18, UiKit.ACCENT, true)
	ev.add_child(_extract_label)
	_extract_bar = UiKit.bar(UiKit.ACCENT, Vector2(260, 12))
	ev.add_child(_extract_bar)
	_extract.add_child(ev)
	_anchor(_extract, Control.PRESET_CENTER_TOP, Vector2(-150, 74))
	_extract.visible = false

func _build_feed_and_chat() -> void:
	_feed = VBoxContainer.new()
	_feed.alignment = BoxContainer.ALIGNMENT_END
	_feed.custom_minimum_size = Vector2(440, 0)
	_anchor(_feed, Control.PRESET_CENTER_RIGHT, Vector2(-464, 40))
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.custom_minimum_size = Vector2(420, 120)
	_chat_log.size = _chat_log.custom_minimum_size
	_chat_log.add_theme_font_size_override("normal_font_size", 14)
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(_chat_log, Control.PRESET_BOTTOM_LEFT, Vector2(24, -300))
	_chat_in = LineEdit.new()
	_chat_in.custom_minimum_size = Vector2(420, 36)
	_chat_in.size = _chat_in.custom_minimum_size
	_chat_in.max_length = 200
	_chat_in.visible = false
	_chat_in.placeholder_text = "Squad chat (Enter to send, Esc to cancel)"
	_chat_in.text_submitted.connect(func(t):
		if t.strip_edges() != "":
			Session.send_chat(t)
		close_chat())
	_anchor(_chat_in, Control.PRESET_BOTTOM_LEFT, Vector2(24, -176))

func _build_overlays() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(_flash))
	_downed = Control.new()
	_downed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.full_rect(_downed))
	var dv := VBoxContainer.new()
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.set_anchors_preset(Control.PRESET_CENTER)
	dv.position = Vector2(-220, 90)
	dv.custom_minimum_size = Vector2(440, 0)
	_downed.add_child(dv)
	var ic := UiKit.icon(UiKit.ICON_DOWN, 64, UiKit.BAD)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dv.add_child(ic)
	_downed_label = UiKit.label("", 22, UiKit.BAD, true)
	_downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dv.add_child(_downed_label)
	_downed.visible = false

func _show_intro() -> void:
	_intro = VBoxContainer.new()
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.position = Vector2(-360, -200)
	_intro.custom_minimum_size = Vector2(720, 0)
	var m: Dictionary = world.mission
	var t1 := UiKit.label(m.get("code", ""), 22, UiKit.DIM, true)
	var t2 := UiKit.label(m.get("name", ""), 54, UiKit.ACCENT, true)
	var t3 := UiKit.label(m.get("environment", ""), 18, UiKit.TEXT)
	var t4 := UiKit.label(m.get("briefing", ""), 16, UiKit.DIM)
	t4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [t1, t2, t3, t4]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_intro.add_child(l)
	add_child(_intro)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(_intro, "modulate:a", 0.0, 1.5)
	tw.tween_callback(_intro.queue_free)

# ------------------------------------------------------------------ events
func _on_inventory(inv: Dictionary) -> void:
	if inv.is_empty():
		return
	var w: Dictionary = inv["weapons"][inv["active"]]
	var def := GameData.weapon(w["id"])
	_weapon_icon.texture = UiKit.tex(def["icon"])
	_weapon_name.text = def["name"].to_upper()
	_ammo.text = str(w["mag"])
	_ammo.add_theme_color_override("font_color", UiKit.BAD if int(w["mag"]) <= int(def["mag"]) / 5 else UiKit.TEXT)
	_reserve.text = "/ %d" % w["reserve"]
	_mode.text = String(inv.get("fire_mode", "semi")).to_upper() + ("   RELOADING" if inv.get("reloading", false) else "")
	for c in _equip_box.get_children():
		c.queue_free()
	var keys := {"medkit": "Q"}
	var util := []
	for id in inv["equipment"]:
		if id != "medkit":
			util.append(id)
	if util.size() > 0: keys[util[0]] = "G"
	if util.size() > 1: keys[util[1]] = "H"
	for id in inv["equipment"]:
		var e := GameData.equip(id)
		var cnt := int(inv["equipment"][id])
		var cd: bool = inv.get("cooldowns", {}).has(id)
		var h := HBoxContainer.new()
		h.add_child(UiKit.icon(e["icon"], 22, UiKit.DIM if cnt == 0 or cd else UiKit.TEXT))
		h.add_child(UiKit.label("%s×%d" % [keys.get(id, ""), cnt], 13, UiKit.DIM if cnt == 0 else UiKit.TEXT))
		_equip_box.add_child(h)

func _on_objectives(st: Dictionary) -> void:
	for c in _objectives.get_children():
		c.queue_free()
	var objs: Dictionary = st.get("objectives", {})
	for id in st.get("order", []):
		var o: Dictionary = objs[id]
		if o["status"] == "locked" and o["type"] != "extraction":
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var done: bool = o["status"] == "completed"
		var col: Color = UiKit.OK if done else (UiKit.TEXT if o["status"] == "active" else UiKit.DIM)
		row.add_child(UiKit.icon(UiKit.SPR_OBJ_INACTIVE if done or o["status"] == "locked" else UiKit.SPR_OBJ_ACTIVE, 14, col))
		var txt: String = o["name"] + ("" if o["primary"] else "  (optional)")
		if o["status"] == "locked":
			txt += "  [locked]"
		var l := UiKit.label(txt, 15, col, o["primary"])
		row.add_child(l)
		_objectives.add_child(row)

func _on_event(text: String, kind: String) -> void:
	var col := UiKit.TEXT
	var prefix := ""
	match kind:
		"radio": col = Color(0.6, 0.85, 1.0); prefix = "◉ "
		"objective": col = UiKit.OK
		"down", "elim": col = UiKit.BAD
		"revive": col = UiKit.OK
		"mission_end": col = UiKit.ACCENT
	var l := UiKit.label(prefix + text, 15 if kind != "mission_end" else 34, col, kind == "mission_end")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 440
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	if _feed.get_child_count() > 7:
		_feed.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(7.0 if kind == "radio" else 5.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func _on_chat(from: String, text: String) -> void:
	if from == "":
		_chat_log.append_text("[color=#9aa08f]» %s[/color]\n" % text.xml_escape())
	else:
		_chat_log.append_text("[color=#f5ba42]%s:[/color] %s\n" % [from.xml_escape(), text.xml_escape()])

func open_chat() -> void:
	chat_open = true
	world.ui_blocking = true
	_chat_in.visible = true
	_chat_in.grab_focus()

func close_chat() -> void:
	chat_open = false
	_chat_in.text = ""
	_chat_in.visible = false
	_chat_in.release_focus()
	world.ui_blocking = false

func _unhandled_input(event: InputEvent) -> void:
	if not chat_open and not world.ui_blocking and event.is_action_pressed("chat"):
		open_chat()
		get_viewport().set_input_as_handled()

func hit_marker(killed: bool, headshot: bool) -> void:
	_hit_t = 0.25
	_hitmark.modulate = UiKit.BAD if killed else (UiKit.ACCENT if headshot else Color.WHITE)

func damage_from(from_pos: Vector3, amount: float) -> void:
	var lp: Player = world.local_player
	if lp == null:
		return
	var to := from_pos - lp.global_position
	var ang := atan2(to.x, -to.z) + lp.rotation.y   # 0 = in front
	var ind := UiKit.icon(UiKit.SPR_DAMAGE_DIR, 0, Color(1, 0.15, 0.1, clampf(amount / 20.0, 0.4, 1.0)))
	ind.custom_minimum_size = Vector2(320, 80)
	ind.size = Vector2(320, 80)
	ind.pivot_offset = Vector2(160, 240)
	ind.position = size * 0.5 - Vector2(160, 240)
	ind.rotation = -ang
	_dmg_root.add_child(ind)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(ind, "modulate:a", 0.0, 0.8)
	tw.tween_callback(ind.queue_free)

func flash(intensity: float) -> void:
	_flash_t = 3.0 * intensity
	_flash.color.a = intensity

# ------------------------------------------------------------------ per-frame
func _process(dt: float) -> void:
	var lp: Player = world.local_player
	_hit_t -= dt
	_hitmark.modulate.a = clampf(_hit_t / 0.25, 0.0, 1.0)
	if _flash_t > 0.0:
		_flash_t -= dt
		_flash.color.a = clampf(_flash_t / 2.0, 0.0, 1.0)
	_update_squad()
	_markers.queue_redraw()
	if lp == null:
		return
	var n: Dictionary = lp.net
	var max_hp: float = n.get("max_hp", 100.0)
	_hp_bar.max_value = max_hp
	_hp_bar.value = n["hp"]
	_hp_bar.tint_progress = UiKit.BAD if n["hp"] < max_hp * 0.3 else UiKit.TEXT
	_hp_label.text = str(int(ceil(n["hp"])))
	_armor_bar.max_value = n.get("max_armor", 50.0)
	_armor_bar.value = n["armor"]
	_stam_bar.max_value = GameData.player_rules["max_stamina"]
	_stam_bar.value = lp.motor["stamina"]
	var low := clampf(1.0 - n["hp"] / (max_hp * 0.4), 0.0, 1.0)
	_vignette.modulate.a = lerpf(_vignette.modulate.a, low * 0.8, min(1.0, dt * 4.0))
	var downed := lp.is_downed_net()
	var elim := lp.is_eliminated_net()
	_downed.visible = downed or elim
	if downed:
		_downed_label.text = "YOU ARE DOWN — BLEEDING OUT %ds\nHold on. A teammate must revive you." % int(n["extra"])
	elif elim:
		_downed_label.text = "ELIMINATED\nYou will rejoin when the squad completes a primary objective."
	var ads: bool = lp.motor["ads"]
	_crosshair.visible = not ads and not downed and not elim and not lp.motor["sprinting"]
	# interaction prompt (client-side query; server validates the actual hold)
	var it: Dictionary = world.find_interaction(lp, false) if lp.is_alive_net() else {}
	_prompt.visible = not it.is_empty()
	if not it.is_empty():
		_prompt_label.text = "Hold  " + String(it["label"])
	var prog: float = n.get("interact", 0.0)
	var use_left: float = lp.inv_mirror.get("use_left", 0.0)
	_ring.visible = prog > 0.0 or use_left > 0.0
	_ring.value = prog if prog > 0.0 else 1.0 - use_left / 2.0
	# extraction
	var ext_open: bool = world.extraction["open"]
	_extract.visible = ext_open
	if ext_open:
		var p: float = world.extraction["progress"]
		_extract_bar.value = p * 100.0
		_extract_label.text = "EXTRACTION — ALL ACTIVE OPERATORS TO THE LZ" if p <= 0.0 else "EXTRACTING... %d%%" % int(p * 100.0)

func _update_squad() -> void:
	for slot in world.players:
		var p: Player = world.players[slot]
		if not _squad_rows.has(slot):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var c := GameData.klass(p.class_id)
			var col: Array = c["color"]
			var ic := UiKit.icon(c["icon"], 26, Color(col[0], col[1], col[2]))
			row.add_child(ic)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 1)
			var name_l := UiKit.label(p.display_name, 14, UiKit.ACCENT if p.is_local else UiKit.TEXT, true)
			v.add_child(name_l)
			var hb := UiKit.bar(UiKit.TEXT, Vector2(150, 8))
			v.add_child(hb)
			var ab := UiKit.bar(UiKit.ARMOR, Vector2(150, 5))
			v.add_child(ab)
			row.add_child(v)
			var st := UiKit.icon(UiKit.ICON_DOWN, 22, UiKit.BAD)
			row.add_child(st)
			_squad.add_child(row)
			_squad_rows[slot] = {"row": row, "hp": hb, "armor": ab, "status": st, "name": name_l}
		var r: Dictionary = _squad_rows[slot]
		r["hp"].max_value = p.net.get("max_hp", 100.0)
		r["hp"].value = p.net["hp"]
		r["armor"].max_value = p.net.get("max_armor", 50.0)
		r["armor"].value = p.net["armor"]
		var flags := int(p.net["flags"])
		r["status"].visible = (flags & (Player.F_DOWNED | Player.F_ELIMINATED | Player.F_DISCONNECTED)) != 0
		r["status"].texture = UiKit.tex(UiKit.ICON_DEAD if flags & Player.F_ELIMINATED else UiKit.ICON_DOWN)
		r["status"].modulate = UiKit.DIM if flags & Player.F_DISCONNECTED else UiKit.BAD
		r["row"].modulate.a = 0.5 if flags & Player.F_DISCONNECTED else 1.0

func _draw_markers() -> void:
	var lp: Player = world.local_player
	if lp == null or not lp.has_node("Rig"):
		return
	var cam: Camera3D = lp.get_node("Rig").camera
	var f := UiKit.font(true)
	var tex := UiKit.tex(UiKit.SPR_OBJ_WORLD)
	for mp in world.get_objective_markers():
		var pos: Vector3 = mp["pos"] + Vector3.UP * 0.6
		if cam.is_position_behind(pos):
			continue
		var s := cam.unproject_position(pos) / scale
		var d := lp.global_position.distance_to(mp["pos"])
		var icon_t: Texture2D = UiKit.tex(UiKit.ICON_HELI) if mp["kind"] == "extract" else tex
		_markers.draw_texture_rect(icon_t, Rect2(s - Vector2(14, 14), Vector2(28, 28)), false, UiKit.ACCENT)
		_markers.draw_string(f, s + Vector2(-40, 30), "%dm" % int(d), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, UiKit.ACCENT)
	for p in world.players.values():
		if p == lp or not p.is_downed_net():
			continue
		var pos: Vector3 = p.global_position + Vector3.UP * 0.8
		if cam.is_position_behind(pos):
			continue
		var s := cam.unproject_position(pos) / scale
		_markers.draw_texture_rect(UiKit.tex(UiKit.ICON_DOWN), Rect2(s - Vector2(14, 14), Vector2(28, 28)), false, UiKit.BAD)
		_markers.draw_string(f, s + Vector2(-60, 30), "REVIVE %s %ds" % [p.display_name, int(p.net["extra"])], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, UiKit.BAD)

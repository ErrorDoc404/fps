extends Control
## Operations HQ: squad roster, class selection, loadout, operation selection + briefing, readiness, deploy, chat.
## All changes are requests; the dedicated server validates and broadcasts the authoritative lobby state.

var app: Node
var _roster: VBoxContainer
var _classes: HBoxContainer
var _loadout: VBoxContainer
var _ops: VBoxContainer
var _brief: Label
var _ready_btn: Button
var _deploy_btn: Button
var _chat_log: RichTextLabel
var _chat_in: LineEdit
var _profile_box: HBoxContainer

func _init(a: Node) -> void:
	app = a
	UiKit.full_rect(self)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.045, 0.05, 0.045)
	add_child(UiKit.full_rect(bg))
	var stripes := UiKit.icon(UiKit.SPR_HAZARD, 0, Color(UiKit.ACCENT, 0.12))
	stripes.stretch_mode = TextureRect.STRETCH_TILE
	stripes.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stripes.custom_minimum_size.y = 10
	stripes.size.y = 10
	add_child(stripes)
	var root := VBoxContainer.new()
	UiKit.full_rect(root)
	root.offset_left = 30; root.offset_right = -30; root.offset_top = 22; root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	root.add_child(top)
	var title := VBoxContainer.new()
	title.add_child(UiKit.label("TASK FORCE BLACKOUT — OPERATIONS HQ", 28, UiKit.ACCENT, true))
	title.add_child(UiKit.label("Dedicated server session · squad of up to 4", 14, UiKit.DIM))
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_profile_box = HBoxContainer.new()
	_profile_box.add_theme_constant_override("separation", 10)
	top.add_child(_profile_box)
	top.add_child(UiKit.button("LEAVE", func(): app.leave_session(), 120))

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	# --- squad column
	var sq := UiKit.panel(Vector2(380, 0))
	var sqv := VBoxContainer.new()
	sqv.add_theme_constant_override("separation", 8)
	sq.add_child(sqv)
	sqv.add_child(UiKit.header("Squad"))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 6)
	sqv.add_child(_roster)
	var sp2 := Control.new()
	sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sqv.add_child(sp2)
	sqv.add_child(UiKit.header("Comms"))
	_chat_log = RichTextLabel.new()
	_chat_log.custom_minimum_size = Vector2(340, 150)
	_chat_log.scroll_following = true
	_chat_log.bbcode_enabled = true
	_chat_log.add_theme_font_size_override("normal_font_size", 14)
	sqv.add_child(_chat_log)
	_chat_in = LineEdit.new()
	_chat_in.placeholder_text = "Squad chat..."
	_chat_in.max_length = 200
	_chat_in.text_submitted.connect(func(t):
		if t.strip_edges() != "":
			Session.send_chat(t)
		_chat_in.text = "")
	sqv.add_child(_chat_in)
	cols.add_child(sq)
	# --- class + loadout column
	var lo := UiKit.panel()
	lo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lov := VBoxContainer.new()
	lov.add_theme_constant_override("separation", 10)
	lo.add_child(lov)
	lov.add_child(UiKit.header("Class"))
	_classes = HBoxContainer.new()
	_classes.add_theme_constant_override("separation", 8)
	lov.add_child(_classes)
	lov.add_child(UiKit.header("Loadout"))
	_loadout = VBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 6)
	lov.add_child(_loadout)
	cols.add_child(lo)
	# --- operation column
	var op := UiKit.panel(Vector2(420, 0))
	var opv := VBoxContainer.new()
	opv.add_theme_constant_override("separation", 8)
	op.add_child(opv)
	opv.add_child(UiKit.header("Operation"))
	_ops = VBoxContainer.new()
	opv.add_child(_ops)
	_brief = UiKit.label("", 15, UiKit.TEXT)
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief.custom_minimum_size.x = 380
	opv.add_child(_brief)
	var sp3 := Control.new()
	sp3.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opv.add_child(sp3)
	_ready_btn = UiKit.button("READY", func(): Session.request_set_ready(not Session.me().get("ready", false)), 380)
	opv.add_child(_ready_btn)
	_deploy_btn = UiKit.button("DEPLOY SQUAD", func(): Session.request_deploy(), 380)
	opv.add_child(_deploy_btn)
	cols.add_child(op)

	Session.lobby_updated.connect(_refresh)
	Session.profile_updated.connect(func(_p): _refresh(Session.lobby))
	Session.chat_received.connect(_on_chat)
	_refresh(Session.lobby)

func _on_chat(from: String, text: String) -> void:
	if from == "":
		_chat_log.append_text("[color=#9aa08f]» %s[/color]\n" % text.xml_escape())
	else:
		_chat_log.append_text("[color=#f5ba42]%s:[/color] %s\n" % [from.xml_escape(), text.xml_escape()])

func _clear(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()

func _refresh(st: Dictionary) -> void:
	if not is_inside_tree() or st.is_empty():
		return
	var me := Session.me()
	var prof := Session.my_profile
	# profile header
	_clear(_profile_box)
	_profile_box.add_child(UiKit.icon(UiKit.ICON_XP, 28, UiKit.ACCENT))
	var pv := VBoxContainer.new()
	pv.add_child(UiKit.label("%s  ·  LVL %d %s" % [prof.get("name", ""), prof.get("level", 1), prof.get("title", "")], 16, UiKit.TEXT, true))
	var xpbar := UiKit.bar(UiKit.ACCENT, Vector2(220, 12))
	var lo_xp := float(prof.get("prev_level_xp", 0))
	var hi_xp := float(prof.get("next_level_xp", -1))
	xpbar.value = 100.0 if hi_xp <= 0 else (float(prof.get("xp", 0)) - lo_xp) / max(1.0, hi_xp - lo_xp) * 100.0
	pv.add_child(xpbar)
	_profile_box.add_child(pv)
	_profile_box.add_child(UiKit.icon(UiKit.ICON_CREDITS, 26, UiKit.ACCENT))
	_profile_box.add_child(UiKit.label(str(prof.get("credits", 0)), 18, UiKit.ACCENT, true))
	# roster
	_clear(_roster)
	var members: Dictionary = st.get("members", {})
	var by_slot := {}
	for pid in members:
		by_slot[int(members[pid]["slot"])] = [int(pid), members[pid]]
	for slot in range(4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size.y = 42
		if by_slot.has(slot):
			var pid: int = by_slot[slot][0]
			var m: Dictionary = by_slot[slot][1]
			var c := GameData.klass(m["class"])
			var col: Array = c["color"]
			row.add_child(UiKit.icon(c["icon"], 34, Color(col[0], col[1], col[2])))
			var nv := VBoxContainer.new()
			var lead := " ★" if st["leader"] == pid else ""
			nv.add_child(UiKit.label("%s%s%s" % [m["name"], lead, "  (you)" if pid == Session.my_peer else ""], 16, UiKit.ACCENT if pid == Session.my_peer else UiKit.TEXT, true))
			nv.add_child(UiKit.label("LVL %d · %s · %s" % [m["level"], c["name"], GameData.weapon(m["primary"]).get("name", "")], 13, UiKit.DIM))
			nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nv)
			row.add_child(UiKit.label("READY" if m["ready"] else "NOT READY", 14, UiKit.OK if m["ready"] else UiKit.BAD, true))
			if Session.is_leader() and pid != Session.my_peer:
				row.add_child(UiKit.button("✕", func(): Session.request_kick(pid), 40))
		else:
			row.add_child(UiKit.label("— open slot —", 15, UiKit.DIM))
		_roster.add_child(row)
	# classes
	_clear(_classes)
	for cid in GameData.classes:
		var c := GameData.klass(cid)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = me.get("class", "") == cid
		b.text = c["name"]
		b.icon = UiKit.tex(c["icon"])
		b.add_theme_constant_override("icon_max_width", 40)
		b.custom_minimum_size = Vector2(170, 56)
		b.tooltip_text = c["role"]
		b.pressed.connect(func(): Session.request_class(cid))
		_classes.add_child(b)
	# loadout
	_clear(_loadout)
	var cls := GameData.klass(me.get("class", "assault"))
	_loadout.add_child(UiKit.label("%s — %s. Equipment: %s" % [cls.get("name", ""), cls.get("role", ""), ", ".join(cls.get("equipment", {}).keys().map(func(k): return "%s ×%d" % [GameData.equip(k)["name"], cls["equipment"][k]]))], 14, UiKit.DIM))
	for slot_key in ["primary", "secondary"]:
		_loadout.add_child(UiKit.label(slot_key.to_upper(), 15, UiKit.ACCENT, true))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		for wid in GameData.weapons:
			var w := GameData.weapon(wid)
			if w["slot"] != slot_key or not cls.get("allowed_categories", []).has(w["category"]):
				continue
			var unlocked := GameData.is_unlocked(wid, int(prof.get("level", 1)), prof.get("purchased", []))
			var b := Button.new()
			b.toggle_mode = true
			b.button_pressed = me.get(slot_key, "") == wid
			b.disabled = not unlocked
			b.icon = UiKit.tex(w["icon"])
			b.add_theme_constant_override("icon_max_width", 96)
			b.text = w["name"] + ("" if unlocked else "  [LVL %d]" % w["unlock_level"])
			b.custom_minimum_size = Vector2(230, 70)
			b.tooltip_text = "DMG %d · %d RPM · MAG %d · range %dm" % [w["damage"], w["rpm"], w["mag"], w["range"]]
			b.pressed.connect(func():
				var p: String = wid if slot_key == "primary" else me.get("primary", "")
				var s: String = wid if slot_key == "secondary" else me.get("secondary", "")
				Session.request_loadout(p, s))
			row.add_child(b)
		_loadout.add_child(row)
	# operations
	_clear(_ops)
	for id in ["op01", "op02", "op03", "op04", "op05", "op06", "op07"]:
		var m := GameData.mission(id)
		var playable: bool = m.get("playable", false)
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = st.get("mission", "") == id
		b.text = "%s  %s" % [m["code"], m["name"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = UiKit.tex(UiKit.ICON_MAP_OBJ if playable else UiKit.ICON_LOCK)
		b.expand_icon = false
		b.disabled = not playable or not Session.is_leader()
		b.custom_minimum_size = Vector2(380, 40)
		b.add_theme_constant_override("icon_max_width", 24)
		b.pressed.connect(func(): Session.request_mission(id))
		_ops.add_child(b)
	var sel := GameData.mission(st.get("mission", "op01"))
	_brief.text = "%s — %s\n%s\n\nBRIEFING: %s" % [sel["code"], sel["name"], sel.get("environment", ""), sel["briefing"]]
	_ready_btn.text = "STAND DOWN" if me.get("ready", false) else "READY UP"
	var all_ready := true
	for pid in members:
		all_ready = all_ready and members[pid]["ready"]
	_deploy_btn.visible = Session.is_leader()
	_deploy_btn.disabled = not all_ready
	_deploy_btn.text = "DEPLOY SQUAD" if all_ready else "WAITING FOR SQUAD"

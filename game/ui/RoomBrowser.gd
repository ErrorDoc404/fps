extends Control
## Room browser for the connected dedicated server: CS:GO-style filters (search, operation, not full,
## has players, no password, not in progress), join (with password prompt), and create-room form.

var app: Node
var _rows: VBoxContainer
var _search: LineEdit
var _mission: OptionButton
var _checks := {}
var _status: Label
var _pw_box: Control
var _pw_edit: LineEdit
var _pw_room := 0
var _create := {}
var _timer := 0.0

func _init(a: Node) -> void:
	app = a
	UiKit.full_rect(self)

func _ready() -> void:
	UiKit.backdrop(self, UiKit.SHOT_BROWSER, 0.7)
	var root := VBoxContainer.new()
	UiKit.full_rect(root)
	root.offset_left = 30; root.offset_right = -30; root.offset_top = 22; root.offset_bottom = -20
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var top := HBoxContainer.new()
	var tv := VBoxContainer.new()
	tv.add_child(UiKit.label("ROOM BROWSER", 28, UiKit.ACCENT, true))
	_status = UiKit.label("", 14, UiKit.DIM)
	tv.add_child(_status)
	top.add_child(tv)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiKit.button("DISCONNECT", func(): app.leave_session(), 170))
	root.add_child(top)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	# ---- list + filters
	var lp := UiKit.panel()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lp.add_child(lv)
	lv.add_child(UiKit.header("Rooms"))
	var f: Dictionary = Settings.get_v("room_filters")
	var fr := HFlowContainer.new()
	fr.add_theme_constant_override("h_separation", 10)
	_search = LineEdit.new()
	_search.placeholder_text = "Search room or leader..."
	_search.text = f.get("search", "")
	_search.custom_minimum_size = Vector2(260, 40)
	_search.text_changed.connect(func(_t): _apply_filters())
	fr.add_child(_search)
	_mission = OptionButton.new()
	_mission.add_item("Any operation")
	_mission.set_item_metadata(0, "")
	var i := 1
	for id in ["op01", "op02", "op03", "op04", "op05", "op06", "op07"]:
		var m := GameData.mission(id)
		if m.get("playable", false):
			_mission.add_item("%s %s" % [m["code"], m["name"]])
			_mission.set_item_metadata(i, id)
			if f.get("mission", "") == id:
				_mission.select(i)
			i += 1
	_mission.item_selected.connect(func(_x): _apply_filters())
	fr.add_child(_mission)
	for c in [["not_full", "Not full"], ["has_players", "Has players"], ["no_password", "No password"], ["not_in_progress", "Not in mission"]]:
		var cb := CheckBox.new()
		cb.text = c[1]
		cb.button_pressed = f.get(c[0], false)
		cb.toggled.connect(func(_b): _apply_filters())
		_checks[c[0]] = cb
		fr.add_child(cb)
	fr.add_child(UiKit.button("REFRESH", func(): _request(), 130))
	lv.add_child(fr)
	var hdr := HBoxContainer.new()
	for h in [["", 30], ["ROOM", 300], ["OPERATION", 230], ["PLAYERS", 100], ["STATUS", 130], ["LEADER", 160]]:
		var l := UiKit.label(h[0], 12, UiKit.ACCENT, true)
		l.custom_minimum_size.x = h[1]
		hdr.add_child(l)
	lv.add_child(hdr)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	lv.add_child(scroll)
	cols.add_child(lp)
	# ---- create room
	var cp := UiKit.panel(Vector2(380, 0))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cp.add_child(cv)
	cv.add_child(UiKit.header("Create room"))
	cv.add_child(UiKit.label("Room name", 14, UiKit.DIM))
	_create["name"] = LineEdit.new()
	_create["name"].max_length = 32
	_create["name"].placeholder_text = "%s's squad" % Settings.get_v("player_name")
	cv.add_child(_create["name"])
	cv.add_child(UiKit.label("Password (optional)", 14, UiKit.DIM))
	_create["password"] = LineEdit.new()
	_create["password"].secret = true
	_create["password"].max_length = 32
	cv.add_child(_create["password"])
	cv.add_child(UiKit.label("Max operators", 14, UiKit.DIM))
	_create["max"] = SpinBox.new()
	_create["max"].min_value = 1
	_create["max"].max_value = 4
	_create["max"].value = 4
	cv.add_child(_create["max"])
	cv.add_child(UiKit.button("CREATE ROOM", func():
		var mid: String = _mission.get_item_metadata(_mission.selected) if _mission.selected > 0 else "op01"
		Session.request_create_room(_create["name"].text, _create["password"].text, int(_create["max"].value), mid), 340))
	cols.add_child(cp)
	# ---- password prompt
	_pw_box = UiKit.panel(Vector2(420, 0))
	_pw_box.set_anchors_preset(Control.PRESET_CENTER)
	_pw_box.position = Vector2(-210, -90)
	var pv := VBoxContainer.new()
	_pw_box.add_child(pv)
	pv.add_child(UiKit.header("Room password"))
	_pw_edit = LineEdit.new()
	_pw_edit.secret = true
	_pw_edit.text_submitted.connect(func(_t): _submit_password())
	pv.add_child(_pw_edit)
	var pb := HBoxContainer.new()
	pb.add_child(UiKit.button("JOIN", func(): _submit_password(), 180))
	pb.add_child(UiKit.button("CANCEL", func(): _pw_box.visible = false, 180))
	pv.add_child(pb)
	_pw_box.visible = false
	add_child(_pw_box)
	Session.room_list_received.connect(_on_list)
	_request()

func filters() -> Dictionary:
	var f := {"search": _search.text, "mission": _mission.get_item_metadata(_mission.selected) if _mission.selected > 0 else ""}
	for k in _checks:
		f[k] = _checks[k].button_pressed
	return f

func _apply_filters() -> void:
	Settings.set_v("room_filters", filters())
	_request()

func _request() -> void:
	_timer = 0.0
	Session.request_rooms(filters())

func _process(dt: float) -> void:
	_timer += dt
	if _timer > 5.0:
		_request()

func _on_list(list: Array, info: Dictionary) -> void:
	if not is_inside_tree():
		return
	_status.text = "%s  ·  %d/%d players online  ·  %d/%d rooms" % [info.get("name", ""), info.get("players", 0), info.get("max_players", 0), info.get("rooms", 0), info.get("max_rooms", 0)]
	for c in _rows.get_children():
		c.queue_free()
	if list.is_empty():
		_rows.add_child(UiKit.label("No rooms match the filters. Create one →", 16, UiKit.DIM))
	for r in list:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 40
		var full: bool = r["players"] >= r["max"]
		var lock := UiKit.icon(UiKit.ICON_LOCK, 20, UiKit.ACCENT) if r["locked"] else Control.new()
		lock.custom_minimum_size = Vector2(30, 20)
		row.add_child(lock)
		for c in [[r["name"], 300], [r["mission_name"], 230], ["%d / %d" % [r["players"], r["max"]], 100],
				["IN MISSION" if r["phase"] != "lobby" else "LOBBY", 130], [r["leader"], 160]]:
			var l := UiKit.label(str(c[0]), 15, UiKit.DIM if full else UiKit.TEXT)
			l.custom_minimum_size.x = c[1]
			l.clip_text = true
			row.add_child(l)
		var b := UiKit.button("FULL" if full else "JOIN", func(): _join(r), 110)
		b.disabled = full
		row.add_child(b)
		_rows.add_child(row)

func _join(r: Dictionary) -> void:
	if r["locked"]:
		_pw_room = r["id"]
		_pw_edit.text = ""
		_pw_box.visible = true
		_pw_edit.grab_focus()
	else:
		Session.request_join_room(r["id"], "")

func _submit_password() -> void:
	_pw_box.visible = false
	Session.request_join_room(_pw_room, _pw_edit.text)

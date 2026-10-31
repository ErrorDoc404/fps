extends PanelContainer
## Server browser (CS:GO style): Favorites / History tabs, live status + ping via each server's /status.json,
## add by address, connect. Rooms on the chosen server are browsed after connecting (RoomBrowser).

var app: Node
var _tab := "favorites"
var _rows: VBoxContainer
var _addr: LineEdit
var _tab_btns := {}
var _info := {}        # address -> {status, ping, ok}

func _init(a: Node) -> void:
	app = a

func _ready() -> void:
	custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiKit.header("Server browser"))
	var tabs := HBoxContainer.new()
	for t in [["favorites", "FAVORITES"], ["history", "HISTORY"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(160, 40)
		b.pressed.connect(func(): _set_tab(t[0]))
		tabs.add_child(b)
		_tab_btns[t[0]] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	tabs.add_child(UiKit.button("REFRESH", func(): _refresh(), 140))
	v.add_child(tabs)
	var hdr := HBoxContainer.new()
	for h in [["SERVER", 260], ["ADDRESS", 170], ["ROOMS", 80], ["PLAYERS", 90], ["PING", 70]]:
		var l := UiKit.label(h[0], 12, UiKit.ACCENT, true)
		l.custom_minimum_size.x = h[1]
		hdr.add_child(l)
	v.add_child(hdr)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(740, 300)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	v.add_child(scroll)
	var add := HBoxContainer.new()
	add.add_theme_constant_override("separation", 8)
	_addr = LineEdit.new()
	_addr.placeholder_text = "host:port   e.g. 203.0.113.7:7777"
	_addr.text = Settings.get_v("last_server")
	_addr.custom_minimum_size = Vector2(330, 44)
	add.add_child(_addr)
	add.add_child(UiKit.button("ADD FAVORITE", func(): _add_favorite(_addr.text.strip_edges()), 180))
	add.add_child(UiKit.button("CONNECT", func(): app.join(_addr.text.strip_edges()), 160))
	v.add_child(add)
	v.add_child(UiKit.label("Status and ping come from each server's web port (TCP, same number as the game port by default).", 12, UiKit.DIM))
	_set_tab("favorites" if not Settings.get_v("favorites").is_empty() else "history")

func _set_tab(t: String) -> void:
	_tab = t
	for k in _tab_btns:
		_tab_btns[k].button_pressed = k == t
	_refresh()

func _list() -> Array:
	return Settings.get_v(_tab).duplicate()

func _add_favorite(addr: String) -> void:
	if addr == "" or not addr.contains(":"):
		app.toast("Enter host:port")
		return
	var favs: Array = Settings.get_v("favorites").duplicate()
	if not favs.has(addr):
		favs.append(addr)
		Settings.set_v("favorites", favs)
	_set_tab("favorites")

func _remove(addr: String) -> void:
	var l: Array = Settings.get_v(_tab).duplicate()
	l.erase(addr)
	Settings.set_v(_tab, l)
	_refresh()

func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var list := _list()
	if list.is_empty():
		_rows.add_child(UiKit.label("No servers here yet. Add one by address below." if _tab == "favorites" else "Servers you join appear here.", 15, UiKit.DIM))
	for addr in list:
		_rows.add_child(_row(addr))
		_query(addr)

func _row(addr: String) -> Control:
	var row := HBoxContainer.new()
	row.name = addr.validate_node_name()
	row.custom_minimum_size.y = 40
	var info: Dictionary = _info.get(addr, {})
	var st: Dictionary = info.get("status", {})
	var cols := [[st.get("name", "querying..." if info.is_empty() else "no response"), 260], [addr, 170],
		["%s/%s" % [st.get("rooms", "-"), st.get("max_rooms", "-")], 80], ["%s/%s" % [st.get("players", "-"), st.get("max_players", "-")], 90],
		["%d ms" % info["ping"] if info.get("ok", false) else "-", 70]]
	for c in cols:
		var l := UiKit.label(str(c[0]), 15, UiKit.TEXT if info.get("ok", false) else UiKit.DIM)
		l.custom_minimum_size.x = c[1]
		l.clip_text = true
		row.add_child(l)
	if info.get("ok", false) and st.get("protocol", Net.PROTOCOL_VERSION) != Net.PROTOCOL_VERSION:
		row.add_child(UiKit.label("VERSION MISMATCH", 12, UiKit.BAD, true))
	row.add_child(UiKit.button("JOIN", func(): app.join(addr), 90))
	row.add_child(UiKit.button("✕", func(): _remove(addr), 44))
	return row

func _query(addr: String) -> void:
	var req := HTTPRequest.new()
	req.timeout = 3.0
	add_child(req)
	var t0 := Time.get_ticks_msec()
	req.request_completed.connect(func(result, code, _h, body):
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code == 200
		var st: Variant = JSON.parse_string(body.get_string_from_utf8()) if ok else null
		_info[addr] = {"ok": ok and st is Dictionary, "status": st if st is Dictionary else {}, "ping": Time.get_ticks_msec() - t0}
		req.queue_free()
		var old := _rows.get_node_or_null(addr.validate_node_name())
		if old:
			var idx := old.get_index()
			old.queue_free()
			var nr := _row(addr)
			_rows.add_child(nr)
			_rows.move_child(nr, idx))
	req.request("http://%s/status.json" % addr)

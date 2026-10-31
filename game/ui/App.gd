extends Node
## Client application root: screen routing between main menu, HQ lobby, mission and results.

var ui: CanvasLayer
var screen: Control
var world: Node3D
var hud: Control
var pause_menu: Control
var _connecting_solo := false
var _solo_attempts := 0
var _solo_port := 0
var _toast: Label
var _holder: Node

func _ready() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_toast = UiKit.label("", 18, UiKit.ACCENT)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position.y -= 80
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Session.welcomed.connect(_on_welcomed)
	Session.room_joined.connect(func(_s): show_lobby())
	Session.room_left.connect(func(r):
		_teardown_mission()
		show_rooms()
		toast(r))
	Session.notice.connect(func(t): toast(t))
	Session.kicked.connect(func(r): toast("Disconnected: " + r))
	Session.mission_loading.connect(_on_mission_loading)
	Session.results_received.connect(_on_results)
	Net.disconnected.connect(func(): _back_to_menu("Lost connection to server."))
	Net.connect_failed.connect(_on_connect_failed)
	get_tree().root.size_changed.connect(_apply_scale)
	show_menu()
	if Args.has("autotest"):
		var t := preload("res://tests/AutoTest.gd").new()
		t.name = "AutoTest"
		t.app = self
		add_child(t)

func _apply_scale() -> void:
	if hud:
		hud.scale = Vector2.ONE * float(Settings.get_v("hud_scale"))

func set_screen(c: Control) -> void:
	if screen:
		screen.queue_free()
	screen = c
	c.theme = UiKit.theme()
	ui.add_child(c)
	if _toast.get_parent():
		_toast.get_parent().remove_child(_toast)
	ui.add_child(_toast)

func toast(text: String, secs := 4.0) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

func show_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_screen(preload("res://ui/MainMenu.gd").new(self))

func _on_welcomed(_p: Dictionary) -> void:
	if _connecting_solo:
		_connecting_solo = false
		Session.request_create_room("%s's squad" % Settings.get_v("player_name"), "", 4, "op01")
	elif Args.has("autotest"):
		pass  # the test bot drives room selection
	else:
		show_rooms()

func show_rooms() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_screen(preload("res://ui/RoomBrowser.gd").new(self))

func show_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_screen(preload("res://ui/LobbyScreen.gd").new(self))

# ---------------------------------------------------------------- connection
func play_solo() -> void:
	_solo_port = 27000 + randi() % 2000
	if not Net.spawn_local_server(_solo_port):
		toast("Could not start local dedicated server.")
		return
	_connecting_solo = true
	_solo_attempts = 0
	toast("Starting local dedicated server...")
	get_tree().create_timer(1.0).timeout.connect(_try_solo_connect)

func _try_solo_connect() -> void:
	if not _connecting_solo:
		return
	_solo_attempts += 1
	Session.connect_to("127.0.0.1", _solo_port)

func join(address: String) -> void:
	var parts := address.split(":")
	var host := parts[0] if parts[0] != "" else "127.0.0.1"
	var port := int(parts[1]) if parts.size() > 1 else Net.DEFAULT_PORT
	var key := "%s:%d" % [host, port]
	Settings.set_v("last_server", key)
	var hist: Array = Settings.get_v("history").duplicate()
	hist.erase(key)
	hist.push_front(key)
	Settings.set_v("history", hist.slice(0, 20))
	toast("Connecting to %s:%d ..." % [host, port])
	if Session.connect_to(host, port) != OK:
		toast("Connection failed.")

func _on_connect_failed() -> void:
	if _connecting_solo and _solo_attempts < 15:
		get_tree().create_timer(0.7).timeout.connect(_try_solo_connect)
		return
	_connecting_solo = false
	toast("Could not reach the server.")

func leave_session() -> void:
	Net.leave()
	Net.kill_local_server()
	_back_to_menu("")

func _back_to_menu(msg: String) -> void:
	_teardown_mission()
	show_menu()
	if msg != "":
		toast(msg)

# ---------------------------------------------------------------- mission
func _on_mission_loading(mission_id: String, sid: String, rid: int) -> void:
	_teardown_mission()
	if screen:
		screen.queue_free()
		screen = null
	# Same node path as the room's World on the server so RPCs route: /root/Rooms/R<id>/World
	var rooms := get_node_or_null("/root/Rooms")
	if rooms == null:
		rooms = Node.new()
		rooms.name = "Rooms"
		get_tree().root.add_child(rooms)
	_holder = Node.new()
	_holder.name = "R%d" % rid
	rooms.add_child(_holder)
	world = preload("res://world/World.gd").new()
	world.name = "World"
	_holder.add_child(world)
	Sfx.world_host = world
	world.setup_client(mission_id, sid)
	hud = preload("res://ui/Hud.gd").new(world)
	hud.theme = UiKit.theme()
	ui.add_child(hud)
	world.hud = hud
	_apply_scale()
	pause_menu = preload("res://ui/PauseMenu.gd").new(self)
	pause_menu.theme = UiKit.theme()
	pause_menu.visible = false
	ui.add_child(pause_menu)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _teardown_mission() -> void:
	# UI first: it reads the world (camera, players) every frame.
	for n in [hud, pause_menu]:
		if is_instance_valid(n):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = false
	Sfx.world_host = null
	if is_instance_valid(_holder):
		_holder.get_parent().remove_child(_holder)  # free the path immediately so a new mission can reuse it
		_holder.queue_free()
	_holder = null
	world = null
	for n in [hud, pause_menu]:
		if is_instance_valid(n):
			n.queue_free()
	hud = null
	pause_menu = null

func toggle_pause() -> void:
	if pause_menu == null:
		return
	pause_menu.visible = not pause_menu.visible
	world.ui_blocking = pause_menu.visible or (hud and hud.chat_open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_menu.visible else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if world and event.is_action_pressed("pause"):
		if hud and hud.chat_open:
			hud.close_chat()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()

func _on_results(results: Dictionary) -> void:
	_teardown_mission()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_screen(preload("res://ui/ResultsScreen.gd").new(self, results))

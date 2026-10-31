extends Node
## Dedicated server process (headless, Linux x86_64/ARM64). Hosts many rooms; each room is a squad of up to 4.
## Args: --port=7777 --data-dir=<path> --log-file=<path> --exit-when-empty --allow-test-commands --max-idle=<sec>
##       --name="My Server" --max-rooms=16 --max-players=64
##       --http-port=same|<port> (download website; default "same" = TCP on the game port number) --downloads-dir=<path> (default: <executable dir>/downloads) --no-web

var _empty_since := -1.0
var _had_players := false
var _status_t := 0.0
var _stopping := false

func _ready() -> void:
	Engine.max_fps = 60
	Geo.visuals = false   # dedicated server: colliders only, no meshes/materials/textures
	var port := Args.get_int("port", Net.DEFAULT_PORT)
	var data_dir := Args.get_value("data-dir", "user://server_data")
	Session.store = ProfileStore.new(data_dir)
	Session.server_name = Args.get_value("name", "Operation: Blackout Server").left(48)
	Session.max_rooms = clampi(Args.get_int("max-rooms", 16), 1, 256)
	if Net.host(port, clampi(Args.get_int("max-players", 64), 1, 1024)) != OK:
		Log.error("server", "startup failed; exiting")
		get_tree().quit(2)
		return
	Log.info("server", "Operation: Blackout dedicated server started", {"port": port, "version": ProjectSettings.get_setting("application/config/version"),
		"engine": Engine.get_version_info()["string"], "test_commands": Args.has("allow-test-commands"),
		"name": Session.server_name, "max_rooms": Session.max_rooms, "max_players": Net.max_clients})
	get_tree().auto_accept_quit = false
	if not Args.has("no-web"):
		var web := preload("res://server/WebPortal.gd").new()
		web.name = "WebPortal"
		add_child(web)
		var dl := Args.get_value("downloads-dir", OS.get_executable_path().get_base_dir().path_join("downloads"))
		var hp := Args.get_value("http-port", "same")
		web.start(port if hp in ["same", "0", ""] else int(hp), port, dl)  # game is UDP, so TCP can reuse the number

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		shutdown("close request")

func shutdown(reason: String) -> void:
	if _stopping:
		return
	_stopping = true
	Log.info("server", "graceful shutdown", {"reason": reason})
	for id in Session.authed.keys():
		Session.rpc_id(id, "s_kicked", "server shutting down")
	await get_tree().create_timer(0.3).timeout
	Net.leave()
	get_tree().quit(0)

func _process(dt: float) -> void:
	var n := Session.total_players()
	if n > 0:
		_had_players = true
		_empty_since = -1.0
	elif _empty_since < 0.0:
		_empty_since = Time.get_ticks_msec() / 1000.0
	var idle := Time.get_ticks_msec() / 1000.0 - _empty_since if _empty_since >= 0.0 else 0.0
	if Args.has("exit-when-empty") and _had_players and n == 0 and idle > 5.0:
		shutdown("squad empty")
	elif Args.has("max-idle") and n == 0 and idle > float(Args.get_value("max-idle")):
		shutdown("idle timeout")
	_status_t += dt
	if _status_t >= 30.0:
		_status_t = 0.0
		Log.info("health", "status", {"players": n, "rooms": Session.rooms.size(), "fps": Engine.get_frames_per_second(),
			"mem_mb": snapped(OS.get_static_memory_usage() / 1048576.0, 0.1), "objects": Performance.get_monitor(Performance.OBJECT_COUNT)})

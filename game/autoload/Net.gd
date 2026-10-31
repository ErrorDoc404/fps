extends Node
## Transport layer: owns the ENet peer for both dedicated server and client roles.
## Gameplay never talks to ENet directly; it uses Godot RPCs on Session / World nodes.

signal connected
signal connect_failed
signal disconnected
signal peer_joined(id: int)
signal peer_left(id: int)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 4
const PROTOCOL_VERSION := "blackout-0.1"

var role := "none"   # "server" | "client" | "none"
var server_process_pid := -1

func _ready() -> void:
	multiplayer.peer_connected.connect(func(id): peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id): peer_left.emit(id))
	multiplayer.connected_to_server.connect(func(): connected.emit())
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host(port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS + 2)  # +2 slack so full-squad rejections can be reported cleanly
	if err != OK:
		Log.error("net", "failed to bind server", {"port": port, "err": err})
		return err
	multiplayer.multiplayer_peer = peer
	role = "server"
	Log.info("net", "dedicated server listening", {"port": port})
	return OK

func join(address: String, port: int) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		Log.error("net", "failed to create client", {"address": address, "port": port, "err": err})
		return err
	multiplayer.multiplayer_peer = peer
	role = "client"
	Log.info("net", "connecting", {"address": address, "port": port})
	return OK

func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = "none"

func is_server() -> bool:
	return role == "server"

func is_client() -> bool:
	return role == "client"

func my_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 0

## Launches a local dedicated server process (same executable, headless) for solo / LAN-host play.
## Gameplay is still fully server-authoritative; the client simply connects to 127.0.0.1.
func spawn_local_server(port: int) -> bool:
	var args := PackedStringArray()
	if OS.has_feature("editor") or not OS.has_feature("template"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--headless", "--", "--server", "--port=%d" % port, "--exit-when-empty"])
	server_process_pid = OS.create_process(OS.get_executable_path(), args)
	Log.info("net", "spawned local dedicated server", {"pid": server_process_pid, "port": port})
	return server_process_pid > 0

func kill_local_server() -> void:
	if server_process_pid > 0:
		OS.kill(server_process_pid)
		server_process_pid = -1

func _on_connect_failed() -> void:
	Log.warn("net", "connection failed")
	leave()
	connect_failed.emit()

func _on_server_disconnected() -> void:
	Log.warn("net", "server disconnected")
	leave()
	disconnected.emit()

func _exit_tree() -> void:
	kill_local_server()

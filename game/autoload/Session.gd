extends Node
## Squad session: authentication handshake, squad lobby (membership, leader, classes, loadouts,
## readiness, mission selection), chat, and mission lifecycle. Server-authoritative; clients only send requests.
##
## Logical services from the spec collapsed into one process for the MVP:
## Authentication + Squad + Session allocation live here; Persistence is ProfileStore.

signal lobby_updated(state: Dictionary)
signal welcomed(profile: Dictionary)
signal profile_updated(profile: Dictionary)
signal chat_received(from_name: String, text: String)
signal mission_loading(mission_id: String, session_id: String)
signal results_received(results: Dictionary)
signal kicked(reason: String)

const MAX_SQUAD := 4
const AUTH_TIMEOUT := 10.0
const RECONNECT_GRACE := 120.0

# ---- server state ----
var store: ProfileStore
var members := {}          # peer_id -> member dict
var leader_peer := 0
var phase := "lobby"       # lobby | loading | active | results
var selected_mission := "op01"
var session_id := ""
var disconnected := {}     # profile_id -> {member, time} during an active mission (reconnection)
var limiter := RateLimiter.new()
var _pending_auth := {}    # peer_id -> deadline

# ---- client state ----
var lobby: Dictionary = {}
var my_profile: Dictionary = {}
var my_peer := 0
var _server_key := ""

func _ready() -> void:
	limiter.set_rule("chat", 5, 1.0)
	limiter.set_rule("lobby", 20, 5.0)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.connected.connect(_on_connected)

# =====================================================================
# Client API
# =====================================================================
func connect_to(address: String, port: int) -> Error:
	_server_key = "%s:%d" % [address, port]
	return Net.join(address, port)

func _on_connected() -> void:
	pass  # the server greets first with its realm id (s_realm), then we authenticate

## Server identity: secrets are stored per realm (persistent per server data dir), not per address/port.
@rpc("authority", "call_remote", "reliable")
func s_realm(realm_id: String) -> void:
	_server_key = "realm_" + realm_id.validate_filename()
	var secret := _load_secret(_server_key)
	rpc_id(1, "c_hello", Net.PROTOCOL_VERSION, Settings.get_v("profile_id"), secret, Settings.get_v("player_name"))

func request_class(cls: String) -> void: rpc_id(1, "c_set_class", cls)
func request_loadout(primary: String, secondary: String) -> void: rpc_id(1, "c_set_loadout", primary, secondary)
func request_set_ready(r: bool) -> void: rpc_id(1, "c_set_ready", r)
func request_mission(id: String) -> void: rpc_id(1, "c_select_mission", id)
func request_deploy() -> void: rpc_id(1, "c_deploy")
func request_kick(peer: int) -> void: rpc_id(1, "c_kick", peer)
func send_chat(text: String) -> void: rpc_id(1, "c_chat", text)

func me() -> Dictionary:
	return lobby.get("members", {}).get(str(my_peer), {})

func is_leader() -> bool:
	return lobby.get("leader", 0) == my_peer

func _auth_path() -> String:
	return Settings.PATH.replace("settings", "auth")

func _auth_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(_auth_path())
	return cfg

func _load_secret(key: String) -> String:
	return _auth_cfg().get_value("secrets", key, "")

func _store_secret(key: String, secret: String) -> void:
	var cfg := _auth_cfg()
	cfg.set_value("secrets", key, secret)
	cfg.save(_auth_path())

@rpc("authority", "call_remote", "reliable")
func s_welcome(peer_id: int, profile: Dictionary, new_secret: String) -> void:
	my_peer = peer_id
	my_profile = profile
	if new_secret != "":
		_store_secret(_server_key, new_secret)
	Log.info("session", "authenticated", {"peer": peer_id, "level": profile.get("level")})
	welcomed.emit(profile)

@rpc("authority", "call_remote", "reliable")
func s_lobby(state: Dictionary) -> void:
	lobby = state
	lobby_updated.emit(state)

@rpc("authority", "call_remote", "reliable")
func s_profile(profile: Dictionary) -> void:
	my_profile = profile
	profile_updated.emit(profile)

@rpc("authority", "call_remote", "reliable")
func s_chat(from_name: String, text: String) -> void:
	chat_received.emit(from_name, text)

@rpc("authority", "call_remote", "reliable")
func s_load_mission(mission_id: String, sid: String) -> void:
	Log.info("session", "server requested mission load", {"mission": mission_id})
	mission_loading.emit(mission_id, sid)

@rpc("authority", "call_remote", "reliable")
func s_results(results: Dictionary) -> void:
	results_received.emit(results)

@rpc("authority", "call_remote", "reliable")
func s_kicked(reason: String) -> void:
	Log.warn("session", "removed from session", {"reason": reason})
	kicked.emit(reason)

# =====================================================================
# Server
# =====================================================================
func _on_peer_joined(id: int) -> void:
	if not Net.is_server():
		return
	_pending_auth[id] = Time.get_ticks_msec() / 1000.0 + AUTH_TIMEOUT
	rpc_id(id, "s_realm", store.realm_id)
	Log.info("session", "peer connected, awaiting hello", {"peer": id})

func _process(_dt: float) -> void:
	if not Net.is_server() or _pending_auth.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for id in _pending_auth.keys():
		if now > _pending_auth[id]:
			_pending_auth.erase(id)
			_disconnect_peer(id, "authentication timeout")

func _disconnect_peer(id: int, reason: String) -> void:
	if multiplayer.get_peers().has(id):
		rpc_id(id, "s_kicked", reason)
	Log.info("session", "disconnecting peer", {"peer": id, "reason": reason})
	get_tree().create_timer(0.3).timeout.connect(func():
		if multiplayer.multiplayer_peer and multiplayer.get_peers().has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id))

func _sender() -> int:
	return multiplayer.get_remote_sender_id()

func _member_of(id: int) -> Dictionary:
	return members.get(id, {})

@rpc("any_peer", "call_remote", "reliable")
func c_hello(version: String, profile_id: String, secret: String, display_name: String) -> void:
	if not Net.is_server():
		return
	var id := _sender()
	if not _pending_auth.has(id):
		return  # duplicate hello
	_pending_auth.erase(id)
	if version != Net.PROTOCOL_VERSION:
		_disconnect_peer(id, "version mismatch (server %s)" % Net.PROTOCOL_VERSION)
		return
	display_name = display_name.strip_edges().left(24)
	if display_name == "":
		display_name = "Operator"
	for m in members.values():
		if m["profile_id"] == profile_id:
			_disconnect_peer(id, "profile already connected")
			return
	var reconnecting := disconnected.has(profile_id)
	if members.size() >= MAX_SQUAD and not reconnecting:
		_disconnect_peer(id, "squad is full")
		return
	var auth := store.authenticate(profile_id, secret, display_name)
	if not auth["ok"]:
		_disconnect_peer(id, auth.get("reason", "authentication failed"))
		return
	var prof: Dictionary = auth["profile"]
	var member: Dictionary
	if reconnecting:
		member = disconnected[profile_id]["member"]
		disconnected.erase(profile_id)
		member["connected"] = true
	else:
		var cls := "assault"
		var lo: Dictionary = prof.get("loadouts", {}).get(cls, {})
		member = {"profile_id": profile_id, "name": prof["name"], "class": cls,
			"primary": lo.get("primary", GameData.klass(cls)["default_primary"]),
			"secondary": lo.get("secondary", GameData.klass(cls)["default_secondary"]),
			"ready": false, "level": prof["level"], "connected": true, "slot": _free_slot()}
	members[id] = member
	if leader_peer == 0 or not members.has(leader_peer):
		leader_peer = id
	rpc_id(id, "s_welcome", id, ProfileStore.public_view(prof), auth["new_secret"])
	Log.info("session", "member joined", {"peer": id, "name": member["name"], "slot": member["slot"], "reconnect": reconnecting})
	broadcast_chat("", "%s joined the squad." % member["name"])
	_broadcast_lobby()
	if phase == "active" or phase == "loading":
		rpc_id(id, "s_load_mission", selected_mission, session_id)

func _free_slot() -> int:
	var used := []
	for m in members.values():
		used.append(m["slot"])
	for d in disconnected.values():
		used.append(d["member"]["slot"])
	for s in range(MAX_SQUAD):
		if not used.has(s):
			return s
	return -1

func _on_peer_left(id: int) -> void:
	if not Net.is_server():
		return
	_pending_auth.erase(id)
	limiter.forget(id)
	if not members.has(id):
		return
	var m: Dictionary = members[id]
	members.erase(id)
	if phase == "active" or phase == "loading":
		m["connected"] = false
		disconnected[m["profile_id"]] = {"member": m, "time": Time.get_ticks_msec() / 1000.0}
		var world := get_node_or_null("/root/World")
		if world:
			world.on_member_disconnected(m["slot"])
	if leader_peer == id:
		leader_peer = members.keys()[0] if not members.is_empty() else 0
		if leader_peer != 0:
			broadcast_chat("", "%s is now squad leader." % members[leader_peer]["name"])
	Log.info("session", "member left", {"peer": id, "name": m["name"], "phase": phase})
	broadcast_chat("", "%s left the squad." % m["name"])
	_broadcast_lobby()

func peer_for_slot(slot: int) -> int:
	for id in members:
		if members[id]["slot"] == slot:
			return id
	return 0

func lobby_state() -> Dictionary:
	var ms := {}
	for id in members:
		ms[str(id)] = members[id].duplicate()
		ms[str(id)].erase("profile_id")
	return {"members": ms, "leader": leader_peer, "phase": phase, "mission": selected_mission}

func _broadcast_lobby() -> void:
	var st := lobby_state()
	for id in members:
		rpc_id(id, "s_lobby", st)

func broadcast_chat(from_name: String, text: String) -> void:
	for id in members:
		rpc_id(id, "s_chat", from_name, text)

@rpc("any_peer", "call_remote", "reliable")
func c_set_class(cls: String) -> void:
	var id := _sender()
	var m := _member_of(id)
	if m.is_empty() or phase != "lobby" or not limiter.allow(id, "lobby") or GameData.klass(cls).is_empty():
		return
	m["class"] = cls
	var prof := store.load_profile(m["profile_id"])
	var lo: Dictionary = prof.get("loadouts", {}).get(cls, {})
	var c := GameData.klass(cls)
	m["primary"] = lo.get("primary", c["default_primary"])
	m["secondary"] = lo.get("secondary", c["default_secondary"])
	if not validate_loadout(m, prof):
		m["primary"] = c["default_primary"]
		m["secondary"] = c["default_secondary"]
	m["ready"] = false
	_broadcast_lobby()

## Server-side loadout validation: ownership (unlock level / purchases), slot and class restrictions.
func validate_loadout(m: Dictionary, prof: Dictionary) -> bool:
	var c := GameData.klass(m["class"])
	var lvl := int(prof.get("level", 1))
	var purchased: Array = prof.get("purchased", [])
	for key in ["primary", "secondary"]:
		var w := GameData.weapon(m[key])
		if w.is_empty() or w["slot"] != key or not c["allowed_categories"].has(w["category"]):
			return false
		if not GameData.is_unlocked(m[key], lvl, purchased):
			return false
	return true

@rpc("any_peer", "call_remote", "reliable")
func c_set_loadout(primary: String, secondary: String) -> void:
	var id := _sender()
	var m := _member_of(id)
	if m.is_empty() or phase != "lobby" or not limiter.allow(id, "lobby"):
		return
	var trial := m.duplicate()
	trial["primary"] = primary
	trial["secondary"] = secondary
	var prof := store.load_profile(m["profile_id"])
	if not validate_loadout(trial, prof):
		rpc_id(id, "s_chat", "", "Loadout rejected: item locked or not allowed for class.")
		_broadcast_lobby()
		return
	m["primary"] = primary
	m["secondary"] = secondary
	prof["loadouts"][m["class"]] = {"primary": primary, "secondary": secondary}
	store.save(prof)
	rpc_id(id, "s_profile", ProfileStore.public_view(prof))
	_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable")
func c_set_ready(r: bool) -> void:
	var id := _sender()
	var m := _member_of(id)
	if m.is_empty() or phase != "lobby" or not limiter.allow(id, "lobby"):
		return
	m["ready"] = r
	_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable")
func c_select_mission(mission_id: String) -> void:
	var id := _sender()
	if id != leader_peer or phase != "lobby":
		return
	var md := GameData.mission(mission_id)
	if md.is_empty() or not md.get("playable", false):
		rpc_id(id, "s_chat", "", "Operation %s is not available yet." % mission_id)
		return
	selected_mission = mission_id
	_broadcast_lobby()

@rpc("any_peer", "call_remote", "reliable")
func c_kick(peer: int) -> void:
	if _sender() != leader_peer or peer == leader_peer or not members.has(peer) or phase != "lobby":
		return
	_disconnect_peer(peer, "removed by squad leader")

@rpc("any_peer", "call_remote", "reliable")
func c_deploy() -> void:
	var id := _sender()
	if id != leader_peer or phase != "lobby":
		return
	for m in members.values():
		if not m["ready"]:
			rpc_id(id, "s_chat", "", "All operators must be ready to deploy.")
			return
	start_mission()

@rpc("any_peer", "call_remote", "reliable")
func c_chat(text: String) -> void:
	var id := _sender()
	var m := _member_of(id)
	if m.is_empty() or not limiter.allow(id, "chat"):
		return
	text = text.strip_edges().left(200)
	if text != "":
		broadcast_chat(m["name"], text)

func start_mission() -> void:
	phase = "loading"
	session_id = Crypto.new().generate_random_bytes(8).hex_encode()
	Log.info("session", "mission deploying", {"mission": selected_mission, "session": session_id, "squad": members.size()})
	var world_script := load("res://world/World.gd")
	var world: Node = world_script.new()
	world.name = "World"
	get_tree().root.add_child(world)
	world.setup(selected_mission, session_id)
	phase = "active"
	_broadcast_lobby()
	for id in members:
		rpc_id(id, "s_load_mission", selected_mission, session_id)

## Called by the MissionDirector when the mission ends. `per_slot` contains validated per-player results.
func finish_mission(summary: Dictionary, per_slot: Dictionary) -> void:
	phase = "results"
	var world := get_node_or_null("/root/World")
	if world:
		world.stop_replication()
	for id in members:
		var m: Dictionary = members[id]
		var r: Dictionary = per_slot.get(m["slot"], {"xp": 0, "credits": 0})
		var prof := store.grant_rewards(m["profile_id"], session_id, selected_mission, summary["result"], r["xp"], r["credits"])
		var out := summary.duplicate(true)
		out["you"] = r
		if not prof.is_empty():
			m["level"] = prof["level"]
			out["profile"] = ProfileStore.public_view(prof)
			rpc_id(id, "s_profile", out["profile"])
		rpc_id(id, "s_results", out)
	disconnected.clear()
	get_tree().create_timer(1.0).timeout.connect(_return_to_lobby)

func _return_to_lobby() -> void:
	var world := get_node_or_null("/root/World")
	if world:
		world.queue_free()
	phase = "lobby"
	for m in members.values():
		m["ready"] = false
	_broadcast_lobby()
	Log.info("session", "returned to lobby")

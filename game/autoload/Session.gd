extends Node
## Dedicated-server session layer: authentication, the room browser, and every room's squad lobby
## (membership, leader, classes, loadouts, readiness, mission selection), plus chat and the mission lifecycle.
## One server process hosts many rooms; each room holds up to 4 operators and runs its own isolated mission World.
## Server-authoritative: clients only send requests.

signal welcomed(profile: Dictionary)
signal room_list_received(rooms: Array, info: Dictionary)
signal room_joined(state: Dictionary)
signal room_left(reason: String)
signal lobby_updated(state: Dictionary)
signal profile_updated(profile: Dictionary)
signal chat_received(from_name: String, text: String)
signal notice(text: String)
signal mission_loading(mission_id: String, session_id: String, room_id: int)
signal results_received(results: Dictionary)
signal kicked(reason: String)

const MAX_SQUAD := 4
const AUTH_TIMEOUT := 10.0

# ---- server state ----
var store: ProfileStore
var server_name := "Operation: Blackout Server"
var max_rooms := 16
var rooms := {}            # room id -> Room
var peer_room := {}        # peer id -> room id
var authed := {}           # peer id -> {profile_id, name, level}
var limiter := RateLimiter.new()
var _pending_auth := {}    # peer id -> deadline
var _next_room_id := 1

# ---- client state ----
var lobby: Dictionary = {}
var my_profile: Dictionary = {}
var my_peer := 0
var room_id := 0
var _server_key := ""

func _ready() -> void:
	limiter.set_rule("chat", 5, 1.0)
	limiter.set_rule("lobby", 20, 5.0)
	limiter.set_rule("browse", 10, 2.0)
	limiter.set_rule("join", 6, 0.5)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.disconnected.connect(_reset_client)

# =====================================================================
# Client API
# =====================================================================
func connect_to(address: String, port: int) -> Error:
	_reset_client()
	return Net.join(address, port)

func _reset_client() -> void:
	lobby = {}
	room_id = 0

func request_rooms(filters: Dictionary) -> void: rpc_id(1, "c_list_rooms", filters)
func request_create_room(room_name: String, password: String, max_players: int, mission: String) -> void:
	rpc_id(1, "c_create_room", room_name, password, max_players, mission)
func request_join_room(id: int, password: String) -> void: rpc_id(1, "c_join_room", id, password)
func request_leave_room() -> void: rpc_id(1, "c_leave_room")
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

## Server identity: secrets are stored per realm (persistent per server data dir), not per address/port.
@rpc("authority", "call_remote", "reliable")
func s_realm(realm_id: String) -> void:
	_server_key = "realm_" + realm_id.validate_filename()
	var secret := _load_secret(_server_key)
	rpc_id(1, "c_hello", Net.PROTOCOL_VERSION, Settings.get_v("profile_id"), secret, Settings.get_v("player_name"))

@rpc("authority", "call_remote", "reliable")
func s_welcome(peer_id: int, profile: Dictionary, new_secret: String) -> void:
	my_peer = peer_id
	my_profile = profile
	if new_secret != "":
		_store_secret(_server_key, new_secret)
	Log.info("session", "authenticated", {"peer": peer_id, "level": profile.get("level")})
	welcomed.emit(profile)

@rpc("authority", "call_remote", "reliable")
func s_room_list(list: Array, info: Dictionary) -> void:
	room_list_received.emit(list, info)

@rpc("authority", "call_remote", "reliable")
func s_room_joined(id: int, state: Dictionary) -> void:
	room_id = id
	lobby = state
	Log.info("session", "joined room", {"room": id, "name": state.get("room", {}).get("name", "")})
	room_joined.emit(state)

@rpc("authority", "call_remote", "reliable")
func s_room_left(reason: String) -> void:
	room_id = 0
	lobby = {}
	room_left.emit(reason)

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
func s_notice(text: String) -> void:
	notice.emit(text)

@rpc("authority", "call_remote", "reliable")
func s_load_mission(mission_id: String, sid: String, rid: int) -> void:
	Log.info("session", "server requested mission load", {"mission": mission_id, "room": rid})
	room_id = rid
	mission_loading.emit(mission_id, sid, rid)

@rpc("authority", "call_remote", "reliable")
func s_results(results: Dictionary) -> void:
	results_received.emit(results)

@rpc("authority", "call_remote", "reliable")
func s_kicked(reason: String) -> void:
	Log.warn("session", "removed from server", {"reason": reason})
	kicked.emit(reason)

# =====================================================================
# Server: connection + authentication
# =====================================================================
func _on_peer_joined(id: int) -> void:
	if not Net.is_server():
		return
	_pending_auth[id] = Time.get_ticks_msec() / 1000.0 + AUTH_TIMEOUT
	rpc_id(id, "s_realm", store.realm_id)

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

func total_players() -> int:
	return authed.size()

@rpc("any_peer", "call_remote", "reliable")
func c_hello(version: String, profile_id: String, secret: String, display_name: String) -> void:
	if not Net.is_server():
		return
	var id := _sender()
	if not _pending_auth.has(id):
		return
	_pending_auth.erase(id)
	if version != Net.PROTOCOL_VERSION:
		_disconnect_peer(id, "version mismatch (server %s)" % Net.PROTOCOL_VERSION)
		return
	display_name = display_name.strip_edges().left(24)
	if display_name == "":
		display_name = "Operator"
	for a in authed.values():
		if a["profile_id"] == profile_id:
			_disconnect_peer(id, "profile already connected")
			return
	var auth := store.authenticate(profile_id, secret, display_name)
	if not auth["ok"]:
		_disconnect_peer(id, auth.get("reason", "authentication failed"))
		return
	var prof: Dictionary = auth["profile"]
	authed[id] = {"profile_id": profile_id, "name": prof["name"], "level": prof["level"]}
	rpc_id(id, "s_welcome", id, ProfileStore.public_view(prof), auth["new_secret"])
	Log.info("session", "player authenticated", {"peer": id, "name": prof["name"], "online": authed.size()})
	# Reconnection: return the operator to the room that is holding their slot.
	for room in rooms.values():
		if room.disconnected.has(profile_id):
			var member: Dictionary = room.disconnected[profile_id]["member"]
			room.disconnected.erase(profile_id)
			member["connected"] = true
			_add_to_room(room, id, member)
			return

func _on_peer_left(id: int) -> void:
	if not Net.is_server():
		return
	_pending_auth.erase(id)
	limiter.forget(id)
	_remove_from_room(id, true)
	authed.erase(id)

# =====================================================================
# Server: room browser
# =====================================================================
@rpc("any_peer", "call_remote", "reliable")
func c_list_rooms(filters: Dictionary) -> void:
	var id := _sender()
	if not authed.has(id) or not limiter.allow(id, "browse"):
		return
	var search := String(filters.get("search", "")).strip_edges().to_lower().left(32)
	var mission := String(filters.get("mission", ""))
	var out := []
	for room in rooms.values():
		var s: Dictionary = room.summary()
		if search != "" and not (s["name"].to_lower().contains(search) or s["leader"].to_lower().contains(search)):
			continue
		if mission != "" and s["mission"] != mission:
			continue
		if filters.get("not_full", false) and room.is_full():
			continue
		if filters.get("has_players", false) and s["players"] == 0:
			continue
		if filters.get("no_password", false) and s["locked"]:
			continue
		if filters.get("not_in_progress", false) and s["phase"] != "lobby":
			continue
		out.append(s)
	out.sort_custom(func(a, b): return a["players"] > b["players"] if a["players"] != b["players"] else a["name"] < b["name"])
	rpc_id(id, "s_room_list", out.slice(0, 100), server_info())

func server_info() -> Dictionary:
	return {"name": server_name, "rooms": rooms.size(), "max_rooms": max_rooms, "players": authed.size(),
		"max_players": Net.max_clients, "version": ProjectSettings.get_setting("application/config/version")}

@rpc("any_peer", "call_remote", "reliable")
func c_create_room(room_name: String, password: String, max_players: int, mission: String) -> void:
	var id := _sender()
	if not authed.has(id) or peer_room.has(id) or not limiter.allow(id, "join"):
		return
	if rooms.size() >= max_rooms:
		rpc_id(id, "s_notice", "Server room limit reached (%d). Join an existing room or try another server." % max_rooms)
		return
	var room := Room.new()
	room.id = _next_room_id
	_next_room_id += 1
	room.name = room_name.strip_edges().left(32)
	if room.name == "":
		room.name = "%s's squad" % authed[id]["name"]
	if password != "":
		room.password_hash = (str(room.id) + ":" + password.left(32)).sha256_text()
	room.max_players = clampi(max_players, 1, MAX_SQUAD)
	var md := GameData.mission(mission)
	room.selected_mission = mission if md.get("playable", false) else "op01"
	room.created_at = Time.get_ticks_msec() / 1000.0
	rooms[room.id] = room
	Log.info("room", "room created", {"room": room.id, "name": room.name, "locked": room.locked(), "max": room.max_players, "rooms": rooms.size()})
	_join_room(room, id)

@rpc("any_peer", "call_remote", "reliable")
func c_join_room(rid: int, password: String) -> void:
	var id := _sender()
	if not authed.has(id) or peer_room.has(id) or not limiter.allow(id, "join"):
		return
	var room: Room = rooms.get(rid)
	if room == null:
		rpc_id(id, "s_notice", "That room no longer exists.")
		return
	if room.is_full():
		rpc_id(id, "s_notice", "Room \"%s\" is full (%d/%d)." % [room.name, room.occupancy(), room.max_players])
		return
	if room.locked() and (str(room.id) + ":" + password.left(32)).sha256_text() != room.password_hash:
		Log.info("room", "wrong room password", {"room": rid, "peer": id})
		rpc_id(id, "s_notice", "Wrong password.")
		return
	_join_room(room, id)

func _join_room(room: Room, id: int) -> void:
	var a: Dictionary = authed[id]
	var prof := store.load_profile(a["profile_id"])
	var cls := "assault"
	var lo: Dictionary = prof.get("loadouts", {}).get(cls, {})
	var member := {"profile_id": a["profile_id"], "name": a["name"], "class": cls,
		"primary": lo.get("primary", GameData.klass(cls)["default_primary"]),
		"secondary": lo.get("secondary", GameData.klass(cls)["default_secondary"]),
		"ready": false, "level": prof.get("level", 1), "connected": true, "slot": room.free_slot()}
	_add_to_room(room, id, member)

func _add_to_room(room: Room, id: int, member: Dictionary) -> void:
	room.members[id] = member
	peer_room[id] = room.id
	if room.leader_peer == 0 or not room.members.has(room.leader_peer):
		room.leader_peer = id
	rpc_id(id, "s_room_joined", room.id, room.lobby_state())
	Log.info("room", "member joined", {"room": room.id, "peer": id, "name": member["name"], "slot": member["slot"]})
	_room_chat(room, "", "%s joined the squad." % member["name"])
	_broadcast_lobby(room)
	if room.phase == "active" or room.phase == "loading":
		rpc_id(id, "s_load_mission", room.selected_mission, room.session_id, room.id)

@rpc("any_peer", "call_remote", "reliable")
func c_leave_room() -> void:
	var id := _sender()
	if peer_room.has(id):
		_remove_from_room(id, false)
		rpc_id(id, "s_room_left", "You left the room.")

## Removes a peer from its room. `dropped` = connection lost (keeps the mission slot for reconnection).
func _remove_from_room(id: int, dropped: bool) -> void:
	if not peer_room.has(id):
		return
	var room: Room = rooms.get(peer_room[id])
	peer_room.erase(id)
	if room == null or not room.members.has(id):
		return
	var m: Dictionary = room.members[id]
	room.members.erase(id)
	var in_mission: bool = room.phase == "active" or room.phase == "loading"
	if in_mission and room.world:
		if dropped:
			m["connected"] = false
			room.disconnected[m["profile_id"]] = {"member": m, "time": Time.get_ticks_msec() / 1000.0}
		room.world.on_member_disconnected(m["slot"], not dropped)
	if room.leader_peer == id:
		room.leader_peer = room.members.keys()[0] if not room.members.is_empty() else 0
		if room.leader_peer != 0:
			_room_chat(room, "", "%s is now squad leader." % room.members[room.leader_peer]["name"])
	Log.info("room", "member left", {"room": room.id, "peer": id, "name": m["name"], "dropped": dropped})
	_room_chat(room, "", "%s left the squad." % m["name"])
	_broadcast_lobby(room)
	if room.members.is_empty() and not in_mission:
		_close_room(room)

func _close_room(room: Room) -> void:
	if room.holder:
		room.holder.queue_free()
	rooms.erase(room.id)
	Log.info("room", "room closed", {"room": room.id, "rooms": rooms.size()})

func room_of(peer: int) -> Room:
	return rooms.get(peer_room.get(peer, -1))

func _broadcast_lobby(room: Room) -> void:
	var st := room.lobby_state()
	for pid in room.members:
		rpc_id(pid, "s_lobby", st)

func _room_chat(room: Room, from_name: String, text: String) -> void:
	for pid in room.members:
		rpc_id(pid, "s_chat", from_name, text)

func _member(id: int) -> Dictionary:
	var room := room_of(id)
	return room.members.get(id, {}) if room else {}

# =====================================================================
# Server: squad lobby (per room)
# =====================================================================
@rpc("any_peer", "call_remote", "reliable")
func c_set_class(cls: String) -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or room.phase != "lobby" or not limiter.allow(id, "lobby") or GameData.klass(cls).is_empty():
		return
	var m: Dictionary = room.members[id]
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
	_broadcast_lobby(room)

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
	var room := room_of(id)
	if room == null or room.phase != "lobby" or not limiter.allow(id, "lobby"):
		return
	var m: Dictionary = room.members[id]
	var trial := m.duplicate()
	trial["primary"] = primary
	trial["secondary"] = secondary
	var prof := store.load_profile(m["profile_id"])
	if not validate_loadout(trial, prof):
		rpc_id(id, "s_notice", "Loadout rejected: item locked or not allowed for class.")
		_broadcast_lobby(room)
		return
	m["primary"] = primary
	m["secondary"] = secondary
	prof["loadouts"][m["class"]] = {"primary": primary, "secondary": secondary}
	store.save(prof)
	rpc_id(id, "s_profile", ProfileStore.public_view(prof))
	_broadcast_lobby(room)

@rpc("any_peer", "call_remote", "reliable")
func c_set_ready(r: bool) -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or room.phase != "lobby" or not limiter.allow(id, "lobby"):
		return
	room.members[id]["ready"] = r
	_broadcast_lobby(room)

@rpc("any_peer", "call_remote", "reliable")
func c_select_mission(mission_id: String) -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or id != room.leader_peer or room.phase != "lobby":
		return
	if not GameData.mission(mission_id).get("playable", false):
		rpc_id(id, "s_notice", "Operation %s is not available yet." % mission_id)
		return
	room.selected_mission = mission_id
	_broadcast_lobby(room)

@rpc("any_peer", "call_remote", "reliable")
func c_kick(peer: int) -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or id != room.leader_peer or peer == id or not room.members.has(peer) or room.phase != "lobby":
		return
	_remove_from_room(peer, false)
	rpc_id(peer, "s_room_left", "Removed by the squad leader.")

@rpc("any_peer", "call_remote", "reliable")
func c_deploy() -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or id != room.leader_peer or room.phase != "lobby":
		return
	for m in room.members.values():
		if not m["ready"]:
			rpc_id(id, "s_notice", "All operators must be ready to deploy.")
			return
	start_mission(room)

@rpc("any_peer", "call_remote", "reliable")
func c_chat(text: String) -> void:
	var id := _sender()
	var room := room_of(id)
	if room == null or not limiter.allow(id, "chat"):
		return
	text = text.strip_edges().left(200)
	if text != "":
		_room_chat(room, room.members[id]["name"], text)

# =====================================================================
# Server: mission lifecycle (per room, isolated World3D)
# =====================================================================
func _rooms_root() -> Node:
	var r := get_node_or_null("/root/Rooms")
	if r == null:
		r = Node.new()
		r.name = "Rooms"
		get_tree().root.add_child(r)
	return r

func start_mission(room: Room) -> void:
	room.phase = "loading"
	room.session_id = Crypto.new().generate_random_bytes(8).hex_encode()
	Log.info("room", "mission deploying", {"room": room.id, "mission": room.selected_mission, "session": room.session_id, "squad": room.members.size()})
	# Each room simulates in its own SubViewport/World3D: separate physics space and navigation map.
	var holder := SubViewport.new()
	holder.name = "R%d" % room.id
	holder.own_world_3d = true
	holder.size = Vector2i(2, 2)
	holder.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_rooms_root().add_child(holder)
	room.holder = holder
	var world: Node = load("res://world/World.gd").new()
	world.name = "World"
	holder.add_child(world)
	room.world = world
	world.setup(room, room.selected_mission, room.session_id)
	room.phase = "active"
	_broadcast_lobby(room)
	for pid in room.members:
		rpc_id(pid, "s_load_mission", room.selected_mission, room.session_id, room.id)

## Called by the room's MissionDirector when the mission ends. `per_slot` contains validated per-player results.
func finish_mission(room: Room, summary: Dictionary, per_slot: Dictionary) -> void:
	if not rooms.has(room.id):
		return
	room.phase = "results"
	if room.world:
		room.world.stop_replication()
	for pid in room.members:
		var m: Dictionary = room.members[pid]
		var r: Dictionary = per_slot.get(m["slot"], {"xp": 0, "credits": 0})
		var prof := store.grant_rewards(m["profile_id"], room.session_id, room.selected_mission, summary["result"], r["xp"], r["credits"])
		var out := summary.duplicate(true)
		out["you"] = r
		if not prof.is_empty():
			m["level"] = prof["level"]
			out["profile"] = ProfileStore.public_view(prof)
			rpc_id(pid, "s_profile", out["profile"])
		rpc_id(pid, "s_results", out)
	room.disconnected.clear()
	get_tree().create_timer(1.0).timeout.connect(func(): _return_to_lobby(room))

func _return_to_lobby(room: Room) -> void:
	if room.holder:
		room.holder.queue_free()
	room.holder = null
	room.world = null
	room.phase = "lobby"
	for m in room.members.values():
		m["ready"] = false
	_broadcast_lobby(room)
	Log.info("room", "returned to lobby", {"room": room.id})
	if room.members.is_empty():
		_close_room(room)

## Called by a World whose squad is gone for good.
func abandon_room(room: Room) -> void:
	if rooms.has(room.id) and room.members.is_empty():
		room.disconnected.clear()
		_return_to_lobby(room)

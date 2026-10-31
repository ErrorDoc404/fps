extends Node3D
## Mission world. Exists at /root/World on both the dedicated server and clients so RPC paths match.
## Server: authoritative simulation (players, AI, combat resolution, interactions, mission director).
## Client: presentation (map visuals, puppets, local prediction via LocalController, HUD, effects).

signal objectives_changed(state: Dictionary)
signal event_message(text: String, kind: String)
signal local_player_ready(p: Player)
signal mission_ended(results: Dictionary)

const SNAPSHOT_EVERY := 3   # physics ticks (60 Hz / 3 = 20 Hz)

var mission_id := ""
var mission: Dictionary
var session_id := ""
var map_info: Dictionary
var players := {}      # slot -> Player
var enemies := {}      # id -> Enemy
var smokes: Array = [] # [pos, radius, until]
var is_server := false
var ui_blocking := false
var mission_time := 0.0

# server
var director: MissionDirector
var equipment: EquipmentSystem
var _ready_peers := {}
var _tick := 0
var _next_enemy_id := 1
var _empty_t := 0.0
var _nav: NavigationRegion3D
var _fire_limiter := RateLimiter.new()

# client
var fx: Fx
var hud: Node
var local_player: Player
var objective_state := {}
var extraction := {"open": false, "progress": 0.0}
var _map_root: Node3D

# ======================================================================= setup
func _build_map(with_visuals: bool) -> void:
	_nav = NavigationRegion3D.new()
	_nav.name = "Nav"
	add_child(_nav)
	_map_root = Node3D.new()
	_map_root.name = "Map"
	_nav.add_child(_map_root)
	match mission.get("map", "industrial"):
		_:
			map_info = IndustrialMap.new().build(_map_root)
	for n in ["Players", "Enemies", "Projectiles"]:
		var c := Node3D.new()
		c.name = n
		add_child(c)
	if with_visuals:
		_environment()

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.38, 0.5)
	sm.sky_horizon_color = Color(0.85, 0.62, 0.45)
	sm.ground_bottom_color = Color(0.2, 0.18, 0.16)
	sm.ground_horizon_color = Color(0.6, 0.48, 0.38)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.55, 0.45)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -35, 0)
	sun.light_color = Color(1.0, 0.78, 0.58)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

func setup(mid: String, sid: String) -> void:
	is_server = true
	mission_id = mid
	session_id = sid
	mission = GameData.mission(mid)
	_fire_limiter.set_rule("fire", 25, 18.0)
	_fire_limiter.set_rule("action", 10, 4.0)
	_build_map(false)
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_radius = 0.4
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.5
	_nav.navigation_mesh = nm
	_nav.bake_navigation_mesh(false)
	Log.info("world", "navigation baked", {"polygons": nm.get_polygon_count()})
	equipment = EquipmentSystem.new(self)
	director = MissionDirector.new(self, mission)
	for id in Session.members:
		_create_player(Session.members[id], mission["spawn_points"][Session.members[id]["slot"]])
	spawn_group("initial")
	director.start()
	Log.info("world", "mission world ready", {"mission": mid, "players": players.size(), "enemies": enemies.size()})

func setup_client(mid: String, sid: String) -> void:
	mission_id = mid
	session_id = sid
	mission = GameData.mission(mid)
	_build_map(true)
	fx = Fx.new()
	fx.name = "Fx"
	add_child(fx)
	rpc_id(1, "c_world_ready")

# ======================================================================= server: players
func _create_player(member: Dictionary, spawn: Array) -> Player:
	var p := Player.new()
	p.name = "P%d" % member["slot"]
	p.world = self
	p.setup_server(member)
	$Players.add_child(p)
	p.global_position = Vector3(spawn[0], spawn[1] + 0.1, spawn[2])
	p.rotation.y = 0.0
	p.last_input["yaw"] = 0.0
	players[p.slot] = p
	return p

func _peer_slot(peer: int) -> int:
	return Session.members[peer]["slot"] if Session.members.has(peer) else -1

func _sender_player() -> Player:
	var slot := _peer_slot(multiplayer.get_remote_sender_id())
	return players.get(slot)

@rpc("any_peer", "call_remote", "reliable")
func c_world_ready() -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if not Session.members.has(peer):
		return
	var m: Dictionary = Session.members[peer]
	var p: Player = players.get(m["slot"])
	if p == null:
		p = _create_player(m, mission["spawn_points"][m["slot"]])
		for other in _ready_peers:
			rpc_id(other, "s_spawn_player", p.slot, p.display_name, p.class_id, p.global_position, p.rotation.y)
	p.connected = true
	_ready_peers[peer] = true
	for q in players.values():
		rpc_id(peer, "s_spawn_player", q.slot, q.display_name, q.class_id, q.global_position, q.rotation.y)
	for e in enemies.values():
		rpc_id(peer, "s_spawn_enemy", e.eid, e.type_id, e.global_position, e.rotation.y)
	rpc_id(peer, "s_you_are", p.slot)
	rpc_id(peer, "s_objectives", director.state_dict())
	for s in smokes:
		rpc_id(peer, "s_smoke", s[0], s[1], s[2] - mission_time)
	p.inventory.dirty = true
	Log.info("world", "peer in world", {"peer": peer, "slot": p.slot})

## Mission over: stop sending world RPCs so clients can tear down their world safely.
func stop_replication() -> void:
	_ready_peers.clear()
	set_physics_process(false)

func on_member_disconnected(slot: int) -> void:
	var p: Player = players.get(slot)
	if p:
		p.connected = false
		p.interact_progress = 0.0
	for peer in _ready_peers.keys():
		if not multiplayer.get_peers().has(peer):
			_ready_peers.erase(peer)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_input(seq: int, move: Vector2, yaw: float, pitch: float, buttons: int, stance: int) -> void:
	var p := _sender_player()
	if p == null or seq <= p.last_seq:
		return
	if not (is_finite(yaw) and is_finite(pitch) and is_finite(move.x) and is_finite(move.y)):
		return
	p.last_seq = seq
	p.input_queue.append({"move": move.limit_length(1.0), "yaw": wrapf(yaw, -PI, PI), "pitch": clampf(pitch, -1.45, 1.45), "buttons": buttons, "stance": stance})

@rpc("any_peer", "call_remote", "reliable")
func c_fire(yaw: float, pitch: float) -> void:
	var p := _sender_player()
	var peer := multiplayer.get_remote_sender_id()
	if p == null or not p.health.alive() or not _fire_limiter.allow(peer, "fire"):
		return
	var now := mission_time
	var inv := p.inventory
	if not inv.can_fire(now) or p.motor["sprinting"]:
		return
	if p.motor["since_sprint"] < float(GameData.player_rules["sprint_to_fire_delay"]) - 0.1:
		return
	inv.consume_round(now)
	var def := inv.def()
	var spread: float = def["spread_ads"] if p.motor["ads"] else def["spread_hip"]
	if Vector2(p.velocity.x, p.velocity.z).length() > 1.0:
		spread *= 1.5
	spread *= [1.0, 0.8, 0.6][int(p.motor["stance"])]
	if not p.is_on_floor():
		spread *= 2.5
	var basis := Basis.from_euler(Vector3(clampf(pitch, -1.45, 1.45), yaw, 0))
	var cone := deg_to_rad(spread) * sqrt(randf())
	var ang := randf() * TAU
	var dir := basis * Vector3(sin(cone) * cos(ang), sin(cone) * sin(ang), -cos(cone))
	var from := p.eye_position()
	var to := from + dir * float(def["range"])
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, [p.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if hit:
		end = hit["position"]
		var col: Object = hit["collider"]
		var dist := from.distance_to(end)
		var falloff := 1.0
		if dist > float(def["falloff_start"]):
			falloff = lerpf(1.0, float(def["falloff_min"]), clampf((dist - float(def["falloff_start"])) / (float(def["range"]) - float(def["falloff_start"])), 0.0, 1.0))
		var dmg: float = float(def["damage"]) * falloff
		if col is Enemy:
			var e: Enemy = col
			var head := end.y > e.global_position.y + 1.5 * float(e.def.get("scale", 1.0))
			if head:
				dmg *= float(GameData.player_rules["headshot_multiplier"])
			e.take_damage(dmg, p)
			rpc_id(peer, "s_hit", e.is_dead(), head)
		elif col is Player and GameData.player_rules.get("friendly_fire", false):
			damage_player(col, dmg, from)
			rpc_id(peer, "s_hit", false, false)
	for other in _ready_peers:
		if other != peer:
			rpc_id(other, "s_shot", 0, p.slot, from, end, def.get("sound", "rifle"))
	for e in enemies.values():
		e.hear(p.global_position, p, 1.0)

@rpc("any_peer", "call_remote", "reliable")
func c_reload() -> void:
	var p := _sender_player()
	if p and p.health.alive() and _fire_limiter.allow(multiplayer.get_remote_sender_id(), "action"):
		if p.inventory.start_reload():
			for other in _ready_peers:
				rpc_id(other, "s_sound3d", "reload", p.global_position + Vector3.UP)

@rpc("any_peer", "call_remote", "reliable")
func c_switch(idx: int) -> void:
	var p := _sender_player()
	if p and p.health.alive() and _fire_limiter.allow(multiplayer.get_remote_sender_id(), "action"):
		p.inventory.switch_to(idx)

@rpc("any_peer", "call_remote", "reliable")
func c_fire_mode() -> void:
	var p := _sender_player()
	if p and _fire_limiter.allow(multiplayer.get_remote_sender_id(), "action"):
		p.inventory.cycle_fire_mode()

@rpc("any_peer", "call_remote", "reliable")
func c_equipment(item: String, yaw: float, pitch: float) -> void:
	var p := _sender_player()
	if p and _fire_limiter.allow(multiplayer.get_remote_sender_id(), "action"):
		equipment.use(p, item, yaw, clampf(pitch, -1.45, 1.45))

## Debug/test hooks: only honoured when the server runs with --allow-test-commands.
@rpc("any_peer", "call_remote", "reliable")
func c_test(cmd: String, arg: Variant) -> void:
	if not Args.has("allow-test-commands"):
		return
	var p := _sender_player()
	if p == null:
		return
	Log.warn("test", "test command", {"cmd": cmd, "slot": p.slot})
	match cmd:
		"teleport": p.global_position = arg
		"damage_self":
			var was: bool = p.get_meta("invulnerable", false)
			p.set_meta("invulnerable", false)
			damage_player(p, float(arg), p.global_position + Vector3(0, 1, -3))
			p.set_meta("invulnerable", was)
		"kill_all_enemies":
			for e in enemies.values():
				if not e.is_dead():
					e.take_damage(99999.0, p)
		"complete_objective": director.force_complete(String(arg), p)
		"invulnerable": p.set_meta("invulnerable", bool(arg))
		"fail_mission": director.fail("Test failure")

func send_inventory(p: Player) -> void:
	var peer := Session.peer_for_slot(p.slot)
	if peer != 0 and _ready_peers.has(peer):
		rpc_id(peer, "s_inventory", p.inventory.to_dict())

func damage_player(p: Player, amount: float, from_pos: Vector3) -> void:
	if p.get_meta("invulnerable", false):
		amount = 0.0
	var applied := p.health.apply_damage(amount)
	var peer := Session.peer_for_slot(p.slot)
	if peer != 0 and _ready_peers.has(peer):
		rpc_id(peer, "s_damaged", from_pos, amount, applied)

func on_player_downed(p: Player) -> void:
	director.stats(p.slot)["downs"] += 1
	broadcast_event("%s is down!" % p.display_name, "down")

func on_player_eliminated(p: Player) -> void:
	broadcast_event("%s has bled out." % p.display_name, "elim")

func on_enemy_killed(e: Enemy, killer: Player) -> void:
	if killer:
		var st := director.stats(killer.slot)
		st["kills"] += 1
		st["kill_xp"] += int(e.def.get("xp", 10))
	director.on_enemy_killed(e)

func ai_alert_radius(source: Enemy, radius: float) -> void:
	for e in enemies.values():
		if e != source and not e.is_dead() and e.global_position.distance_to(source.global_position) <= radius and source.target:
			if e.state != Enemy.State.COMBAT:
				e.engage(source.target, true)

func enemy_fired(e: Enemy, from: Vector3, end: Vector3, target: Player, damage: float) -> void:
	if target and has_los(from, end):
		damage_player(target, damage, from)
	for peer in _ready_peers:
		rpc_id(peer, "s_shot", 1, e.eid, from, end, "enemy")

func spawn_group(group: String) -> void:
	var defs: Array = mission.get("enemy_groups", {}).get(group, [])
	for g in defs:
		var e := Enemy.new()
		var pos := Vector3(g["pos"][0], g["pos"][1] + 0.1, g["pos"][2])
		e.setup(_next_enemy_id, g["type"], self, g.get("patrol", []), true)
		_next_enemy_id += 1
		$Enemies.add_child(e)
		e.global_position = pos
		e.home = pos
		enemies[e.eid] = e
		if g.get("hunt", false):
			var tgt := _nearest_alive_player(pos)
			if tgt:
				e.call_deferred("engage", tgt, true)
		for peer in _ready_peers:
			rpc_id(peer, "s_spawn_enemy", e.eid, e.type_id, e.global_position, e.rotation.y)
	if not defs.is_empty():
		Log.info("world", "enemy group spawned", {"group": group, "count": defs.size()})

func _nearest_alive_player(pos: Vector3) -> Player:
	var best: Player = null
	var bd := INF
	for p in players.values():
		if p.health.alive() and p.connected and p.global_position.distance_to(pos) < bd:
			bd = p.global_position.distance_to(pos)
			best = p
	return best

## World line-of-sight (static geometry + active smoke).
func has_los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	if get_world_3d().direct_space_state.intersect_ray(q):
		return false
	for s in smokes:
		if s[2] > mission_time and _segment_hits_sphere(a, b, s[0], s[1]):
			return false
	return true

static func _segment_hits_sphere(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	var ab := b - a
	var t := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_to(c) < r

func broadcast_event(text: String, kind: String) -> void:
	for peer in _ready_peers:
		rpc_id(peer, "s_event", text, kind)

func broadcast_objectives() -> void:
	var st := director.state_dict()
	for peer in _ready_peers:
		rpc_id(peer, "s_objectives", st)

func broadcast_to_ready(method: String, args: Array) -> void:
	for peer in _ready_peers:
		callv("rpc_id", [peer, method] + args)

# ======================================================================= server tick
func _physics_process(dt: float) -> void:
	mission_time += dt
	if not is_server:
		return
	for p in players.values():
		if p.connected or not p.input_queue.is_empty():
			p.server_tick(dt)
		else:
			p.health.tick(dt)
			p._refresh_net()
		_interaction_tick(p, dt)
	for e in enemies.values():
		e.server_tick(dt)
	equipment.tick(dt)
	director.tick(dt)
	smokes = smokes.filter(func(s): return s[2] > mission_time)
	if Session.members.is_empty():
		_empty_t += dt
		if _empty_t > 60.0 and director.phase == "active":
			director.fail("Squad disconnected")
	else:
		_empty_t = 0.0
	_tick += 1
	if _tick % SNAPSHOT_EVERY == 0 and not _ready_peers.is_empty():
		var ps := []
		for p in players.values():
			ps.append(p.snapshot())
		var es := []
		for e in enemies.values():
			if not e.is_dead() or e.get_meta("sent_dead", 0) < 3:
				es.append(e.snapshot())
				if e.is_dead():
					e.set_meta("sent_dead", e.get_meta("sent_dead", 0) + 1)
		var extra := [director.extraction_progress(), mission_time]
		var live := multiplayer.get_peers()
		for peer in _ready_peers.keys():
			if live.has(peer):
				rpc_id(peer, "s_snapshot", ps, es, extra)
			else:
				_ready_peers.erase(peer)  # disconnected; peer_left will clean up the rest

func _interaction_tick(p: Player, dt: float) -> void:
	var holding: bool = p.connected and p.health.alive() and (int(p.last_input["buttons"]) & PlayerMotor.BTN_INTERACT) != 0
	if not holding:
		p.interact_target = ""
		p.interact_progress = 0.0
		p.interact_needed = 0.0
		return
	var t := find_interaction(p, true)
	if t.is_empty():
		p.interact_target = ""
		p.interact_progress = 0.0
		p.interact_needed = 0.0
		return
	if t["key"] != p.interact_target:
		p.interact_target = t["key"]
		p.interact_progress = 0.0
	p.interact_needed = t["time"]
	p.interact_progress += dt
	if p.interact_progress >= p.interact_needed:
		p.interact_progress = 0.0
		p.interact_target = ""
		_complete_interaction(p, t)

func _complete_interaction(p: Player, t: Dictionary) -> void:
	match t["kind"]:
		"revive":
			var target: Player = players[t["slot"]]
			var c := GameData.klass(p.class_id)
			var hp: float = float(GameData.player_rules["revive_health"]) + float(c["modifiers"].get("revive_health_bonus", 0))
			target.health.revive(hp)
			director.stats(p.slot)["revives"] += 1
			broadcast_event("%s revived %s." % [p.display_name, target.display_name], "revive")
		"objective":
			director.on_interact_complete(t["id"], p)

## Shared interaction query (server for validation, client for prompts). Returns {} when nothing is in reach.
func find_interaction(p: Player, server_side: bool) -> Dictionary:
	var r := GameData.player_rules
	var pos := p.global_position
	var best := {}
	var best_d := INF
	for q in players.values():
		if q == p:
			continue
		var downed: bool = q.health.is_downed if server_side else q.is_downed_net()
		if downed and q.global_position.distance_to(pos) <= float(r["revive_range"]):
			var d: float = q.global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				var mult: float = p.revive_mult if server_side else float(GameData.klass(p.class_id)["modifiers"].get("revive_time_mult", 1.0))
				best = {"key": "player:%d" % q.slot, "kind": "revive", "slot": q.slot, "time": float(r["revive_time"]) * mult,
					"label": "Revive %s" % q.display_name}
	if not best.is_empty():
		return best
	var eye := pos + Vector3.UP * PlayerMotor.eye_height(p.motor)
	var look := Basis.from_euler(Vector3(p.aim_pitch if server_side else p.pitch, p.rotation.y, 0)) * Vector3.FORWARD
	for id in map_info["interactables"]:
		var it: Dictionary = map_info["interactables"][id]
		var obj := _objective_for_target(id, server_side)
		if obj.is_empty():
			continue
		var to: Vector3 = it["pos"] - eye
		if to.length() > float(r["interact_range"]) or look.dot(to.normalized()) < 0.35:
			continue
		return {"key": "obj:" + id, "kind": "objective", "id": obj["id"], "time": float(obj.get("hold_time", 2.0)), "label": it["label"]}
	return {}

func _objective_for_target(target: String, server_side: bool) -> Dictionary:
	for o in mission["objectives"]:
		if o.get("target", "") == target:
			var status: String = director.status(o["id"]) if server_side else objective_state.get("objectives", {}).get(o["id"], {}).get("status", "")
			return o if status == "active" else {}
	return {}

# ======================================================================= client RPC handlers
@rpc("authority", "call_remote", "reliable")
func s_spawn_player(slot: int, pname: String, cls: String, pos: Vector3, yaw: float) -> void:
	if players.has(slot):
		return
	var p := Player.new()
	p.name = "P%d" % slot
	p.slot = slot
	p.display_name = pname
	p.class_id = cls
	p.world = self
	$Players.add_child(p)
	p.global_position = pos
	p.rotation.y = yaw
	players[slot] = p
	if slot == Session.me().get("slot", -1):
		_make_local(p)
	else:
		var rp := preload("res://player/RemotePresentation.gd").new()
		rp.name = "Remote"
		rp.player = p
		p.add_child(rp)

func _make_local(p: Player) -> void:
	p.is_local = true
	local_player = p
	var ctrl := preload("res://player/LocalController.gd").new()
	ctrl.name = "Controller"
	ctrl.player = p
	ctrl.world = self
	p.add_child(ctrl)
	var rig := preload("res://player/FirstPersonRig.gd").new()
	rig.name = "Rig"
	rig.player = p
	rig.controller = ctrl
	p.add_child(rig)
	ctrl.rig = rig
	local_player_ready.emit(p)

@rpc("authority", "call_remote", "reliable")
func s_you_are(slot: int) -> void:
	var p: Player = players.get(slot)
	if p and not p.is_local:
		var rem := p.get_node_or_null("Remote")
		if rem:
			rem.queue_free()
		_make_local(p)

@rpc("authority", "call_remote", "reliable")
func s_spawn_enemy(id: int, type_id: String, pos: Vector3, yaw: float) -> void:
	if enemies.has(id):
		return
	var e := Enemy.new()
	e.setup(id, type_id, self, [], false)
	$Enemies.add_child(e)
	e.global_position = pos
	e.rotation.y = yaw
	enemies[id] = e

@rpc("authority", "call_remote", "unreliable_ordered")
func s_snapshot(ps: Array, es: Array, extra: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for s in ps:
		var p: Player = players.get(s[0])
		if p:
			p.apply_snapshot(s, now)
	for s in es:
		var e: Enemy = enemies.get(s[0])
		if e:
			e.apply_snapshot(s, now)
	extraction["progress"] = extra[0]
	mission_time = extra[1]

@rpc("authority", "call_remote", "reliable")
func s_inventory(inv: Dictionary) -> void:
	if local_player:
		local_player.set_inventory_mirror(inv)

@rpc("authority", "call_remote", "reliable")
func s_shot(kind: int, who: int, from: Vector3, to: Vector3, sound: String) -> void:
	if fx == null:
		return
	fx.tracer(from, to)
	Sfx.play_3d("shot_" + sound, from, -4.0 if kind == 0 else -2.0)
	if kind == 0 and players.has(who):
		var rem: Node = players[who].get_node_or_null("Remote")
		if rem:
			rem.on_fire()
	elif kind == 1 and enemies.has(who):
		enemies[who].on_fire_visual()
		if local_player and _segment_near(from, to, local_player.global_position + Vector3.UP * 1.2, 1.5):
			Sfx.play_2d("whiz", -8.0)

static func _segment_near(a: Vector3, b: Vector3, c: Vector3, r: float) -> bool:
	return _segment_hits_sphere(a, b, c, r)

@rpc("authority", "call_remote", "reliable")
func s_sound3d(sound: String, pos: Vector3) -> void:
	Sfx.play_3d(sound, pos, -6.0)

@rpc("authority", "call_remote", "reliable")
func s_hit(killed: bool, headshot: bool) -> void:
	if hud:
		hud.hit_marker(killed, headshot)
	Sfx.play_2d("hit_kill" if killed else "hit", -6.0)

@rpc("authority", "call_remote", "reliable")
func s_damaged(from_pos: Vector3, amount: float, applied: float) -> void:
	if hud:
		hud.damage_from(from_pos, amount)
	if local_player and local_player.has_node("Rig"):
		local_player.get_node("Rig").add_shake(clampf(amount / 30.0, 0.1, 0.6))
	Sfx.play_2d("hurt", -4.0)

@rpc("authority", "call_remote", "reliable")
func s_objectives(st: Dictionary) -> void:
	var prev := objective_state
	objective_state = st
	extraction["open"] = st.get("extraction_open", false)
	if fx and extraction["open"] and not prev.get("extraction_open", false):
		fx.helicopter(map_info["extraction"])
	objectives_changed.emit(st)

@rpc("authority", "call_remote", "reliable")
func s_event(text: String, kind: String) -> void:
	if kind == "radio":
		Sfx.play_2d("radio", -8.0)
	event_message.emit(text, kind)

@rpc("authority", "call_remote", "reliable")
func s_throw(id: int, kind: String, pos: Vector3, vel: Vector3) -> void:
	if fx:
		fx.throwable(id, kind, pos, vel)

@rpc("authority", "call_remote", "reliable")
func s_detonate(id: int, kind: String, pos: Vector3) -> void:
	if fx:
		fx.detonate(id, kind, pos)

@rpc("authority", "call_remote", "reliable")
func s_smoke(pos: Vector3, radius: float, duration: float) -> void:
	smokes.append([pos, radius, mission_time + duration])
	if fx:
		fx.smoke(pos, radius, duration)

@rpc("authority", "call_remote", "reliable")
func s_flashed(intensity: float) -> void:
	if hud:
		hud.flash(intensity)

@rpc("authority", "call_remote", "reliable")
func s_mission_end(summary: Dictionary) -> void:
	mission_ended.emit(summary)

## Client helper: world positions of active objectives (for compass, minimap, world markers).
func get_objective_markers() -> Array:
	var out := []
	var objs: Dictionary = objective_state.get("objectives", {})
	for id in objective_state.get("order", []):
		var o: Dictionary = objs[id]
		if o["status"] != "active":
			continue
		var pos := Vector3.INF
		var kind := "objective"
		if o["type"] == "extraction":
			pos = map_info["extraction"]
			kind = "extract"
		elif o["target"] != "":
			pos = map_info["interactables"][o["target"]]["pos"]
		elif o["zone"] != "":
			var box: AABB = map_info["zones"][o["zone"]]
			pos = box.get_center()
			pos.y = 1.0
		if pos != Vector3.INF:
			out.append({"id": id, "pos": pos, "kind": kind, "name": o["name"], "primary": o["primary"]})
	return out

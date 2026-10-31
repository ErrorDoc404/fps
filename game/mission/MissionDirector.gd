class_name MissionDirector
extends RefCounted
## Server-side mission state machine and objective evaluation, driven entirely by mission data.
## Mission phases: active -> completed | failed. Objective status: locked | active | completed.

var world: Node
var mission: Dictionary
var phase := "preparing"
var _status := {}           # objective id -> status
var _progress := {}         # objective id -> 0..1 (extraction / secure area)
var _stats := {}            # slot -> {kills, kill_xp, downs, revives, extracted}
var _zone_had_enemies := {}
var _all_down_t := 0.0
var _end_reason := ""
var _extract_t := 0.0
var _started_at := 0.0

func _init(w: Node, m: Dictionary) -> void:
	world = w
	mission = m
	for o in mission["objectives"]:
		_status[o["id"]] = "locked"
		_progress[o["id"]] = 0.0

func start() -> void:
	phase = "active"
	_started_at = world.mission_time
	_refresh_unlocks()
	radio("start")
	Log.info("mission", "mission active", {"mission": mission["id"], "session": world.session_id})

func stats(slot: int) -> Dictionary:
	if not _stats.has(slot):
		_stats[slot] = {"kills": 0, "kill_xp": 0, "downs": 0, "revives": 0, "extracted": false}
	return _stats[slot]

func status(id: String) -> String:
	return _status.get(id, "")

func objective(id: String) -> Dictionary:
	for o in mission["objectives"]:
		if o["id"] == id:
			return o
	return {}

func radio(key: String) -> void:
	var text: String = mission.get("radio", {}).get(key, "")
	if text != "":
		world.broadcast_event(text, "radio")

func extraction_open() -> bool:
	for o in mission["objectives"]:
		if o["type"] == "extraction":
			return _status[o["id"]] == "active"
	return false

func extraction_progress() -> float:
	for o in mission["objectives"]:
		if o["type"] == "extraction":
			return _progress[o["id"]]
	return 0.0

func _refresh_unlocks() -> void:
	var changed := false
	for o in mission["objectives"]:
		if _status[o["id"]] != "locked":
			continue
		var ok := true
		for dep in o.get("depends", []):
			if _status.get(dep, "") != "completed":
				ok = false
		if ok:
			_status[o["id"]] = "active"
			changed = true
			if o["type"] == "extraction":
				radio("extraction_open")
			if o["type"] == "secure_area":
				_zone_had_enemies[o["id"]] = _living_enemies_in(o["zone"]) > 0
			if o.has("on_start_spawn") and o["type"] != "interact":
				world.spawn_group(o["on_start_spawn"])
	if changed:
		world.broadcast_objectives()

func _complete(id: String, by: Player = null) -> void:
	if _status.get(id, "") != "active":
		return
	var o := objective(id)
	_status[id] = "completed"
	Log.info("mission", "objective completed", {"objective": id, "by": by.display_name if by else ""})
	world.broadcast_event("Objective complete: %s" % o["name"], "objective")
	radio(id)
	if o.has("on_complete_spawn"):
		world.spawn_group(o["on_complete_spawn"])
	if o.get("primary", false) and mission.get("respawn", {}).get("mode", "") == "on_objective":
		_reinforce_eliminated()
	if o["type"] == "extraction":
		_finish("completed")
		return
	_refresh_unlocks()
	world.broadcast_objectives()

func force_complete(id: String, by: Player) -> void:
	_complete(id, by)

func _reinforce_eliminated() -> void:
	var spawns: Array = mission["spawn_points"]
	for p in world.players.values():
		if p.health.is_eliminated:
			var anchor := _squad_anchor(p)
			p.respawn_at(anchor)
			world.broadcast_event("%s has rejoined the operation." % p.display_name, "revive")

func _squad_anchor(exclude: Player) -> Vector3:
	for q in world.players.values():
		if q != exclude and q.health.alive() and q.connected:
			return q.global_position + Vector3(1.0, 0.2, 1.0)
	var s: Array = mission["spawn_points"][exclude.slot]
	return Vector3(s[0], s[1] + 0.1, s[2])

func on_interact_complete(id: String, by: Player) -> void:
	_complete(id, by)

func on_interact_started(id: String) -> void:
	var o := objective(id)
	if o.has("on_start_spawn") and not o.get("_spawned", false):
		o["_spawned"] = true
		world.spawn_group(o["on_start_spawn"])

func on_enemy_killed(_e: Enemy) -> void:
	pass

func _living_enemies_in(zone: String) -> int:
	var box: AABB = world.map_info["zones"][zone]
	var n := 0
	for e in world.enemies.values():
		if not e.is_dead() and box.has_point(e.global_position + Vector3.UP):
			n += 1
	return n

func _players_in(zone: String) -> Array:
	var box: AABB = world.map_info["zones"][zone]
	var out := []
	for p in world.players.values():
		if p.connected and box.has_point(p.global_position + Vector3.UP * 0.5):
			out.append(p)
	return out

func tick(dt: float) -> void:
	if phase != "active":
		return
	for o in mission["objectives"]:
		var id: String = o["id"]
		if _status[id] != "active":
			continue
		match o["type"]:
			"reach_zone":
				for p in _players_in(o["zone"]):
					if p.health.alive():
						_complete(id, p)
						break
			"secure_area":
				var inside := _players_in(o["zone"]).filter(func(p): return p.health.alive())
				if _living_enemies_in(o["zone"]) == 0 and not inside.is_empty():
					_complete(id, inside[0])
			"interact":
				for p in world.players.values():
					if p.interact_target == "obj:" + String(o["target"]):
						on_interact_started(id)
			"extraction":
				_tick_extraction(o, dt)
	_check_failure(dt)

func _tick_extraction(o: Dictionary, dt: float) -> void:
	var id: String = o["id"]
	var active := []
	for p in world.players.values():
		if p.connected and not p.health.is_eliminated:
			active.append(p)
	var inside := _players_in(o["zone"])
	var ok := not active.is_empty()
	for p in active:
		if not inside.has(p) or p.health.is_downed:
			ok = false
	if ok:
		_progress[id] = min(1.0, _progress[id] + dt / float(o.get("hold_time", 8.0)))
		if _progress[id] >= 1.0:
			for p in inside:
				stats(p.slot)["extracted"] = true
			_complete(id, null)
	else:
		_progress[id] = max(0.0, _progress[id] - dt * 0.25)

func _check_failure(dt: float) -> void:
	if not mission.get("fail_conditions", {}).get("all_down", true):
		return
	var any_up := false
	var any_connected := false
	for p in world.players.values():
		if p.connected:
			any_connected = true
			if p.health.alive():
				any_up = true
	if any_connected and not any_up:
		_all_down_t += dt
		if _all_down_t > 1.0:
			fail("All operators incapacitated")
	else:
		_all_down_t = 0.0

func fail(reason: String) -> void:
	if phase != "active":
		return
	_end_reason = reason
	_finish("failed")

func _finish(result: String) -> void:
	phase = result
	Log.info("mission", "mission finished", {"result": result, "reason": _end_reason, "duration": world.mission_time - _started_at})
	world.broadcast_event("MISSION %s" % ("COMPLETE" if result == "completed" else "FAILED"), "mission_end")
	var rw: Dictionary = GameData.progression["rewards"]
	var base_xp := 0
	var base_credits := 0
	var objs := []
	var intel_xp := 0
	for o in mission["objectives"]:
		var done: bool = _status[o["id"]] == "completed"
		objs.append({"name": o["name"], "primary": o.get("primary", false), "completed": done})
		if done:
			base_xp += int(o["reward"]["xp"])
			base_credits += int(o["reward"]["credits"])
			if o["type"] == "interact":
				intel_xp += int(o["reward"]["xp"])
	if result == "completed":
		base_xp += int(mission["rewards"]["completion_xp"])
		base_credits += int(mission["rewards"]["completion_credits"])
	var per_slot := {}
	var squad := []
	for p in world.players.values():
		var st := stats(p.slot)
		var c := GameData.klass(p.class_id)
		var xp := base_xp + int(st["kill_xp"])
		xp += int(intel_xp * (float(c["modifiers"].get("intel_reward_mult", 1.0)) - 1.0))
		var credits := base_credits
		var survived: bool = result == "completed" and st["extracted"]
		if survived:
			xp += int(rw["survival_xp"])
			credits += int(rw["survival_credits"])
		if result != "completed":
			xp = int(xp * float(rw["failure_mult"]))
			credits = int(credits * float(rw["failure_mult"]))
		per_slot[p.slot] = {"xp": xp, "credits": credits}
		squad.append({"name": p.display_name, "class": p.class_id, "kills": st["kills"], "downs": st["downs"],
			"revives": st["revives"], "extracted": st["extracted"], "eliminated": p.health.is_eliminated, "xp": xp, "credits": credits})
	var summary := {"result": result, "reason": _end_reason, "mission": mission["id"], "mission_name": mission["name"],
		"code": mission.get("code", ""), "objectives": objs, "squad": squad, "duration": world.mission_time - _started_at,
		"session": world.session_id}
	world.broadcast_objectives()
	world.get_tree().create_timer(3.0).timeout.connect(func(): Session.finish_mission(summary, per_slot))

func state_dict() -> Dictionary:
	var objs := {}
	for o in mission["objectives"]:
		objs[o["id"]] = {"status": _status[o["id"]], "name": o["name"], "description": o["description"],
			"primary": o.get("primary", false), "type": o["type"], "zone": o.get("zone", ""), "target": o.get("target", "")}
	return {"objectives": objs, "order": mission["objectives"].map(func(o): return o["id"]), "phase": phase,
		"extraction_open": extraction_open()}

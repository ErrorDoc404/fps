class_name EquipmentSystem
extends RefCounted
## Server-side equipment: validation, cooldowns, throwable simulation and effects. Data-driven from equipment.json.

var world: Node
var _throwables: Array = []   # {id, kind, pos, vel, fuse, owner, landed_t}
var _next_id := 1

func _init(w: Node) -> void:
	world = w

func use(p: Player, item: String, yaw: float, pitch: float) -> void:
	var inv := p.inventory
	var def := GameData.equip(item)
	if def.is_empty() or not p.health.alive() or int(inv.equipment.get(item, 0)) <= 0:
		return
	if inv.cooldowns.has(item) or inv.use_timer > 0.0:
		return
	inv.equipment[item] = int(inv.equipment[item]) - 1
	inv.cooldowns[item] = float(def.get("cooldown", 1.0))
	inv.dirty = true
	var dir := Basis.from_euler(Vector3(pitch, yaw, 0)) * Vector3.FORWARD
	match def["effect"]:
		"heal_self":
			inv.cancel_reload()
			inv.use_timer = def["use_time"]
			inv.use_item = item
		"smoke", "flash":
			var t := {"id": _next_id, "kind": item, "pos": p.eye_position() + dir * 0.5, "vel": dir * float(def["throw_speed"]) + Vector3.UP * 2.5,
				"fuse": float(def.get("fuse", 99.0)), "owner": p, "landed_t": -1.0, "def": def}
			_next_id += 1
			_throwables.append(t)
			world.broadcast_to_ready("s_throw", [t["id"], item, t["pos"], t["vel"]])
		"reveal":
			var n := 0
			var until: float = Time.get_ticks_msec() / 1000.0 + float(def["duration"])
			for e in world.enemies.values():
				if not e.is_dead() and e.global_position.distance_to(p.global_position) <= float(def["radius"]):
					e.revealed_until = until
					n += 1
			world.broadcast_event("%s: recon pulse marked %d hostiles." % [p.display_name, n], "info")
		"resupply":
			for q in world.players.values():
				if q.health.alive() and q.global_position.distance_to(p.global_position) <= float(def["radius"]):
					q.inventory.add_magazines(int(def["magazines"]))
			world.broadcast_event("%s distributed ammunition." % p.display_name, "info")
	Log.debug("equip", "used", {"slot": p.slot, "item": item})

func finish_use(p: Player) -> void:
	var item := p.inventory.use_item
	p.inventory.use_item = ""
	p.inventory.dirty = true
	var def := GameData.equip(item)
	if def.get("effect", "") != "heal_self":
		return
	var target := p
	if GameData.klass(p.class_id)["modifiers"].get("heal_teammate", false):
		var look := p.aim_direction()
		for q in world.players.values():
			if q != p and q.health.alive() and q.health.health < q.health.max_health:
				var to: Vector3 = q.global_position - p.global_position
				if to.length() < 2.5 and look.dot(to.normalized()) > 0.5:
					target = q
					break
	target.health.heal(float(def["amount"]))
	if target != p:
		world.broadcast_event("%s treated %s." % [p.display_name, target.display_name], "info")

func tick(dt: float) -> void:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for t in _throwables.duplicate():
		t["fuse"] -= dt
		if t["landed_t"] < 0.0:
			var v: Vector3 = t["vel"]
			v.y -= 9.8 * dt
			var next: Vector3 = t["pos"] + v * dt
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(t["pos"], next, 1))
			if hit:
				next = hit["position"] + hit["normal"] * 0.05
				v = Vector3.ZERO
				t["landed_t"] = 0.0
			t["pos"] = next
			t["vel"] = v
		else:
			t["landed_t"] += dt
		var kind: String = t["kind"]
		var detonate: bool = (kind == "smoke" and t["landed_t"] > 0.6) or (kind == "flash" and t["fuse"] <= 0.0)
		if detonate:
			_throwables.erase(t)
			_detonate(t)

func _detonate(t: Dictionary) -> void:
	var def: Dictionary = t["def"]
	var pos: Vector3 = t["pos"]
	world.broadcast_to_ready("s_detonate", [t["id"], t["kind"], pos])
	if t["kind"] == "smoke":
		var r: float = def["radius"]
		var dur: float = def["duration"]
		world.smokes.append([pos + Vector3.UP * 1.2, r, world.mission_time + dur])
		world.broadcast_to_ready("s_smoke", [pos + Vector3.UP * 1.2, r, dur])
	elif t["kind"] == "flash":
		var r: float = def["radius"]
		for e in world.enemies.values():
			var d: float = e.global_position.distance_to(pos)
			if not e.is_dead() and d < r and world.has_los(pos + Vector3.UP * 0.3, e.eye()):
				e.stun(float(def["stun"]) * (1.0 - d / r * 0.5))
		for p in world.players.values():
			var d: float = p.global_position.distance_to(pos)
			if d < r and world.has_los(pos + Vector3.UP * 0.3, p.eye_position()):
				var facing: float = p.aim_direction().dot((pos - p.eye_position()).normalized())
				var intensity := clampf((1.0 - d / r) * (0.4 + 0.6 * maxf(facing, 0.0)), 0.0, 1.0)
				var peer: int = world.room.peer_for_slot(p.slot)
				if peer != 0:
					world.rpc_id(peer, "s_flashed", intensity)
		for e in world.enemies.values():
			e.hear(pos, t["owner"], 1.2)

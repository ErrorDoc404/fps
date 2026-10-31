class_name Player
extends CharacterBody3D
## Networked operator. Gameplay state (motor, health, inventory) is server-authoritative;
## presentation is attached separately: FirstPersonRig for the local player, ThirdPersonBody for others.
## The server never creates presentation nodes.

signal inventory_changed(inv: Dictionary)

const INTERP_DELAY := 0.1

var slot := 0
var display_name := ""
var class_id := "assault"
var is_local := false
var motor: Dictionary
var world: Node

# server-only
var health: PlayerHealth
var inventory: PlayerInventory
var input_queue: Array = []
var last_input := {"move": Vector2.ZERO, "yaw": 0.0, "pitch": 0.0, "buttons": 0, "stance": 0}
var last_seq := 0
var aim_pitch := 0.0
var connected := true
var interact_target := ""     # e.g. "player:2", "obj:intel_laptop"
var interact_progress := 0.0
var interact_needed := 0.0
var revive_mult := 1.0

# replicated mirror (clients) -- also filled on server for uniform reads
var net := {"hp": 100.0, "armor": 50.0, "stamina": 100.0, "flags": 0, "extra": 0.0, "weapon": "", "interact": 0.0}
var inv_mirror := {}
var _snaps: Array = []        # remote interpolation buffer: [time, pos, yaw, pitch]
var pitch := 0.0

const F_SPRINT := 4
const F_ADS := 8
const F_RELOAD := 16
const F_DOWNED := 32
const F_ELIMINATED := 64
const F_DISCONNECTED := 128

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	motor = PlayerMotor.new_state()

func setup_server(member: Dictionary) -> void:
	slot = member["slot"]
	display_name = member["name"]
	class_id = member["class"]
	var c := GameData.klass(class_id)
	health = PlayerHealth.new(float(c["modifiers"].get("armor_bonus", 0.0)))
	inventory = PlayerInventory.new()
	inventory.setup(class_id, member["primary"], member["secondary"])
	motor["weight"] = inventory.total_weight()
	revive_mult = float(c["modifiers"].get("revive_time_mult", 1.0))
	health.downed.connect(func():
		inventory.cancel_reload()
		world.on_player_downed(self))
	health.eliminated.connect(func(): world.on_player_eliminated(self))

func is_alive_net() -> bool:
	return (int(net["flags"]) & (F_DOWNED | F_ELIMINATED)) == 0

func is_downed_net() -> bool:
	return (int(net["flags"]) & F_DOWNED) != 0

func is_eliminated_net() -> bool:
	return (int(net["flags"]) & F_ELIMINATED) != 0

func eye_position() -> Vector3:
	return global_position + Vector3.UP * PlayerMotor.eye_height(motor)

func aim_direction() -> Vector3:
	return Basis.from_euler(Vector3(aim_pitch, rotation.y, 0)) * Vector3.FORWARD

# ------------------------------------------------------------------ server
func server_tick(dt: float) -> void:
	if health.is_eliminated:
		velocity = Vector3.ZERO
		_refresh_net()
		return
	# Each client input frame is simulated exactly once (no extrapolation), so the owning client's
	# prediction history and the server agree; up to 3 queued frames are drained per tick to absorb jitter.
	var n := 0
	while not input_queue.is_empty() and n < 3:
		last_input = input_queue.pop_front()
		_server_step(last_input, dt)
		n += 1
	if input_queue.size() > 8:
		input_queue = input_queue.slice(input_queue.size() - 4)
	health.tick(dt)
	inventory.tick(dt)
	if inventory.use_timer > 0.0:
		inventory.use_timer -= dt
		if inventory.use_timer <= 0.0:
			world.equipment.finish_use(self)
	if inventory.dirty:
		inventory.dirty = false
		world.send_inventory(self)
	_refresh_net()

func _server_step(inp: Dictionary, dt: float) -> void:
	motor["downed"] = health.is_downed
	motor["reloading"] = inventory.is_reloading()
	motor["busy"] = inventory.use_timer > 0.0 or interact_progress > 0.0
	aim_pitch = clampf(float(inp["pitch"]), -1.45, 1.45)
	PlayerMotor.step(self, motor, inp, dt)
	if motor["sprinting"] and inventory.is_reloading():
		pass  # reload continues while sprinting; firing is blocked instead

func _refresh_net() -> void:
	var flags := int(motor["stance"])
	if motor["sprinting"]: flags |= F_SPRINT
	if motor["ads"]: flags |= F_ADS
	if inventory.is_reloading(): flags |= F_RELOAD
	if health.is_downed: flags |= F_DOWNED
	if health.is_eliminated: flags |= F_ELIMINATED
	if not connected: flags |= F_DISCONNECTED
	net["hp"] = health.health
	net["armor"] = health.armor
	net["stamina"] = motor["stamina"]
	net["flags"] = flags
	net["extra"] = health.bleedout
	net["weapon"] = inventory.current()["id"]
	net["interact"] = (interact_progress / interact_needed) if interact_needed > 0.0 else 0.0
	pitch = aim_pitch

func snapshot() -> Array:
	return [slot, global_position, rotation.y, aim_pitch, net["flags"], net["hp"], net["armor"], net["stamina"],
		net["extra"], last_seq, net["weapon"], net["interact"], health.max_health, health.max_armor]

func respawn_at(pos: Vector3) -> void:
	health.restore_full()
	global_position = pos
	velocity = Vector3.ZERO
	motor["stance"] = 0
	inventory.dirty = true

# ------------------------------------------------------------------ client
func apply_snapshot(s: Array, now: float) -> void:
	net["flags"] = s[4]
	net["hp"] = s[5]
	net["armor"] = s[6]
	net["extra"] = s[8]
	net["weapon"] = s[10]
	net["interact"] = s[11]
	net["max_hp"] = s[12]
	net["max_armor"] = s[13]
	motor["downed"] = (int(s[4]) & F_DOWNED) != 0
	if is_local:
		net["stamina"] = s[7]
		motor["stamina"] = s[7]
		var ctrl := get_node_or_null("Controller")
		if ctrl:
			ctrl.reconcile(int(s[9]), s[1])
	else:
		motor["stance"] = int(s[4]) & 3
		motor["sprinting"] = (int(s[4]) & F_SPRINT) != 0
		motor["ads"] = (int(s[4]) & F_ADS) != 0
		_snaps.append([now, s[1], s[2], s[3]])
		if _snaps.size() > 30:
			_snaps.pop_front()

func set_inventory_mirror(inv: Dictionary) -> void:
	inv_mirror = inv
	inventory_changed.emit(inv)

func _physics_process(_dt: float) -> void:
	if world == null or Net.is_server() or is_local or _snaps.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0 - INTERP_DELAY
	while _snaps.size() >= 2 and _snaps[1][0] <= t:
		_snaps.pop_front()
	if _snaps.size() >= 2:
		var a: Array = _snaps[0]
		var b: Array = _snaps[1]
		var f := clampf((t - a[0]) / maxf(0.001, b[0] - a[0]), 0.0, 1.0)
		global_position = (a[1] as Vector3).lerp(b[1], f)
		rotation.y = lerp_angle(a[2], b[2], f)
		pitch = lerpf(a[3], b[3], f)
	else:
		global_position = _snaps[0][1]
		rotation.y = _snaps[0][2]
		pitch = _snaps[0][3]
	var target_h := PlayerMotor.stance_height(motor)
	motor["height"] = move_toward(float(motor["height"]), target_h, _dt * 3.5)
	PlayerMotor._apply_shape(self, float(motor["height"]))

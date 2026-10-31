extends Node
## Owning-client input + client-side prediction for the local operator.
## Sends one input frame per physics tick to the server and reconciles against authoritative snapshots.

var player: Player
var world: Node
var yaw := 0.0
var pitch := 0.0
var stance := 0
var seq := 0
var history: Array = []       # [seq, position after applying that input]
var _next_fire := 0.0
var _recoil_debt := 0.0
var _semi_latch := false
var rig: Node
var last_server_pos := Vector3.ZERO

func _ready() -> void:
	yaw = player.rotation.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func input_blocked() -> bool:
	return world.ui_blocking

func _unhandled_input(event: InputEvent) -> void:
	if input_blocked():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.get_v("mouse_sensitivity") * 0.01
		if player.motor["ads"]:
			sens *= 0.6
		yaw -= event.relative.x * sens
		var dy: float = event.relative.y * sens * (-1.0 if Settings.get_v("invert_y") else 1.0)
		pitch = clampf(pitch - dy, -1.45, 1.45)
	elif event.is_action_pressed("crouch"):
		stance = 0 if stance == 1 else 1
	elif event.is_action_pressed("prone"):
		stance = 0 if stance == 2 else 2
	elif event.is_action_pressed("jump") and stance != 0:
		stance = 0
	elif event.is_action_pressed("reload"):
		world.rpc_id(1, "c_reload")
	elif event.is_action_pressed("weapon_primary"):
		world.rpc_id(1, "c_switch", 0)
	elif event.is_action_pressed("weapon_secondary"):
		world.rpc_id(1, "c_switch", 1)
	elif event.is_action_pressed("weapon_next") or (event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		world.rpc_id(1, "c_switch", 1 - int(player.inv_mirror.get("active", 0)))
	elif event.is_action_pressed("fire_mode"):
		world.rpc_id(1, "c_fire_mode")
	elif event.is_action_pressed("equip_1"):
		_use_utility(0)
	elif event.is_action_pressed("equip_2"):
		_use_utility(1)
	elif event.is_action_pressed("medkit"):
		world.rpc_id(1, "c_equipment", "medkit", yaw, pitch)

func _use_utility(index: int) -> void:
	var items := utility_items()
	if index < items.size():
		world.rpc_id(1, "c_equipment", items[index], yaw, pitch)

func utility_items() -> Array:
	var out := []
	for id in player.inv_mirror.get("equipment", {}):
		if id != "medkit":
			out.append(id)
	return out

func _buttons() -> int:
	if input_blocked():
		return 0
	var b := 0
	if Input.is_action_pressed("sprint"): b |= PlayerMotor.BTN_SPRINT
	if Input.is_action_pressed("jump"): b |= PlayerMotor.BTN_JUMP
	if Input.is_action_pressed("aim"): b |= PlayerMotor.BTN_ADS
	if Input.is_action_pressed("interact"): b |= PlayerMotor.BTN_INTERACT
	return b

func _physics_process(dt: float) -> void:
	if multiplayer.multiplayer_peer == null or player.is_eliminated_net():
		return
	var move := Vector2.ZERO
	if not input_blocked():
		move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var buttons := _buttons()
	if (buttons & PlayerMotor.BTN_SPRINT) and stance != 0 and move.y < -0.3:
		stance = 0  # sprinting stands the operator up
	# recoil recovery: pull back part of the accumulated kick
	if _recoil_debt > 0.0:
		var rec: float = min(_recoil_debt, dt * 3.0 * max(_recoil_debt, 0.02))
		pitch -= rec
		_recoil_debt -= rec / 0.7
	seq += 1
	var inp := {"move": move, "yaw": yaw, "pitch": pitch, "buttons": buttons, "stance": stance}
	player.motor["reloading"] = player.inv_mirror.get("reloading", false)
	PlayerMotor.step(player, player.motor, inp, dt)
	history.append([seq, player.global_position])
	if history.size() > 120:
		history.pop_front()
	world.rpc_id(1, "c_input", seq, move, yaw, pitch, buttons, stance)
	_try_fire()

func _try_fire() -> void:
	var inv := player.inv_mirror
	if inv.is_empty() or input_blocked() or not player.is_alive_net():
		_semi_latch = false
		return
	var held := Input.is_action_pressed("fire")
	if not held:
		_semi_latch = false
		return
	var w: Dictionary = inv["weapons"][inv["active"]]
	var def := GameData.weapon(w["id"])
	var now := Time.get_ticks_msec() / 1000.0
	if inv.get("fire_mode", "semi") == "semi" and _semi_latch:
		return
	if now < _next_fire or inv.get("reloading", false) or player.motor["sprinting"] or inv.get("use_left", 0.0) > 0.0:
		return
	if player.motor["since_sprint"] < float(GameData.player_rules["sprint_to_fire_delay"]):
		return
	if int(w["mag"]) <= 0:
		_semi_latch = true
		if rig: rig.dry_fire()
		return
	_semi_latch = true
	_next_fire = now + 60.0 / float(def["rpm"])
	w["mag"] = int(w["mag"]) - 1  # predicted; server mirror will confirm
	world.rpc_id(1, "c_fire", yaw, pitch)
	var ads_mult := 0.55 if player.motor["ads"] else 1.0
	if player.motor["stance"] > 0:
		ads_mult *= 0.8
	var kick := deg_to_rad(float(def["recoil_pitch"])) * ads_mult
	pitch = clampf(pitch + kick, -1.45, 1.45)
	_recoil_debt += kick * 0.7
	yaw += deg_to_rad(float(def["recoil_yaw"])) * randf_range(-1.0, 1.0) * ads_mult
	if rig: rig.on_fire(def)
	player.inventory_changed.emit(inv)

## Server says: after input `ack_seq` you were at `server_pos`. Correct the prediction drift.
func reconcile(ack_seq: int, server_pos: Vector3) -> void:
	last_server_pos = server_pos
	while not history.is_empty() and history[0][0] < ack_seq:
		history.pop_front()
	if history.is_empty() or history[0][0] != ack_seq:
		if history.is_empty() and player.global_position.distance_to(server_pos) > 1.0:
			player.global_position = server_pos
		return
	var err: Vector3 = server_pos - history[0][1]
	var d := err.length()
	if d < 0.03:
		return
	if d > 2.0:
		Log.debug("net", "hard reconcile", {"err": d})
		player.global_position += err
		for h in history:
			h[1] += err
	else:
		var corr := err * 0.25   # soft correction to avoid visible snapping
		player.global_position += corr
		for h in history:
			h[1] += corr

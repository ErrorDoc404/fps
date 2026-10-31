class_name PlayerMotor
## Deterministic movement simulation shared by the server (authoritative) and the owning client (prediction).
## State lives in a plain Dictionary so it can be snapshotted and corrected.

enum Stance { STAND, CROUCH, PRONE }
const BTN_SPRINT := 1
const BTN_JUMP := 2
const BTN_ADS := 4
const BTN_INTERACT := 8
const BTN_FIRE := 16

static func new_state() -> Dictionary:
	var r := GameData.player_rules
	return {"stance": Stance.STAND, "sprinting": false, "ads": false, "stamina": float(r["max_stamina"]),
		"regen_delay": 0.0, "since_sprint": 10.0, "prev_buttons": 0, "height": float(r["heights"]["stand"]),
		"downed": false, "busy": false, "reloading": false, "weight": 0.0}

static func stance_height(st: Dictionary) -> float:
	var h: Dictionary = GameData.player_rules["heights"]
	if st["downed"]:
		return float(h["downed"])
	match int(st["stance"]):
		Stance.CROUCH: return float(h["crouch"])
		Stance.PRONE: return float(h["prone"])
	return float(h["stand"])

## Applies one input frame. `inp` = {"move": Vector2, "yaw": float, "buttons": int, "stance": int}.
static func step(body: CharacterBody3D, st: Dictionary, inp: Dictionary, dt: float) -> void:
	var r := GameData.player_rules
	var buttons: int = inp["buttons"]
	var pressed: int = buttons & ~int(st["prev_buttons"])
	st["prev_buttons"] = buttons
	body.rotation.y = inp["yaw"]

	# --- stance (validated: cannot stand up under a low ceiling) ---
	var want: int = clampi(int(inp["stance"]), 0, 2)
	if st["downed"]:
		want = Stance.PRONE
	if want < int(st["stance"]) and not _has_headroom(body, st, want):
		want = st["stance"]
	st["stance"] = want
	var target_h := stance_height(st)
	st["height"] = move_toward(float(st["height"]), target_h, dt * 3.5)
	_apply_shape(body, float(st["height"]))

	# --- speed selection ---
	var move: Vector2 = inp["move"]
	if move.length() > 1.0:
		move = move.normalized()
	var wants_sprint: bool = (buttons & BTN_SPRINT) != 0 and move.y < -0.3 and want == Stance.STAND and not st["downed"]
	var min_stam: float = r["sprint_min_stamina"]
	var can_sprint: bool = st["stamina"] > (0.0 if st["sprinting"] else min_stam)
	st["sprinting"] = wants_sprint and can_sprint and body.is_on_floor()
	st["ads"] = (buttons & BTN_ADS) != 0 and not st["sprinting"] and not st["downed"]
	var sp: Dictionary = r["speeds"]
	var speed: float = sp["walk"]
	if st["downed"]: speed = sp["downed"]
	elif want == Stance.PRONE: speed = sp["prone"]
	elif want == Stance.CROUCH: speed = sp["crouch"]
	elif st["sprinting"]: speed = sp["sprint"]
	elif st["ads"]: speed = sp["ads"]
	if st["busy"]:
		speed = min(speed, sp["crouch"])
	speed *= clampf(1.0 - (float(st["weight"]) - 5.0) * 0.025, 0.82, 1.0)  # heavy equipment slows the operator

	# --- stamina ---
	if st["sprinting"]:
		st["stamina"] = max(0.0, st["stamina"] - float(r["stamina_drain_per_sec"]) * dt)
		st["regen_delay"] = r["stamina_regen_delay"]
		st["since_sprint"] = 0.0
	else:
		st["since_sprint"] += dt
		if st["regen_delay"] > 0.0:
			st["regen_delay"] -= dt
		else:
			var regen: float = r["stamina_regen_per_sec"] * (1.4 if move == Vector2.ZERO else 1.0)
			st["stamina"] = min(float(r["max_stamina"]), st["stamina"] + regen * dt)

	# --- horizontal motion ---
	var basis := Basis(Vector3.UP, float(inp["yaw"]))
	var wish := basis * Vector3(move.x, 0, move.y)
	var target := wish * speed
	var vel := body.velocity
	var accel: float = r["accel"] if body.is_on_floor() else r["air_accel"]
	var hv := Vector2(vel.x, vel.z).move_toward(Vector2(target.x, target.z), accel * speed * dt)
	vel.x = hv.x
	vel.z = hv.y

	# --- vertical ---
	if body.is_on_floor():
		if (pressed & BTN_JUMP) != 0 and want == Stance.STAND and not st["downed"] and st["stamina"] >= float(r["jump_stamina"]):
			vel.y = r["jump_velocity"]
			st["stamina"] -= float(r["jump_stamina"])
			st["regen_delay"] = r["stamina_regen_delay"]
		else:
			vel.y = -0.5
	else:
		vel.y -= float(r["gravity"]) * dt
	body.velocity = vel
	body.move_and_slide()

static func _apply_shape(body: CharacterBody3D, h: float) -> void:
	var cs: CollisionShape3D = body.get_node("Shape")
	var cap: CapsuleShape3D = cs.shape
	cap.height = max(h, cap.radius * 2.0)
	cs.position.y = cap.height * 0.5

static func _has_headroom(body: CharacterBody3D, st: Dictionary, want: int) -> bool:
	var tmp := {"stance": want, "downed": false}
	var need := stance_height(tmp) - float(st["height"])
	if need <= 0.01:
		return true
	return not body.test_move(body.global_transform, Vector3.UP * need)

static func eye_height(st: Dictionary) -> float:
	return float(st["height"]) - float(GameData.player_rules["eye_offset"])

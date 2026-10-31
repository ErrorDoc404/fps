class_name SoldierModel
extends Node3D
## Third-person character presentation built from primitives (no character models were supplied).
## Used for remote operators and enemies. Procedural poses: stand / crouch / prone / downed / dead,
## walk cycle, aim pitch, firing kick.

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arms: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _gun: Node3D
var _phase := 0.0
var _kick := 0.0
var _lie := 0.0

func build(uniform: Color, vest: Color, accent: Color, helmet := true, scale_f := 1.0) -> void:
	scale = Vector3.ONE * scale_f
	_hips = Node3D.new(); _hips.position.y = 0.95; add_child(_hips)
	_leg_l = _limb(Vector3(-0.12, 0, 0), uniform, 0.92)
	_leg_r = _limb(Vector3(0.12, 0, 0), uniform, 0.92)
	_torso = Node3D.new(); _hips.add_child(_torso)
	Geo.box(Vector3(0.42, 0.55, 0.24), uniform, Vector3(0, 0.3, 0), _torso)
	Geo.box(Vector3(0.46, 0.4, 0.3), vest, Vector3(0, 0.33, 0), _torso)
	Geo.box(Vector3(0.12, 0.06, 0.02), accent, Vector3(-0.12, 0.45, -0.16), _torso)  # class/faction patch
	Geo.box(Vector3(0.3, 0.3, 0.12), vest.darkened(0.2), Vector3(0, 0.33, 0.2), _torso)  # pack
	_head = Node3D.new(); _head.position.y = 0.68; _torso.add_child(_head)
	Geo.box(Vector3(0.2, 0.24, 0.22), Color(0.72, 0.58, 0.46), Vector3(0, 0.1, 0), _head)
	if helmet:
		Geo.box(Vector3(0.27, 0.13, 0.28), vest.darkened(0.1), Vector3(0, 0.25, 0.01), _head)
	Geo.box(Vector3(0.18, 0.05, 0.02), Color(0.08, 0.08, 0.08), Vector3(0, 0.14, -0.115), _head)
	_arms = Node3D.new(); _arms.position = Vector3(0, 0.52, 0); _torso.add_child(_arms)
	Geo.box(Vector3(0.1, 0.1, 0.42), uniform, Vector3(-0.2, -0.08, -0.2), _arms)
	Geo.box(Vector3(0.1, 0.1, 0.42), uniform, Vector3(0.2, -0.08, -0.2), _arms)
	_gun = Node3D.new(); _gun.position = Vector3(0.06, -0.06, -0.38); _arms.add_child(_gun)
	Geo.box(Vector3(0.07, 0.12, 0.7), Color(0.12, 0.12, 0.12), Vector3.ZERO, _gun)
	Geo.box(Vector3(0.05, 0.16, 0.08), Color(0.12, 0.12, 0.12), Vector3(0, -0.12, 0.05), _gun)

func _limb(offset: Vector3, color: Color, length: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = offset
	_hips.add_child(pivot)
	Geo.box(Vector3(0.15, length, 0.17), color, Vector3(0, -length * 0.5, 0), pivot)
	Geo.box(Vector3(0.16, 0.1, 0.26), Color(0.15, 0.13, 0.1), Vector3(0, -length + 0.05, -0.04), pivot)
	return pivot

func set_gun_visible(v: bool) -> void:
	_gun.visible = v

func kick() -> void:
	_kick = 1.0

## stance: 0 stand, 1 crouch, 2 prone; state: "alive" | "downed" | "dead"
func pose(dt: float, stance: int, aim_pitch: float, speed: float, state := "alive") -> void:
	_phase += dt * (2.0 + speed * 2.2)
	_kick = max(0.0, _kick - dt * 8.0)
	var swing: float = sin(_phase) * clampf(speed / 4.0, 0.0, 1.0) * 0.6
	var target_lie := 0.0
	var hip_y := 0.95
	var knee := 0.0
	if state == "dead" or state == "downed":
		target_lie = 1.0
	elif stance == 2:
		target_lie = 1.0
	elif stance == 1:
		hip_y = 0.6
		knee = 0.9
	_lie = move_toward(_lie, target_lie, dt * 3.0)
	_hips.position.y = lerpf(hip_y, 0.18, _lie)
	_hips.rotation.x = lerpf(0.0, -PI / 2.0, _lie)
	_hips.rotation.z = (0.5 * _lie) if state != "alive" else 0.0
	_leg_l.rotation.x = swing + knee
	_leg_r.rotation.x = -swing + knee
	_torso.rotation.x = -knee * 0.25
	var aim := 0.0 if state != "alive" else aim_pitch
	if _lie > 0.5 and state == "alive":
		aim = clampf(aim_pitch, -0.3, 0.6) + PI / 2.0
	_arms.rotation.x = aim + _kick * 0.12 - (0.0 if state == "alive" else 1.2)
	_head.rotation.x = clampf(aim_pitch, -0.6, 0.6) * (1.0 - _lie)

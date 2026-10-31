class_name SoldierModel
extends Node3D
## Third-person character presentation (client only) using the supplied Synty POLYGON Military rigged characters.
## The pack ships skinned characters but no animation clips, so poses are solved procedurally every frame on the
## Synty humanoid rig: two-bone IK puts the hands on the weapon's grip / handguard and the feet on the ground
## (walk cycle, crouch), the spine follows aim pitch, fingers curl around the weapon, and the body lies down for
## prone / downed / dead. Static head attachments (helmets, goggles, hair) are bone-attached to `head`.
##   Task Force:  assault / medic / recon / support  (desert atlas)
##   Dominion:    infantry / heavy / spotter / command (urban / insurgent looks)

const CHR := "PM/Chr/"
const ATT := "PM/Fbx/"
const KINDS := {
	"assault": {"model": "PM/Chr/SK_Chr_Soldier_Male_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_01_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Helmet_01_Goggles_01.fbx", "PM/Fbx/SM_Chr_Attach_Helmet_01_Goggles_01_Glass.fbx"]},
	"medic": {"model": "PM/Chr/SK_Chr_Soldier_Female_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_01_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Helmet_11_Female.fbx"]},
	"recon": {"model": "PM/Chr/SK_Chr_Ghillie_Male_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_01_A.png", "head": []},
	"support": {"model": "PM/Chr/SK_Chr_Soldier_Male_02.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_01_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Helmet_07.fbx", "PM/Fbx/SM_Chr_Attach_Helmet_07_Glass.fbx", "PM/Fbx/SM_Chr_Attach_Headset_01.fbx"]},
	"infantry": {"model": "PM/Chr/SK_Chr_Insurgent_Male_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_01_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Helmet_02.fbx"]},
	"heavy": {"model": "PM/Chr/SK_Chr_Soldier_Male_02.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_02_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Helmet_10.fbx", "PM/Fbx/SM_Chr_Attach_Helmet_10_Visor.fbx"]},
	"spotter": {"model": "PM/Chr/SK_Chr_Ghillie_Male_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_02_A.png", "head": []},
	"command": {"model": "PM/Chr/SK_Chr_Leader_Male_01.fbx", "atlas": "PM/Textures/PolygonMilitary_Texture_02_A.png", "head": ["PM/Fbx/SM_Chr_Attach_Hair_Male_02.fbx"]},
}

var _body: Node3D          # the Synty instance (turned 180° so it faces -Z like the rest of the game)
var _sk: Skeleton3D
var _gun: Node3D
var _weapon_def: Dictionary
var _n := 0
var _parent := PackedInt32Array()
var _rest: Array[Transform3D] = []
var _child_dir: Array[Vector3] = []     # rest offset to first child, in bone-local space
var _b := {}                            # bone name -> index
var _palm_local := {}                   # hand bone -> palm normal in hand-local rest space
var _len := {}
var _phase := 0.0
var _kick := 0.0
var _lie := 0.0
var _crouch := 0.0
var _fp_hands: Array = []
var _fp := false               # first-person mode: wrist targets [right, left] in skeleton space

func build_kind(kind: String, weapon_id: String, scale_f := 1.0) -> void:
	var cfg: Dictionary = KINDS.get(kind, KINDS["assault"])
	scale = Vector3.ONE * scale_f
	_body = Poly.instance(cfg["model"], cfg["atlas"])
	_body.rotation_degrees.y = 180.0
	add_child(_body)
	_sk = _body.find_child("Skeleton3D", true, false)
	if _sk == null:
		return
	_n = _sk.get_bone_count()
	_parent.resize(_n)
	_child_dir.resize(_n)
	_rest.resize(_n)
	for i in _n:
		_parent[i] = _sk.get_bone_parent(i)
		_rest[i] = _sk.get_bone_rest(i)
		_b[_sk.get_bone_name(i)] = i
		_child_dir[i] = Vector3.ZERO
	for i in _n:
		var p := _parent[i]
		if p >= 0 and _child_dir[p] == Vector3.ZERO:
			_child_dir[p] = _rest[i].origin
	for i in _n:   # bones without children (finger tips) keep their parent's direction
		if _child_dir[i] == Vector3.ZERO and _parent[i] >= 0:
			_child_dir[i] = _rest[_parent[i]].basis.inverse() * _child_dir[_parent[i]]
	for h in ["Hand_L", "Hand_R"]:
		var g := _sk.get_bone_global_rest(_b[h])
		_palm_local[_b[h]] = g.basis.inverse() * Vector3.DOWN   # T-pose palms face down
	for s in ["L", "R"]:
		var lo := "l" if s == "L" else "r"
		_len["arm_a" + s] = _rest[_b["lowerarm_" + lo]].origin.length()
		_len["arm_b" + s] = _rest[_b["Hand_" + s]].origin.length()
		_len["leg_a" + s] = _rest[_b["calf_" + lo]].origin.length()
		_len["leg_b" + s] = _rest[_b["Foot_" + s]].origin.length()
	# head attachments are modelled in place on the T-pose: attach to `head` with the inverse rest transform
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	_sk.add_child(att)
	for rel in cfg["head"]:   # attachment meshes are authored relative to the head bone
		var m := Poly.instance(rel, cfg["atlas"])
		att.add_child(m)
	if weapon_id != "":
		set_weapon(weapon_id)

## First-person arms: same Synty character, head/neck and legs collapsed (bone scale) so only the
## arms, hands and sleeves are visible from the camera. Posed every frame with pose_fp().
func build_fp(kind: String) -> void:
	build_kind(kind, "")
	if _sk == null:
		return
	_fp = true   # torso / head / legs are collapsed in pose(); arms keep their true shoulders
	Geo.no_shadow(self)

## Eye point of this model in its own (parent) space, used to put the camera at the character's eyes.
func eye_offset() -> Vector3:
	return Basis(Vector3.UP, PI) * _sk.get_bone_global_rest(_b["eyes"]).origin

## wrist_r / wrist_l are given in this node's parent space; arms reach them with IK (never longer than the real arm).
func pose_fp(dt: float, wrist_r: Vector3, wrist_l: Vector3) -> void:
	if _sk == null:
		return
	var to_skel := (transform * _body.transform).affine_inverse()
	_fp_hands = [to_skel * wrist_r, to_skel * wrist_l]
	pose(dt, 0, 0.0, 0.0, "alive")

func set_weapon(weapon_id: String) -> void:
	var def := GameData.weapon(weapon_id)
	if def.is_empty() or _body == null:
		return
	var vis := _gun.visible if _gun else true
	if _gun:
		_gun.queue_free()
	_weapon_def = def
	_gun = WeaponModel.build(def)
	_gun.visible = vis
	_body.add_child(_gun)

func set_gun_visible(v: bool) -> void:
	if _gun:
		_gun.visible = v

func kick() -> void:
	_kick = 1.0

# ------------------------------------------------------------------ pose solver
static func _ik(s: Vector3, t: Vector3, a: float, b: float, pole: Vector3) -> Array:
	var d := t - s
	var l := clampf(d.length(), 0.02, a + b - 0.002)
	var dir := d.normalized()
	var ca := clampf((a * a + l * l - b * b) / (2.0 * a * l), -1.0, 1.0)
	var ang := acos(ca)
	var pp := (pole - dir * pole.dot(dir))
	pp = pp.normalized() if pp.length() > 0.0001 else Vector3.UP
	var elbow := s + (dir * cos(ang) + pp * sin(ang)) * a
	return [elbow, s + dir * l]

## Rotates global transform `g` of bone i so that its child direction points along `want` (skeleton space).
func _aim(i: int, g: Transform3D, want: Vector3) -> Transform3D:
	var d0 := (g.basis * _child_dir[i]).normalized()
	var d1 := want.normalized()
	if d0.dot(d1) > 0.99999:
		return g
	var axis := d0.cross(d1)
	if axis.length() < 0.00001:
		axis = Vector3.UP if absf(d0.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	g.basis = Basis(axis.normalized(), d0.angle_to(d1)) * g.basis
	return g

## stance: 0 stand, 1 crouch, 2 prone; state: "alive" | "downed" | "dead"
func pose(dt: float, stance: int, aim_pitch: float, speed: float, state := "alive") -> void:
	if _sk == null:
		return
	var moving := clampf(speed / 4.0, 0.0, 1.0)
	_phase += dt * (3.0 + speed * 2.2)
	_kick = maxf(0.0, _kick - dt * 8.0)
	var lying := state != "alive" or stance == 2
	_lie = move_toward(_lie, 1.0 if lying else 0.0, dt * 3.0)
	_crouch = move_toward(_crouch, 1.0 if (stance == 1 and not lying) else 0.0, dt * 4.0)
	# body orientation for prone (face down) / downed + dead (on the back)
	if state == "alive":
		_body.rotation = Vector3(-PI / 2.0 * _lie, PI, 0)
		_body.position = Vector3(0, 0.12 * _lie, 0.85 * _lie)
	else:
		_body.rotation = Vector3(PI / 2.0 * _lie, PI, 0.0)
		_body.position = Vector3(0, 0.15 * _lie, -0.85 * _lie)
	var armed := state == "alive" and (_gun != null or _fp_hands.size() == 2)
	# aim frame in skeleton space (+Z forward): pitch up rotates the muzzle toward +Y
	var gun_pitch := aim_pitch if stance != 2 else clampf(aim_pitch, -0.3, 0.5) + PI / 2.0
	var aim_b := Basis(Vector3.RIGHT, -gun_pitch - _kick * 0.08)
	var pelvis_drop := 0.38 * _crouch + absf(sin(_phase)) * 0.025 * moving * (1.0 - _crouch)
	var glob: Array[Transform3D] = []
	glob.resize(_n)
	var glob_true: Array[Transform3D] = []   # globals before first-person collapsing (true shoulder positions)
	glob_true.resize(_n)
	var targets := {}
	var palm := {}
	for i in _n:
		var p := _parent[i]
		var pg := glob_true[p] if p >= 0 else Transform3D.IDENTITY   # solve on the true (uncollapsed) skeleton
		var bn := _sk.get_bone_name(i)
		var g := pg * _rest[i]
		match bn:
			"Pelvis":
				g.origin.y -= pelvis_drop
				g.basis = Basis(Vector3.RIGHT, 0.2 * _crouch) * g.basis
			"spine_02", "spine_03":
				if stance != 2 and state == "alive":
					g.basis = Basis(Vector3.RIGHT, -aim_pitch * 0.35 + 0.08 * moving) * g.basis
			"neck_01":
				if state == "alive" and stance != 2:
					g.basis = Basis(Vector3.RIGHT, -aim_pitch * 0.25) * g.basis
			"UpperArm_R", "UpperArm_L":
				var side := "R" if bn.ends_with("R") else "L"
				var t: Vector3
				var pole: Vector3
				if armed and _fp_hands.size() == 2:
					t = _fp_hands[0 if side == "R" else 1]
					pole = Vector3(-0.8 if side == "R" else 0.8, -1.0, -0.6)
				elif armed:
					if not targets.has("gun"):
						var chest := glob[_b["spine_03"]].origin
						var gx := Transform3D(aim_b * Basis(Vector3.UP, PI), chest + aim_b * Vector3(-0.1, 0.02, 0.3))
						if stance == 2:
							gx.origin = chest + aim_b * Vector3(-0.08, 0.02, 0.35)
						targets["gun"] = gx
						_gun.transform = gx
					var gx2: Transform3D = targets["gun"]
					var mk := "Grip" if side == "R" else "LeftHand"
					var hand_pt: Vector3 = gx2 * (_gun.get_node(mk).position if _gun.has_node(mk) else Vector3.ZERO)
					t = hand_pt + aim_b * Vector3(0, -0.02, -0.07)    # wrist sits behind the palm
					pole = Vector3(-0.7 if side == "R" else 0.5, -1.0, -0.2)
				else:
					var sh := g.origin
					var downed := state == "downed"
					t = sh + Vector3(0.12 if side == "L" else -0.12, -0.5, 0.18 if downed else 0.05)
					pole = Vector3(0, 0, -1)
				var sol := _ik(g.origin, t, _len["arm_a" + side], _len["arm_b" + side], pole)
				targets["elbow" + side] = sol[0]
				targets["wrist" + side] = sol[1]
				g = _aim(i, g, sol[0] - g.origin)
			"lowerarm_r", "lowerarm_l":
				var side2 := "R" if bn.ends_with("r") else "L"
				g = _aim(i, g, targets["wrist" + side2] - g.origin)
			"Hand_R", "Hand_L":
				palm[i] = g.basis * _palm_local[i]
			"Thigh_R", "Thigh_L":
				var side3 := "R" if bn.ends_with("R") else "L"
				var sgn := 1.0 if side3 == "L" else -1.0
				var step := sin(_phase + (0.0 if side3 == "L" else PI))
				var foot := Vector3(g.origin.x + sgn * 0.02, 0.07, g.origin.z + step * 0.22 * moving)
				foot.y += maxf(0.0, cos(_phase + (0.0 if side3 == "L" else PI))) * 0.09 * moving
				if _crouch > 0.0:
					foot.z = lerpf(foot.z, g.origin.z + (0.28 if side3 == "L" else -0.18), _crouch)
				if lying:
					foot = g.origin + Vector3(sgn * 0.06, -0.78, 0.02 if state == "alive" else 0.1)
				var lsol := _ik(g.origin, foot, _len["leg_a" + side3], _len["leg_b" + side3], Vector3(0, 0, 1))
				targets["knee" + side3] = lsol[0]
				targets["ankle" + side3] = lsol[1]
				g = _aim(i, g, lsol[0] - g.origin)
			"calf_r", "calf_l":
				var side4 := "R" if bn.ends_with("r") else "L"
				g = _aim(i, g, targets["ankle" + side4] - g.origin)
			_:
				if armed and (bn.begins_with("finger") or bn.begins_with("indexFinger") or bn.begins_with("thumb")):
					var hand_i: int = _b["Hand_L"] if bn.ends_with("_l") else _b["Hand_R"]
					if palm.has(hand_i):
						var d0 := (g.basis * _child_dir[i]).normalized()
						var curl := 0.55 if bn.begins_with("thumb") else 0.85
						g = _aim(i, g, d0 * cos(curl) + (palm[hand_i] as Vector3) * sin(curl))
		glob_true[i] = g
		# First person: chest/head and legs collapse to nothing; clavicles re-expand so the arms stay full size
		# at their true shoulders. `glob` holds the actually-posed globals.
		var a := g
		if _fp:
			if bn in ["spine_02", "Thigh_L", "Thigh_R"]:
				a = Transform3D(g.basis * Basis.from_scale(Vector3.ONE * 0.005), g.origin)
			elif bn != "clavicle_l" and bn != "clavicle_r" and p >= 0:
				a = glob[p] * (pg.affine_inverse() * g)
		glob[i] = a
		var apg := glob[p] if p >= 0 else Transform3D.IDENTITY
		var local := apg.affine_inverse() * a
		_sk.set_bone_pose_position(i, local.origin)
		_sk.set_bone_pose_rotation(i, local.basis.orthonormalized().get_rotation_quaternion())
		_sk.set_bone_pose_scale(i, local.basis.get_scale())

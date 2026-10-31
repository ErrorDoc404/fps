class_name ViewModel
## First-person view model: a detailed WeaponModel plus gloved hands and sleeved forearms posed on the
## grip and handguard. Exposes the weapon's Muzzle / Mag / Sight markers for the rig (ADS alignment, reload).

const SHOULDER_R := Vector3(0.14, -0.26, 0.36)
const SHOULDER_L := Vector3(-0.42, -0.4, 0.02)

static func build(def: Dictionary) -> Node3D:
	var root := WeaponModel.build(def)
	var sleeve := Mat.camo("tf")
	var glove := Mat.fabric(Color(0.2, 0.19, 0.16))
	var pistol: bool = def.get("model", "") == "pistol"
	# right hand wraps the pistol grip
	var rh := Vector3(0.0, -0.055, 0.02)
	_hand(root, rh, glove, Vector3(-16, 0, 0), true)
	_limb(root, rh + Vector3(0.0, -0.01, 0.05), SHOULDER_R, 0.045, sleeve)
	_cuff(root, rh + Vector3(0.0, -0.012, 0.065), SHOULDER_R, glove)
	# left hand on the handguard / supporting hand under the grip for the pistol
	var lh: Vector3 = root.get_node("LeftHand").position
	_hand(root, lh + Vector3(0, -0.02, 0), glove, Vector3(0, 0, -20 if not pistol else -70), false)
	_limb(root, lh + Vector3(-0.01, -0.03, 0.03), SHOULDER_L if not pistol else Vector3(-0.1, -0.25, 0.32), 0.038, sleeve)
	_cuff(root, lh + Vector3(-0.012, -0.035, 0.045), SHOULDER_L if not pistol else Vector3(-0.1, -0.25, 0.32), glove)
	# watch on the left wrist (environmental detail)
	Geo.no_shadow(root)
	return root

## Box limb oriented from `a` to `b`.
static func _limb(root: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var n := Node3D.new()
	root.add_child(n)
	n.position = (a + b) * 0.5
	n.basis = Basis.looking_at(b - a, Vector3.UP)
	Geo.part(n, Vector3(r * 2.0, r * 1.8, a.distance_to(b)), Vector3.ZERO, m, Vector3.ZERO, r * 0.4)

static func _cuff(root: Node3D, a: Vector3, toward: Vector3, m: Material) -> void:
	var n := Node3D.new()
	root.add_child(n)
	n.position = a + (toward - a).normalized() * 0.03
	n.basis = Basis.looking_at(toward - a, Vector3.UP)
	Geo.part(n, Vector3(0.1, 0.09, 0.05), Vector3.ZERO, m, Vector3.ZERO, 0.015)

static func _hand(root: Node3D, at: Vector3, m: Material, rot: Vector3, right: bool) -> void:
	var h := Node3D.new()
	h.position = at
	h.rotation_degrees = rot
	root.add_child(h)
	var side := 1.0 if right else -1.0
	Geo.part(h, Vector3(0.03, 0.075, 0.07), Vector3(side * 0.024, 0, 0), m, Vector3.ZERO, 0.012)       # palm
	for i in 4:   # fingers curl around the grip / handguard
		Geo.part(h, Vector3(0.05, 0.016, 0.018), Vector3(-side * 0.008, 0.026 - i * 0.018, -0.03), m, Vector3(0, side * 20, 0), 0.006)
	Geo.part(h, Vector3(0.016, 0.016, 0.05), Vector3(-side * 0.02, 0.035, -0.012), m, Vector3(0, -side * 25, 0), 0.006)  # thumb

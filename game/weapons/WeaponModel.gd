class_name WeaponModel
## Detailed procedural weapon meshes (no weapon 3D models were supplied). Silhouettes follow the supplied
## Synty weapon side renders (Icons_Weapons/*_Side.png): VK-7 = SCAR-style carbine, RK-12 = AR-style rifle,
## Kestrel = P90-style bullpup PDW, Longbow = wood-furniture DMR, P9 = polymer pistol.
## Axes: muzzle toward -Z, +Y up, origin at the pistol grip / trigger. Markers: Muzzle, Mag, Sight, LeftHand.

static func build(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	var c: Array = def.get("color", [0.2, 0.2, 0.2])
	var tint := Color(c[0], c[1], c[2])
	match def.get("model", "rifle"):
		"rifle_heavy": _ar(root, tint)
		"smg": _pdw(root, tint)
		"dmr": _dmr(root, tint)
		"pistol": _pistol(root, tint)
		_: _carbine(root, tint)
	return root

static func _marker(root: Node3D, name: String, pos: Vector3) -> Node3D:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	root.add_child(m)
	return m

static func _rail(root: Node3D, z0: float, z1: float, y: float, m: Material) -> void:
	var len := z1 - z0
	Geo.part(root, Vector3(0.024, 0.012, len), Vector3(0, y, (z0 + z1) * 0.5), m, Vector3.ZERO, 0.002)
	var n := int(len / 0.012)
	for i in range(0, n, 2):
		Geo.part(root, Vector3(0.026, 0.006, 0.006), Vector3(0, y + 0.009, z0 + 0.006 + i * 0.012), m, Vector3.ZERO, 0.0)

static func _curved_mag(mag: Node3D, segs: int, seg_h: float, w: float, d: float, curve_deg: float, m: Material) -> void:
	var pos := Vector3.ZERO
	var ang := 0.0
	for i in segs:
		var piece := Geo.part(mag, Vector3(w, seg_h * 1.04, d), pos + Vector3(0, -seg_h * 0.5, 0), m, Vector3(ang, 0, 0), 0.004)
		var dir := Basis(Vector3.RIGHT, deg_to_rad(ang)) * Vector3(0, -seg_h, 0)
		pos += dir
		ang -= curve_deg / segs
	Geo.part(mag, Vector3(w + 0.006, 0.012, d + 0.006), pos, m, Vector3(ang, 0, 0), 0.003)

static func _red_dot(root: Node3D, z: float, y: float) -> float:
	var housing := Mat.polymer(Color(0.09, 0.09, 0.09))
	Geo.part(root, Vector3(0.03, 0.012, 0.05), Vector3(0, y + 0.006, z), housing, Vector3.ZERO, 0.003)
	for s in [-1, 1]:   # open window: side walls + hood, so the shooter can look through it
		Geo.part(root, Vector3(0.005, 0.04, 0.05), Vector3(s * 0.0165, y + 0.03, z), housing, Vector3.ZERO, 0.002)
	Geo.part(root, Vector3(0.038, 0.006, 0.052), Vector3(0, y + 0.052, z), housing, Vector3.ZERO, 0.002)
	Geo.part(root, Vector3(0.03, 0.03, 0.002), Vector3(0, y + 0.031, z - 0.019), Mat.glass(Color(0.4, 0.8, 0.6, 0.25)), Vector3.ZERO, 0.0)
	Geo.part(root, Vector3(0.0025, 0.0025, 0.001), Vector3(0, y + 0.031, z - 0.021), Mat.emissive(Color(1, 0.1, 0.05), 6.0), Vector3.ZERO, 0.0)
	return y + 0.031

static func _flash_hider(root: Node3D, z: float, y: float, m: Material) -> float:
	Geo.tube(root, 0.011, 0.05, Vector3(0, y, z - 0.025), m, Vector3(90, 0, 0), 8)
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		Geo.part(root, Vector3(0.004, 0.004, 0.03), Vector3(cos(a) * 0.009, y + sin(a) * 0.009, z - 0.055), m, Vector3.ZERO, 0.0)
	return z - 0.07

static func _grip(root: Node3D, m: Material, z := 0.0) -> void:
	Geo.part(root, Vector3(0.03, 0.1, 0.042), Vector3(0, -0.06, z + 0.012), m, Vector3(-16, 0, 0), 0.008)
	Geo.part(root, Vector3(0.006, 0.03, 0.05), Vector3(0, -0.02, z - 0.04), m, Vector3.ZERO, 0.002)   # trigger guard
	Geo.part(root, Vector3(0.004, 0.018, 0.006), Vector3(0, -0.012, z - 0.03), Mat.metal(Color(0.15, 0.15, 0.15)), Vector3(10, 0, 0), 0.0)

# ------------------------------------------------------------------ archetypes
static func _carbine(r: Node3D, tint: Color) -> void:   # VK-7: SCAR-style
	var body := Mat.polymer(tint.lightened(0.05))
	var metal := Mat.gunmetal()
	Geo.part(r, Vector3(0.05, 0.05, 0.42), Vector3(0, 0.035, -0.12), body, Vector3.ZERO, 0.006)          # upper receiver
	Geo.part(r, Vector3(0.046, 0.04, 0.2), Vector3(0, -0.005, -0.02), body, Vector3.ZERO, 0.006)         # lower receiver
	Geo.part(r, Vector3(0.052, 0.012, 0.04), Vector3(0, 0.03, -0.05), metal, Vector3.ZERO, 0.002)        # ejection port cover
	Geo.part(r, Vector3(0.012, 0.012, 0.03), Vector3(-0.03, 0.045, -0.2), metal, Vector3.ZERO, 0.002)    # charging handle
	_rail(r, -0.33, 0.08, 0.066, metal)
	Geo.part(r, Vector3(0.055, 0.045, 0.2), Vector3(0, 0.03, -0.4), body, Vector3.ZERO, 0.008)           # handguard
	for s in [-1, 1]:
		Geo.part(r, Vector3(0.006, 0.012, 0.15), Vector3(s * 0.03, 0.025, -0.4), metal, Vector3.ZERO, 0.0)  # side rails
	Geo.tube(r, 0.01, 0.2, Vector3(0, 0.03, -0.6), metal, Vector3(90, 0, 0), 8)
	Geo.part(r, Vector3(0.008, 0.035, 0.012), Vector3(0, 0.07, -0.47), metal, Vector3.ZERO, 0.002)       # folded front sight
	var mz := _flash_hider(r, -0.7, 0.03, metal)
	_grip(r, body)
	# folding stock with cheek riser
	Geo.part(r, Vector3(0.03, 0.05, 0.2), Vector3(0, 0.02, 0.18), body, Vector3.ZERO, 0.008)
	Geo.part(r, Vector3(0.034, 0.09, 0.04), Vector3(0, 0.0, 0.29), body, Vector3.ZERO, 0.01)
	Geo.part(r, Vector3(0.03, 0.02, 0.12), Vector3(0, 0.052, 0.2), body, Vector3.ZERO, 0.006)
	Geo.part(r, Vector3(0.036, 0.095, 0.012), Vector3(0, 0.0, 0.312), Mat.rubber(), Vector3.ZERO, 0.004)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.02, -0.1)
	r.add_child(mag)
	_curved_mag(mag, 5, 0.032, 0.026, 0.06, 18.0, Mat.polymer(Color(0.12, 0.12, 0.12)))
	var sight_y := _red_dot(r, -0.08, 0.072)
	_marker(r, "Sight", Vector3(0, sight_y, 0))
	_marker(r, "Muzzle", Vector3(0, 0.03, mz))
	_marker(r, "LeftHand", Vector3(-0.02, 0.0, -0.4))

static func _ar(r: Node3D, tint: Color) -> void:   # RK-12: AR-style with quad rail
	var furn := Mat.polymer(tint)
	var metal := Mat.gunmetal()
	Geo.part(r, Vector3(0.046, 0.05, 0.24), Vector3(0, 0.03, -0.06), metal, Vector3.ZERO, 0.005)        # upper
	Geo.part(r, Vector3(0.044, 0.045, 0.18), Vector3(0, -0.012, -0.02), metal, Vector3.ZERO, 0.005)     # lower
	Geo.part(r, Vector3(0.03, 0.03, 0.03), Vector3(0.026, 0.03, -0.04), metal, Vector3.ZERO, 0.004)     # forward assist
	_rail(r, -0.5, 0.06, 0.064, metal)
	Geo.part(r, Vector3(0.056, 0.056, 0.3), Vector3(0, 0.03, -0.33), metal, Vector3.ZERO, 0.006)        # quad rail
	for s in [-1, 1]:
		_rail_side(r, s * 0.031, -0.47, -0.19, 0.03, metal)
	Geo.tube(r, 0.011, 0.22, Vector3(0, 0.03, -0.58), metal, Vector3(90, 0, 0), 8)
	Geo.part(r, Vector3(0.012, 0.06, 0.02), Vector3(0, 0.07, -0.55), metal, Vector3.ZERO, 0.002)         # A2 front sight
	var mz := _flash_hider(r, -0.69, 0.03, metal)
	_grip(r, furn)
	Geo.tube(r, 0.016, 0.2, Vector3(0, 0.03, 0.15), metal, Vector3(90, 0, 0), 8)                         # buffer tube
	Geo.part(r, Vector3(0.036, 0.075, 0.14), Vector3(0, 0.005, 0.2), furn, Vector3.ZERO, 0.01)         # stock
	Geo.part(r, Vector3(0.038, 0.09, 0.014), Vector3(0, -0.002, 0.275), Mat.rubber(), Vector3.ZERO, 0.004)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.032, -0.08)
	r.add_child(mag)
	_curved_mag(mag, 5, 0.03, 0.024, 0.062, 16.0, Mat.metal(Color(0.3, 0.3, 0.28), 0.5))
	# holographic sight
	var h := Mat.polymer(Color(0.1, 0.1, 0.1))
	Geo.part(r, Vector3(0.04, 0.016, 0.08), Vector3(0, 0.078, -0.06), h, Vector3.ZERO, 0.004)
	for s in [-1, 1]:   # hood: open window
		Geo.part(r, Vector3(0.005, 0.044, 0.072), Vector3(s * 0.02, 0.106, -0.062), h, Vector3.ZERO, 0.002)
	Geo.part(r, Vector3(0.045, 0.006, 0.072), Vector3(0, 0.131, -0.062), h, Vector3.ZERO, 0.002)
	Geo.part(r, Vector3(0.036, 0.032, 0.002), Vector3(0, 0.106, -0.09), Mat.glass(Color(0.5, 0.75, 0.9, 0.25)), Vector3.ZERO, 0.0)
	Geo.part(r, Vector3(0.003, 0.003, 0.001), Vector3(0, 0.106, -0.092), Mat.emissive(Color(1, 0.15, 0.05), 6.0), Vector3.ZERO, 0.0)
	_marker(r, "Sight", Vector3(0, 0.106, 0))
	_marker(r, "Muzzle", Vector3(0, 0.03, mz))
	_marker(r, "LeftHand", Vector3(-0.02, 0.0, -0.36))

static func _rail_side(r: Node3D, x: float, z0: float, z1: float, y: float, m: Material) -> void:
	var len := z1 - z0
	for i in int(len / 0.024):
		Geo.part(r, Vector3(0.008, 0.016, 0.01), Vector3(x, y, z0 + 0.012 + i * 0.024), m, Vector3.ZERO, 0.0)

static func _pdw(r: Node3D, tint: Color) -> void:   # Kestrel: P90-style bullpup
	var body := Mat.polymer(tint.lightened(0.06))
	var metal := Mat.gunmetal()
	Geo.part(r, Vector3(0.056, 0.09, 0.38), Vector3(0, 0.0, 0.0), body, Vector3.ZERO, 0.02)              # main body
	Geo.part(r, Vector3(0.05, 0.05, 0.12), Vector3(0, -0.06, -0.1), body, Vector3(12, 0, 0), 0.015)     # front grip lip
	Geo.part(r, Vector3(0.05, 0.03, 0.06), Vector3(0, -0.07, 0.02), body, Vector3.ZERO, 0.01)          # thumbhole grip
	Geo.part(r, Vector3(0.05, 0.1, 0.06), Vector3(0, -0.02, 0.18), body, Vector3.ZERO, 0.015)           # butt
	Geo.part(r, Vector3(0.006, 0.02, 0.006), Vector3(0, -0.04, -0.05), Mat.metal(Color(0.15, 0.15, 0.15)), Vector3.ZERO, 0.0)
	Geo.tube(r, 0.01, 0.07, Vector3(0, 0.012, -0.22), metal, Vector3(90, 0, 0), 8)
	_rail(r, -0.14, 0.1, 0.058, metal)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, 0.05, 0.0)
	r.add_child(mag)
	Geo.part(mag, Vector3(0.05, 0.016, 0.32), Vector3.ZERO, Mat.glass(Color(0.25, 0.2, 0.15, 0.7)), Vector3.ZERO, 0.004)  # translucent top mag
	Geo.part(mag, Vector3(0.04, 0.008, 0.3), Vector3(0, -0.004, 0), Mat.metal(Color(0.6, 0.5, 0.25), 0.4), Vector3.ZERO, 0.0)  # visible rounds
	var sight_y := _red_dot(r, -0.02, 0.064)
	_marker(r, "Sight", Vector3(0, sight_y, 0))
	_marker(r, "Muzzle", Vector3(0, 0.012, -0.26))
	_marker(r, "LeftHand", Vector3(-0.02, -0.05, -0.12))

static func _dmr(r: Node3D, tint: Color) -> void:   # Longbow: wood furniture DMR with scope
	var wood := Mat.wood(Color(0.58, 0.36, 0.2))
	var metal := Mat.gunmetal(tint.darkened(0.3))
	Geo.part(r, Vector3(0.044, 0.05, 0.3), Vector3(0, 0.025, -0.08), metal, Vector3.ZERO, 0.005)          # receiver
	Geo.part(r, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.022, -0.38), wood, Vector3.ZERO, 0.012)           # handguard
	for i in 3:
		Geo.part(r, Vector3(0.052, 0.012, 0.03), Vector3(0, 0.03, -0.3 - i * 0.07), Mat.polymer(), Vector3.ZERO, 0.002)  # vents
	Geo.tube(r, 0.011, 0.36, Vector3(0, 0.025, -0.7), metal, Vector3(90, 0, 0), 8)
	var mz := _flash_hider(r, -0.88, 0.025, metal)
	Geo.part(r, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.06, 0.02), wood, Vector3(-20, 0, 0), 0.01)      # pistol grip
	Geo.part(r, Vector3(0.006, 0.03, 0.05), Vector3(0, -0.02, -0.03), metal, Vector3.ZERO, 0.002)
	# thumbhole stock
	Geo.part(r, Vector3(0.036, 0.03, 0.28), Vector3(0, 0.035, 0.2), wood, Vector3(4, 0, 0), 0.01)
	Geo.part(r, Vector3(0.036, 0.03, 0.22), Vector3(0, -0.05, 0.22), wood, Vector3(-12, 0, 0), 0.01)
	Geo.part(r, Vector3(0.038, 0.13, 0.05), Vector3(0, -0.01, 0.33), wood, Vector3.ZERO, 0.012)
	Geo.part(r, Vector3(0.038, 0.035, 0.08), Vector3(0, 0.06, 0.2), wood, Vector3.ZERO, 0.01)            # cheek rest
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.01, -0.12)
	r.add_child(mag)
	_curved_mag(mag, 4, 0.028, 0.022, 0.07, 10.0, Mat.metal(Color(0.15, 0.15, 0.15), 0.5))
	# scope + mount
	var sm := Mat.gunmetal(Color(0.1, 0.1, 0.1))
	Geo.part(r, Vector3(0.03, 0.02, 0.12), Vector3(0, 0.06, -0.08), sm, Vector3.ZERO, 0.004)
	Geo.tube(r, 0.018, 0.24, Vector3(0, 0.095, -0.08), sm, Vector3(90, 0, 0), 12)
	Geo.tube(r, 0.024, 0.06, Vector3(0, 0.095, -0.23), sm, Vector3(90, 0, 0), 12, 0.018)
	Geo.tube(r, 0.022, 0.05, Vector3(0, 0.095, 0.06), sm, Vector3(90, 0, 0), 12)
	Geo.tube(r, 0.01, 0.025, Vector3(0, 0.122, -0.08), sm, Vector3.ZERO, 8)                              # elevation turret
	Geo.tube(r, 0.01, 0.025, Vector3(0.024, 0.095, -0.08), sm, Vector3(0, 0, 90), 8)
	Geo.tube(r, 0.021, 0.002, Vector3(0, 0.095, -0.262), Mat.glass(Color(0.3, 0.5, 0.7, 0.6)), Vector3(90, 0, 0), 12)
	_marker(r, "Sight", Vector3(0, 0.095, 0))
	_marker(r, "Muzzle", Vector3(0, 0.025, mz))
	_marker(r, "LeftHand", Vector3(-0.02, -0.005, -0.4))

static func _pistol(r: Node3D, tint: Color) -> void:   # P9: polymer striker pistol
	var frame := Mat.polymer(tint.lightened(0.05))
	var slide := Mat.gunmetal(Color(0.16, 0.16, 0.17))
	Geo.part(r, Vector3(0.028, 0.03, 0.19), Vector3(0, 0.028, -0.07), slide, Vector3.ZERO, 0.004)       # slide
	for i in 6:
		Geo.part(r, Vector3(0.03, 0.022, 0.003), Vector3(0, 0.03, 0.0 + i * 0.006), Mat.metal(Color(0.1, 0.1, 0.1)), Vector3.ZERO, 0.0)  # serrations
	Geo.part(r, Vector3(0.026, 0.022, 0.17), Vector3(0, 0.002, -0.06), frame, Vector3.ZERO, 0.004)       # frame
	Geo.part(r, Vector3(0.016, 0.006, 0.05), Vector3(0, -0.012, -0.12), frame, Vector3.ZERO, 0.002)      # accessory rail
	Geo.part(r, Vector3(0.028, 0.11, 0.046), Vector3(0, -0.055, 0.0), frame, Vector3(-18, 0, 0), 0.008)  # grip
	Geo.part(r, Vector3(0.006, 0.026, 0.045), Vector3(0, -0.016, -0.05), frame, Vector3.ZERO, 0.002)
	Geo.part(r, Vector3(0.004, 0.016, 0.006), Vector3(0, -0.01, -0.045), Mat.metal(Color(0.15, 0.15, 0.15)), Vector3(8, 0, 0), 0.0)
	Geo.part(r, Vector3(0.004, 0.006, 0.006), Vector3(0, 0.046, -0.155), Mat.emissive(Color(0.6, 1.0, 0.4), 1.5), Vector3.ZERO, 0.0)  # tritium front
	Geo.part(r, Vector3(0.022, 0.008, 0.008), Vector3(0, 0.046, 0.015), slide, Vector3.ZERO, 0.0)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.11, 0.018)
	r.add_child(mag)
	Geo.part(mag, Vector3(0.024, 0.014, 0.04), Vector3.ZERO, frame, Vector3(-18, 0, 0), 0.003)
	_marker(r, "Sight", Vector3(0, 0.048, 0))
	_marker(r, "Muzzle", Vector3(0, 0.028, -0.17))
	_marker(r, "LeftHand", Vector3(-0.018, -0.055, 0.005))

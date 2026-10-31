class_name ViewModel
## Builds first-person weapon + arms meshes from a weapon definition's "model" archetype.
## Returns a Node3D with child markers: "Muzzle", "Mag", "Sight" (sight height used for ADS alignment).

const SKIN := Color(0.7, 0.55, 0.43)
const SLEEVE := Color(0.27, 0.3, 0.22)
const GLOVE := Color(0.12, 0.12, 0.11)

static func build(def: Dictionary) -> Node3D:
	var root := Node3D.new()
	var c: Array = def.get("color", [0.2, 0.2, 0.2])
	var col := Color(c[0], c[1], c[2])
	var dark := col.darkened(0.35)
	var model: String = def.get("model", "rifle")
	var length := 0.62
	var barrel := 0.28
	var mag_h := 0.16
	var stock := true
	var scope := false
	match model:
		"rifle_heavy": length = 0.7; barrel = 0.32; mag_h = 0.17
		"smg": length = 0.42; barrel = 0.12; mag_h = 0.2
		"dmr": length = 0.78; barrel = 0.4; mag_h = 0.12; scope = true
		"pistol": length = 0.18; barrel = 0.02; mag_h = 0.0; stock = false
	# receiver
	Geo.box(Vector3(0.05, 0.075, length), col, Vector3(0, 0, -length * 0.5 + 0.1), root, 0.6, 0.3)
	Geo.box(Vector3(0.052, 0.02, length * 0.85), dark, Vector3(0, 0.045, -length * 0.45 + 0.1), root, 0.5, 0.4)  # top rail
	if barrel > 0.0:
		Geo.cyl(0.012, barrel, dark, Vector3(0, 0.012, -length + 0.1 - barrel * 0.5), root, Vector3(90, 0, 0))
		Geo.box(Vector3(0.06, 0.06, length * 0.35), col.lightened(0.05), Vector3(0, 0.0, -length * 0.75 + 0.1), root)  # handguard
	if stock:
		Geo.box(Vector3(0.04, 0.07, 0.2), dark, Vector3(0, -0.02, 0.2), root)
	Geo.box(Vector3(0.035, 0.09, 0.045), dark, Vector3(0, -0.075, 0.03), root)  # grip
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.04, -0.12 if model != "pistol" else 0.03)
	root.add_child(mag)
	if mag_h > 0.0:
		Geo.box(Vector3(0.03, mag_h, 0.05), dark, Vector3(0, -mag_h * 0.5, 0), mag)
	var sight := Marker3D.new()
	sight.name = "Sight"
	if scope:
		Geo.cyl(0.022, 0.2, Color(0.08, 0.08, 0.08), Vector3(0, 0.085, -0.15), root, Vector3(90, 0, 0))
		sight.position = Vector3(0, 0.085, 0)
	elif model == "pistol":
		Geo.box(Vector3(0.008, 0.012, 0.008), Color(0.9, 0.9, 0.9), Vector3(0, 0.045, -0.06), root)
		sight.position = Vector3(0, 0.05, 0)
	else:
		Geo.box(Vector3(0.04, 0.04, 0.05), Color(0.08, 0.08, 0.08), Vector3(0, 0.075, -0.05), root)  # red-dot housing
		var dot := Geo.box(Vector3(0.004, 0.004, 0.002), Color(1, 0.1, 0.1), Vector3(0, 0.078, -0.03), root)
		dot.material_override = Geo.mat(Color(1, 0.1, 0.1), 0.5, 0.0, Color(1, 0, 0))
		sight.position = Vector3(0, 0.078, 0)
	root.add_child(sight)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.012, -length + 0.1 - barrel - 0.01)
	root.add_child(muzzle)
	_arms(root, model == "pistol", length)
	return root

static func _arms(root: Node3D, pistol: bool, length: float) -> void:
	# right hand on grip, left hand on handguard (or supporting the pistol grip)
	var rh := Geo.box(Vector3(0.06, 0.07, 0.09), GLOVE, Vector3(0.012, -0.07, 0.04), root)
	Geo.box(Vector3(0.07, 0.07, 0.3), SLEEVE, Vector3(0.04, -0.06, 0.2), rh)
	var lpos := Vector3(-0.01, -0.06, 0.02) if pistol else Vector3(-0.015, -0.045, -length * 0.62 + 0.1)
	var lh := Geo.box(Vector3(0.06, 0.06, 0.09), GLOVE, lpos, root)
	Geo.box(Vector3(0.07, 0.07, 0.34), SLEEVE, Vector3(-0.07, -0.05, 0.2), lh).rotation_degrees.y = -25.0

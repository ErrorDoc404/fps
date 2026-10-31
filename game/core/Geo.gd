class_name Geo
## Small helpers for building primitive geometry (graybox meshes, colliders and materials) in code.

static var _mats := {}

static func mat(color: Color, roughness := 0.85, metallic := 0.0, emission := Color.BLACK) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), roughness, metallic, emission.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 2.0
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func box(size: Vector3, color: Color, pos := Vector3.ZERO, parent: Node = null, rough := 0.85, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, rough, metal)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi

static func cyl(radius: float, height: float, color: Color, pos := Vector3.ZERO, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot
	if parent:
		parent.add_child(mi)
	return mi

static func capsule(radius: float, height: float, color: Color, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi

static func sphere(radius: float, color: Color, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi

## Static solid block: visible mesh + collider on the world layer. Used for level geometry.
static func solid(parent: Node, size: Vector3, pos: Vector3, color: Color, rot_y_deg := 0.0, visible := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = rot_y_deg
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	if visible:
		box(size, color, Vector3.ZERO, body)
	parent.add_child(body)
	return body

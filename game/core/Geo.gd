class_name Geo
## Geometry kit for code-built level art, characters and weapons (no 3D models were supplied).
## Low-poly, flat-shaded chamfered shapes in the Synty POLYGON style, paired with the PBR library in `world/Mat.gd`.
## `Geo.visuals = false` on the dedicated server: colliders are still built, presentation meshes are skipped.

static var visuals := true
static var _mats := {}
static var _mesh_cache := {}

# ------------------------------------------------------------------ legacy flat-colour helpers (FX, debug)
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

static func _material(m: Variant) -> Material:
	if m is Material:
		return m
	return mat(m)

# ------------------------------------------------------------------ meshes
## Chamfered box (flat normals). bevel = chamfer size in metres (0 → plain box).
static func bevel_box_mesh(size: Vector3, bevel: float) -> Mesh:
	var b := minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)
	var key := "bb%s|%.3f" % [size, b]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: Mesh
	if b <= 0.0005:
		var bm := BoxMesh.new()
		bm.size = size
		mesh = bm
	else:
		var h := size * 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var px := func(sx, sy, sz): return Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
		var py := func(sx, sy, sz): return Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
		var pz := func(sx, sy, sz): return Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
		for s in [-1, 1]:
			_poly(st, [px.call(s, -1, -1), px.call(s, 1, -1), px.call(s, 1, 1), px.call(s, -1, 1)], size)
			_poly(st, [py.call(-1, s, -1), py.call(1, s, -1), py.call(1, s, 1), py.call(-1, s, 1)], size)
			_poly(st, [pz.call(-1, -1, s), pz.call(1, -1, s), pz.call(1, 1, s), pz.call(-1, 1, s)], size)
		for a in [-1, 1]:
			for c in [-1, 1]:
				_poly(st, [px.call(a, c, -1), px.call(a, c, 1), py.call(a, c, 1), py.call(a, c, -1)], size)  # X-Y edges
				_poly(st, [px.call(a, -1, c), px.call(a, 1, c), pz.call(a, 1, c), pz.call(a, -1, c)], size)  # X-Z edges
				_poly(st, [py.call(-1, a, c), py.call(1, a, c), pz.call(1, a, c), pz.call(-1, a, c)], size)  # Y-Z edges
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				for sz in [-1, 1]:
					_poly(st, [px.call(sx, sy, sz), py.call(sx, sy, sz), pz.call(sx, sy, sz)], size)
		mesh = st.commit()
	_mesh_cache[key] = mesh
	return mesh

## Adds a convex planar polygon with an outward flat normal and box-projected UVs.
static func _poly(st: SurfaceTool, pts: Array, size: Vector3) -> void:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var n: Vector3 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	if n.dot(c) > 0.0:
		pts.reverse()
		n = -n
	var outward := -n
	for i in range(1, pts.size() - 1):
		for p in [pts[0], pts[i], pts[i + 1]]:
			st.set_normal(outward)
			var a := outward.abs()
			var uv := Vector2(p.z, p.y) if a.x >= a.y and a.x >= a.z else (Vector2(p.x, p.z) if a.y >= a.z else Vector2(p.x, p.y))
			st.set_uv(uv)
			st.add_vertex(p)

static func cyl_mesh(r_top: float, r_bottom: float, height: float, segments := 10) -> Mesh:
	var key := "cy%.3f|%.3f|%.3f|%d" % [r_top, r_bottom, height, segments]
	if not _mesh_cache.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bottom
		cm.height = height
		cm.radial_segments = segments
		cm.rings = 1
		_mesh_cache[key] = cm
	return _mesh_cache[key]

static func sphere_mesh(radius: float, segments := 10) -> Mesh:
	var key := "sp%.3f|%d" % [radius, segments]
	if not _mesh_cache.has(key):
		var sm := SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
		sm.radial_segments = segments
		sm.rings = maxi(4, segments / 2)
		_mesh_cache[key] = sm
	return _mesh_cache[key]

# ------------------------------------------------------------------ node helpers (presentation only)
## Chamfered part. `m` is a Material or Color. Returns the MeshInstance3D (or a bare Node3D when visuals are off).
static func part(parent: Node, size: Vector3, pos: Vector3, m: Variant, rot_deg := Vector3.ZERO, bevel := 0.02) -> Node3D:
	if not visuals:
		var n := Node3D.new()
		n.position = pos
		n.rotation_degrees = rot_deg
		parent.add_child(n)
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = bevel_box_mesh(size, bevel)
	mi.material_override = _material(m)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func tube(parent: Node, radius: float, length: float, pos: Vector3, m: Variant, rot_deg := Vector3.ZERO, segments := 10, r_top := -1.0) -> Node3D:
	if not visuals:
		var n := Node3D.new()
		n.position = pos
		parent.add_child(n)
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = cyl_mesh(radius if r_top < 0.0 else r_top, radius, length, segments)
	mi.material_override = _material(m)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func ball(parent: Node, radius: float, pos: Vector3, m: Variant, segments := 10) -> Node3D:
	if not visuals:
		var n := Node3D.new()
		n.position = pos
		parent.add_child(n)
		return n
	var mi := MeshInstance3D.new()
	mi.mesh = sphere_mesh(radius, segments)
	mi.material_override = _material(m)
	mi.position = pos
	parent.add_child(mi)
	return mi

# Legacy names kept for existing callers (FX, interact markers).
static func box(size: Vector3, color: Color, pos := Vector3.ZERO, parent: Node = null, rough := 0.85, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = bevel_box_mesh(size, 0.0)
	mi.material_override = mat(color, rough, metal)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi

static func cyl(radius: float, height: float, color: Color, pos := Vector3.ZERO, parent: Node = null, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = cyl_mesh(radius, radius, height, 12)
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot
	if parent:
		parent.add_child(mi)
	return mi

static func sphere(radius: float, color: Color, pos := Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = sphere_mesh(radius, 12)
	mi.material_override = mat(color)
	mi.position = pos
	if parent:
		parent.add_child(mi)
	return mi

# ------------------------------------------------------------------ collision
## Static collider on the world layer (always built: client and server must share identical collision).
## With visuals on, `m` (Material/Color) is rendered as a chamfered mesh unless m == null.
static func solid(parent: Node, size: Vector3, pos: Vector3, m: Variant, rot_y_deg := 0.0, bevel := 0.03) -> StaticBody3D:
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
	if visuals and m != null:
		part(body, size, Vector3.ZERO, m, Vector3.ZERO, bevel)
	parent.add_child(body)
	return body

static func solid_cyl(parent: Node, radius: float, height: float, pos: Vector3, m: Variant, segments := 14) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	body.add_child(cs)
	if visuals and m != null:
		tube(body, radius, height, Vector3.ZERO, m, Vector3.ZERO, segments)
	parent.add_child(body)
	return body

static func no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		no_shadow(c)

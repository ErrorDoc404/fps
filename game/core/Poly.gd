class_name Poly
## Loader for the supplied Synty POLYGON 3D packs (client presentation only).
## Paths: "PM/..." = POLYGON_Military_SourceFiles_v4/SourceFiles, "PW/..." = POLYGON_Military_Warehouse_SourceFiles_v1/SourceFiles,
## copied by tools/import_assets.py into res://assets/polygon/ (atlases downscaled to 2048 px).
## Synty FBX files reference .psd textures that do not exist, so the matching atlas PNG is assigned here.

const ROOT := "res://assets/polygon/"
const ATLAS_DESERT := "PM/Textures/PolygonMilitary_Texture_01_A.png"
const ATLAS_URBAN := "PM/Textures/PolygonMilitary_Texture_02_A.png"
const ATLAS_WOOD := "PM/Textures/PolygonMilitary_Texture_04_A.png"
const ATLAS_WEAPONS := "PM/Textures/PolygonMilitary_Weapons_01.png"
const ATLAS_WEAPONS_TAN := "PM/Textures/PolygonMilitary_Weapons_04.png"

static var _scenes := {}
static var _mats := {}

## Loads every character / attachment / weapon model and atlas up front (during the deployment loading screen)
## so nothing is read from disk when operators or enemies spawn mid-mission.
static func preload_gameplay_models() -> void:
	for cfg in SoldierModel.KINDS.values():
		scene(cfg["model"])
		atlas(cfg["atlas"])
		for h in cfg["head"]:
			scene(h)
	for w in GameData.weapons.values():
		var sy: Dictionary = w.get("synty", {})
		if sy.is_empty():
			continue
		atlas(sy["atlas"])
		for p in sy["parts"]:
			scene(p)
		if sy.get("mag", "") != "":
			scene(sy["mag"])
		for s in sy.get("sights", []):
			scene(s["part"])

static func available(rel: String) -> bool:
	return ResourceLoader.exists(ROOT + rel)

static func scene(rel: String) -> PackedScene:
	if not _scenes.has(rel):
		_scenes[rel] = load(ROOT + rel) if available(rel) else null
		if _scenes[rel] == null:
			push_warning("Poly: missing model " + rel)
	return _scenes[rel]

static func atlas(tex_rel: String, glass := false) -> StandardMaterial3D:
	var key := tex_rel + ("|glass" if glass else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(ROOT + tex_rel) if ResourceLoader.exists(ROOT + tex_rel) else null
		m.roughness = 0.82
		m.metallic_specular = 0.35
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if glass:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.6, 0.75, 0.8, 0.35)
			m.roughness = 0.05
			m.metallic = 0.4
		_mats[key] = m
	return _mats[key]

## Instantiates a model and assigns the atlas material to every mesh (glass parts get a translucent variant).
static func instance(rel: String, tex_rel: String) -> Node3D:
	var ps := scene(rel)
	if ps == null:
		return Node3D.new()
	var n: Node3D = ps.instantiate()
	apply_material(n, atlas(tex_rel, rel.contains("Glass") or rel.contains("Visor")))
	for mi in n.find_children("*Glass*", "MeshInstance3D", true, false):
		mi.material_override = atlas(tex_rel, true)
	return n

static func apply_material(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = m
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for c in n.get_children():
		apply_material(c, m)

## Local-space AABB of all meshes under `n`.
static func bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = n.global_transform.affine_inverse() * mi.global_transform if n.is_inside_tree() else _rel_xform(n, mi)
		var b: AABB = xf * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

static func _rel_xform(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

## Places a model at `pos` / `rot_y`. With `fit` (box size), the model is uniformly scaled to fit the box footprint
## and height, centred on X/Z and sitting on the box bottom, so it matches an existing gameplay collider.
static func place(parent: Node, rel: String, tex_rel: String, pos: Vector3, rot_y := 0.0, fit := Vector3.ZERO, stretch := false) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = rot_y
	parent.add_child(holder)
	if not Geo.visuals:
		return holder
	var inner := instance(rel, tex_rel)
	var m := Node3D.new()   # fitting wrapper: scaled / offset in the holder's axes
	m.add_child(inner)
	holder.add_child(m)
	if fit != Vector3.ZERO:
		var b := _rel_bounds(inner)
		if absf(fit.x - fit.z) > 0.2 and (fit.x > fit.z) != (b.size.x > b.size.z):
			inner.rotation_degrees.y = 90.0   # align the model's long axis with the collider's long axis
			b = Transform3D(inner.basis, Vector3.ZERO) * b
		if b.size.x > 0.001 and b.size.z > 0.001:
			var s := Vector3.ONE
			if stretch:
				s = Vector3(fit.x / b.size.x, (fit.y / b.size.y) if fit.y > 0.0 else 1.0, fit.z / b.size.z)
			else:
				var k := minf(fit.x / b.size.x, fit.z / b.size.z)
				if fit.y > 0.0:
					k = minf(k, fit.y / b.size.y)
				s = Vector3.ONE * k
			m.scale = s
			var c := b.get_center() * s
			var y := -b.position.y * s.y - (fit.y * 0.5 if fit.y > 0.0 else 0.0)
			m.position = Vector3(-c.x, y, -c.z)
	return m

## Bounds of a freshly instanced model in its own space (independent of tree placement).
static func _rel_bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = _rel_xform(n, mi) * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

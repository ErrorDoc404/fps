class_name Props
## Prop presentation for the maps. Uses the supplied Synty POLYGON Military / Warehouse models (via Poly) fitted to
## the existing gameplay colliders; the code-built versions below remain only as fallbacks (e.g. forklift, tanks,
## which have no matching Synty model). Presentation only: callers create colliders separately so the dedicated
## server (Geo.visuals == false) builds identical collision without any meshes or materials.

const A := "PM/Textures/PolygonMilitary_Texture_01_A.png"
const VEH := "PM/Textures/PolygonMilitary_Land_Vehicles_05.png"

## Places a Synty model fitted to a box centred on `p` (or standing on `p` when fit.y == 0). Returns false if missing.
static func _sy(p: Node3D, rel: String, fit: Vector3, stretch := false, tex := A, offset := Vector3.ZERO) -> bool:
	if not Geo.visuals or not Poly.available(rel):
		return false
	Poly.place(p, rel, tex, offset, 0.0, fit, stretch)
	return true

const C_CONTAINER := [Color(0.52, 0.2, 0.15), Color(0.2, 0.33, 0.45), Color(0.27, 0.36, 0.24), Color(0.62, 0.45, 0.16), Color(0.42, 0.42, 0.43)]

static func container(p: Node3D, color: Color) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PW/FBX/SM_Prop_Shipping_Container_01.fbx", Vector3(2.5, 2.6, 6.1), true):
		return
	var body := Mat.corrugated(color)
	var frame := Mat.painted(color.darkened(0.25))
	Geo.part(p, Vector3(2.44, 2.5, 5.95), Vector3.ZERO, body, Vector3.ZERO, 0.02)
	for x in [-1.2, 1.2]:   # rails and corner posts
		for y in [-1.22, 1.22]:
			Geo.part(p, Vector3(0.1, 0.12, 6.06), Vector3(x, y, 0), frame, Vector3.ZERO, 0.01)
		for z in [-3.0, 3.0]:
			Geo.part(p, Vector3(0.14, 2.6, 0.14), Vector3(x, 0, z), frame, Vector3.ZERO, 0.01)
			for y in [-1.22, 1.22]:
				Geo.part(p, Vector3(0.18, 0.16, 0.18), Vector3(x, y, z), Mat.metal(Color(0.3, 0.3, 0.3)), Vector3.ZERO, 0.02)
	# door end: two leaves, locking bars, handles
	for x in [-0.6, 0.6]:
		Geo.part(p, Vector3(1.15, 2.35, 0.05), Vector3(x, 0, 3.0), Mat.painted(color.darkened(0.05)), Vector3.ZERO, 0.01)
		for bx in [-0.3, 0.3]:
			Geo.tube(p, 0.025, 2.4, Vector3(x + bx, 0, 3.06), Mat.metal(), Vector3.ZERO, 6)
			Geo.part(p, Vector3(0.06, 0.18, 0.06), Vector3(x + bx, -0.2, 3.09), Mat.metal(Color(0.25, 0.25, 0.25)))
	Geo.part(p, Vector3(2.3, 2.35, 0.05), Vector3(0, 0, -3.0), Mat.painted(color.darkened(0.1)))

static func barrel(p: Node3D, color: Color, tipped := false) -> void:
	if not Geo.visuals:
		return
	var bh := Node3D.new()
	p.add_child(bh)
	if tipped:
		bh.rotation_degrees = Vector3(90, 0, 0)
		bh.position = Vector3(0, -0.0, -0.45)
	if _sy(bh, "PM/Fbx/SM_Prop_Barrel_01.fbx", Vector3(0.62, 0, 0.62)):
		return
	bh.queue_free()
	var b := Node3D.new()
	p.add_child(b)
	if tipped:
		b.rotation_degrees = Vector3(90, 0, 0)
		b.position.y = -0.28
	Geo.tube(b, 0.29, 0.88, Vector3(0, 0.44, 0), Mat.painted(color, 0.55), Vector3.ZERO, 14)
	for y in [0.06, 0.3, 0.58, 0.84]:
		Geo.tube(b, 0.3, 0.035, Vector3(0, y, 0), Mat.painted(color.darkened(0.2)), Vector3.ZERO, 14)
	Geo.tube(b, 0.05, 0.03, Vector3(0.14, 0.89, 0.05), Mat.metal(), Vector3.ZERO, 6)

static func pallet(p: Node3D, pos: Vector3, load := 0) -> void:
	if not Geo.visuals:
		return
	var ph := Node3D.new()
	ph.position = pos
	p.add_child(ph)
	if _sy(ph, "PM/Fbx/SM_Prop_Pallet_01.fbx", Vector3(1.2, 0, 1.2)):
		if load == 1:
			_sy(ph, "PM/Fbx/SM_Prop_Sack_Large_01.fbx", Vector3(1.1, 0, 1.1), false, A, Vector3(0, 0.14, 0))
		elif load == 2:
			_sy(ph, "PM/Fbx/SM_Prop_Crate_Wood_01.fbx", Vector3(1.1, 0, 1.1), false, A, Vector3(0, 0.14, 0))
		return
	ph.queue_free()
	var n := Node3D.new()
	n.position = pos
	p.add_child(n)
	var w := Mat.wood(Color(0.6, 0.48, 0.32))
	for z in [-0.5, 0.0, 0.5]:
		Geo.part(n, Vector3(1.2, 0.1, 0.12), Vector3(0, 0.05, z), w, Vector3.ZERO, 0.01)
	for x in [-0.5, -0.17, 0.17, 0.5]:
		Geo.part(n, Vector3(0.14, 0.03, 1.2), Vector3(x, 0.12, 0), w, Vector3.ZERO, 0.005)
	if load == 1:   # stacked sacks
		for i in 6:
			Geo.part(n, Vector3(0.55, 0.2, 0.36), Vector3(-0.28 + (i % 2) * 0.56, 0.25 + (i / 4) * 0.2, -0.38 + ((i / 2) % 2) * 0.76 * 0.5), Mat.fabric(Color(0.68, 0.62, 0.48)), Vector3(0, (i * 13) % 20 - 10, 0), 0.06)
	elif load == 2:  # shrink-wrapped boxes
		Geo.part(n, Vector3(1.1, 0.9, 1.1), Vector3(0, 0.6, 0), Mat.painted(Color(0.6, 0.5, 0.36), 0.9), Vector3.ZERO, 0.04)
		Geo.part(n, Vector3(1.12, 0.05, 0.08), Vector3(0, 0.8, 0), Mat.polymer(Color(0.15, 0.15, 0.15)))

static func crate(p: Node3D, size: float, military := true) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Prop_Crate_Cube_01.fbx" if military else "PM/Fbx/SM_Prop_Crate_Wood_01.fbx", Vector3.ONE * size):
		return
	var body := Mat.painted(Color(0.33, 0.36, 0.25)) if military else Mat.wood()
	Geo.part(p, Vector3.ONE * size * 0.96, Vector3.ZERO, body, Vector3.ZERO, 0.03)
	var trim := Mat.wood(Color(0.45, 0.36, 0.24)) if not military else Mat.painted(Color(0.24, 0.26, 0.18))
	for a in [-1, 1]:
		Geo.part(p, Vector3(size, 0.08, 0.08), Vector3(0, a * size * 0.45, size * 0.49), trim)
		Geo.part(p, Vector3(size, 0.08, 0.08), Vector3(0, a * size * 0.45, -size * 0.49), trim)
		Geo.part(p, Vector3(0.08, size, 0.08), Vector3(a * size * 0.45, 0, size * 0.49), trim)
		Geo.part(p, Vector3(0.08, size, 0.08), Vector3(a * size * 0.45, 0, -size * 0.49), trim)
	if military:
		Geo.part(p, Vector3(size * 0.5, size * 0.12, 0.02), Vector3(0, size * 0.15, size * 0.5), Mat.painted(Color(0.85, 0.8, 0.6)))

static func jersey_barrier(p: Node3D, stripes := true) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Prop_Barrier_01.fbx", Vector3(3.2, 0.95, 0.62), true):
		return
	var c := Mat.concrete(Color(0.7, 0.68, 0.63))
	Geo.part(p, Vector3(3.2, 0.3, 0.62), Vector3(0, -0.32, 0), c, Vector3.ZERO, 0.03)
	Geo.part(p, Vector3(3.2, 0.4, 0.4), Vector3(0, -0.05, 0), c, Vector3.ZERO, 0.05)
	Geo.part(p, Vector3(3.2, 0.3, 0.22), Vector3(0, 0.3, 0), c, Vector3.ZERO, 0.05)
	if stripes:
		for i in 4:
			Geo.part(p, Vector3(0.3, 0.2, 0.42), Vector3(-1.2 + i * 0.8, 0.0, 0), Mat.painted(Color(0.78, 0.6, 0.12)), Vector3(0, 0, 30), 0.01)

static func sandbag_wall(p: Node3D, length: float, rows := 3) -> void:
	if not Geo.visuals:
		return
	if rows >= 3 and _sy(p, "PM/Fbx/SM_Prop_Barrier_Base_Row_01.fbx", Vector3(length, 1.1, 1.0), true):
		return
	var m := Mat.fabric(Color(0.58, 0.52, 0.38))
	var n := int(length / 0.55)
	for r in rows:
		for i in n:
			var x := -length * 0.5 + 0.28 + i * 0.55 + (0.27 if r % 2 == 1 else 0.0)
			if x > length * 0.5 - 0.2:
				continue
			Geo.part(p, Vector3(0.52, 0.2, 0.34), Vector3(x, -0.45 + 0.2 + r * 0.2, 0), m, Vector3(0, (i * 7 + r * 3) % 9 - 4, 0), 0.07)

static func light_pole(p: Node3D, height := 6.0) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Prop_LightPole_01.fbx", Vector3(1.0, height, 1.0), false, A, Vector3(0, height * 0.5, 0)):
		return
	Geo.tube(p, 0.12, height, Vector3(0, height * 0.5, 0), Mat.painted(Color(0.42, 0.44, 0.42)), Vector3.ZERO, 8, 0.08)
	Geo.part(p, Vector3(0.5, 0.25, 0.5), Vector3(0, 0.12, 0), Mat.concrete(), Vector3.ZERO, 0.04)
	Geo.part(p, Vector3(1.2, 0.08, 0.08), Vector3(0.5, height - 0.1, 0), Mat.metal())
	Geo.part(p, Vector3(0.5, 0.14, 0.32), Vector3(1.0, height - 0.18, 0), Mat.painted(Color(0.3, 0.32, 0.3)), Vector3.ZERO, 0.03)
	Geo.part(p, Vector3(0.42, 0.02, 0.26), Vector3(1.0, height - 0.26, 0), Mat.emissive(Color(1.0, 0.82, 0.55), 4.0))

static func truck(p: Node3D, color: Color, canvas := true) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Veh_Truck_01.fbx", Vector3(3.1, 2.75, 6.9), false, VEH):
		return
	var paint := Mat.painted(color, 0.7)
	var dark := Mat.painted(color.darkened(0.35))
	Geo.part(p, Vector3(2.3, 0.35, 6.0), Vector3(0, -0.45, 0), Mat.metal(Color(0.18, 0.18, 0.18)), Vector3.ZERO, 0.02)  # chassis
	Geo.part(p, Vector3(2.3, 1.5, 1.9), Vector3(0, 0.45, -2.0), paint, Vector3.ZERO, 0.1)   # cab
	Geo.part(p, Vector3(2.2, 0.55, 0.05), Vector3(0, 0.75, -2.96), Mat.glass(Color(0.25, 0.35, 0.4, 0.6)))
	for x in [-1.16, 1.16]:
		Geo.part(p, Vector3(0.05, 0.5, 0.9), Vector3(x, 0.75, -2.0), Mat.glass(Color(0.25, 0.35, 0.4, 0.6)))
		Geo.part(p, Vector3(0.08, 0.25, 0.12), Vector3(x * 1.08, 0.75, -2.85), Mat.polymer())  # mirrors
	Geo.part(p, Vector3(2.0, 0.5, 0.3), Vector3(0, -0.15, -3.05), dark, Vector3.ZERO, 0.05)   # bumper / grille
	for x in [-0.8, 0.8]:
		Geo.part(p, Vector3(0.3, 0.16, 0.04), Vector3(x, 0.1, -3.07), Mat.emissive(Color(1.0, 0.95, 0.8), 0.6))
	Geo.part(p, Vector3(2.3, 0.6, 3.8), Vector3(0, -0.05, 1.0), paint, Vector3.ZERO, 0.03)    # bed
	if canvas:
		Geo.part(p, Vector3(2.32, 1.5, 3.8), Vector3(0, 1.0, 1.0), Mat.fabric(color.lerp(Color(0.5, 0.48, 0.36), 0.5)), Vector3.ZERO, 0.15)
		for z in [-0.6, 0.4, 1.4, 2.4]:
			Geo.part(p, Vector3(2.36, 0.06, 0.06), Vector3(0, 1.72, z), dark)
	for z in [-2.0, 0.6, 2.0]:
		for x in [-1.05, 1.05]:
			Geo.tube(p, 0.5, 0.38, Vector3(x, -0.65, z), Mat.rubber(), Vector3(0, 0, 90), 12)
			Geo.tube(p, 0.26, 0.4, Vector3(x * 1.02, -0.65, z), Mat.painted(color.darkened(0.2)), Vector3(0, 0, 90), 8)

static func forklift(p: Node3D) -> void:
	if not Geo.visuals:
		return
	var y := Mat.painted(Color(0.78, 0.6, 0.12), 0.6)
	Geo.part(p, Vector3(1.4, 0.9, 2.2), Vector3(0, -0.4, 0.3), y, Vector3.ZERO, 0.08)
	Geo.part(p, Vector3(1.3, 0.6, 0.6), Vector3(0, 0.0, 1.2), Mat.painted(Color(0.2, 0.2, 0.2)), Vector3.ZERO, 0.08)  # counterweight
	for x in [-0.62, 0.62]:
		Geo.part(p, Vector3(0.08, 1.4, 0.08), Vector3(x, 0.5, -0.6), Mat.metal(Color(0.2, 0.2, 0.2)))
		Geo.part(p, Vector3(0.08, 1.4, 0.08), Vector3(x, 0.5, 0.8), Mat.metal(Color(0.2, 0.2, 0.2)))
		Geo.part(p, Vector3(0.12, 2.0, 0.1), Vector3(x * 0.6, 0.0, -0.95), Mat.metal(Color(0.25, 0.25, 0.25)))
		Geo.part(p, Vector3(0.12, 0.05, 1.1), Vector3(x * 0.4, -0.95, -1.5), Mat.metal(Color(0.3, 0.3, 0.3)))
	Geo.part(p, Vector3(1.4, 0.06, 1.6), Vector3(0, 1.2, 0.1), Mat.metal(Color(0.2, 0.2, 0.2)))
	Geo.part(p, Vector3(0.5, 0.5, 0.5), Vector3(0, 0.25, 0.5), Mat.polymer())
	for z in [-0.6, 0.8]:
		for x in [-0.66, 0.66]:
			Geo.tube(p, 0.28, 0.22, Vector3(x, -0.72, z), Mat.rubber(), Vector3(0, 0, 90), 10)

static func generator(p: Node3D) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Prop_Generator_Large_01.fbx", Vector3(2.2, 1.3, 1.1)):
		return
	Geo.part(p, Vector3(2.2, 1.3, 1.1), Vector3(0, 0, 0), Mat.painted(Color(0.32, 0.38, 0.26)), Vector3.ZERO, 0.06)
	for i in 6:
		Geo.part(p, Vector3(0.02, 0.6, 0.06), Vector3(-0.6 + i * 0.12, 0.1, 0.56), Mat.metal(Color(0.2, 0.2, 0.2)))
	Geo.tube(p, 0.06, 0.6, Vector3(0.8, 0.9, 0), Mat.metal(Color(0.15, 0.15, 0.15)), Vector3.ZERO, 6)
	Geo.part(p, Vector3(0.3, 0.2, 0.02), Vector3(0.6, 0.2, 0.56), Mat.emissive(Color(0.2, 1.0, 0.3), 1.5))

static func tank(p: Node3D, radius: float, height: float) -> void:
	if not Geo.visuals:
		return
	var m := Mat.painted(Color(0.72, 0.7, 0.64), 0.5)
	Geo.tube(p, radius, height, Vector3.ZERO, m, Vector3.ZERO, 20)
	Geo.tube(p, radius * 0.96, 0.6, Vector3(0, height * 0.5 + 0.3, 0), m, Vector3.ZERO, 20, radius * 0.3)
	for y in [-height * 0.5 + 0.2, -height * 0.15, height * 0.2, height * 0.48]:
		Geo.tube(p, radius + 0.04, 0.12, Vector3(0, y, 0), Mat.metal(Color(0.45, 0.45, 0.45)), Vector3.ZERO, 20)
	Geo.tube(p, radius + 0.02, 1.0, Vector3(0, -height * 0.5 + 0.5, 0), Mat.rust(), Vector3.ZERO, 20)   # rust staining at the base
	# ladder + cage
	for x in [-0.25, 0.25]:
		Geo.part(p, Vector3(0.05, height + 0.4, 0.05), Vector3(x, 0.2, radius + 0.25), Mat.metal())
	for i in int(height / 0.4):
		Geo.part(p, Vector3(0.5, 0.04, 0.04), Vector3(0, -height * 0.5 + 0.3 + i * 0.4, radius + 0.25), Mat.metal())
	Geo.tube(p, 0.25, 1.4, Vector3(radius * 0.7, -height * 0.5 + 0.7, -radius * 0.7), Mat.metal(Color(0.4, 0.42, 0.4)), Vector3(0, 0, 90), 10)

static func tower(p: Node3D) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Bld_GuardTower_01.fbx", Vector3(3.9, 0, 3.9)):
		return
	var w := Mat.wood(Color(0.5, 0.4, 0.28))
	for x in [-1.5, 1.5]:
		for z in [-1.5, 1.5]:
			Geo.part(p, Vector3(0.28, 5.2, 0.28), Vector3(x, 2.5, z), w, Vector3.ZERO, 0.02)
	for y in [1.5, 3.2]:
		Geo.part(p, Vector3(3.2, 0.12, 0.12), Vector3(0, y, 1.5), w, Vector3(0, 0, 32))
		Geo.part(p, Vector3(3.2, 0.12, 0.12), Vector3(0, y, -1.5), w, Vector3(0, 0, -32))
	Geo.part(p, Vector3(3.8, 0.25, 3.8), Vector3(0, 5.1, 0), w, Vector3.ZERO, 0.02)
	for side in [[Vector3(3.8, 1.0, 0.1), Vector3(0, 5.75, 1.85)], [Vector3(3.8, 1.0, 0.1), Vector3(0, 5.75, -1.85)], [Vector3(0.1, 1.0, 3.8), Vector3(1.85, 5.75, 0)]]:
		Geo.part(p, side[0], side[1], Mat.wood(Color(0.46, 0.37, 0.26)))
	Geo.part(p, Vector3(4.2, 0.12, 4.2), Vector3(0, 7.4, 0), Mat.corrugated(Color(0.4, 0.38, 0.32)), Vector3(4, 0, 0))
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			Geo.part(p, Vector3(0.1, 1.6, 0.1), Vector3(x, 6.6, z), w)
	sandbag_wall_at(p, Vector3(0, 5.5, 1.6), 3.4)

static func sandbag_wall_at(p: Node3D, pos: Vector3, length: float) -> void:
	var n := Node3D.new()
	n.position = pos
	p.add_child(n)
	sandbag_wall(n, length, 2)

static func tire_stack(p: Node3D, count: int) -> void:
	if not Geo.visuals:
		return
	if Poly.available("PM/Fbx/SM_Prop_Tire_01.fbx"):
		for i in count:
			_sy(p, "PM/Fbx/SM_Prop_Tire_01.fbx", Vector3(0.85, 0, 0.85), false, A, Vector3(0.03 * (i % 2), i * 0.26, 0))
		return
	for i in count:
		Geo.tube(p, 0.42, 0.24, Vector3(0.04 * (i % 2), 0.12 + i * 0.24, 0.0), Mat.rubber(), Vector3.ZERO, 12)

static func cable_spool(p: Node3D) -> void:
	if not Geo.visuals:
		return
	if _sy(p, "PM/Fbx/SM_Prop_WireSpool_01.fbx", Vector3(1.5, 0, 1.5)):
		return
	for x in [-0.4, 0.4]:
		Geo.tube(p, 0.7, 0.08, Vector3(x, 0.7, 0), Mat.wood(), Vector3(0, 0, 90), 14)
	Geo.tube(p, 0.38, 0.75, Vector3(0, 0.7, 0), Mat.rubber(Color(0.12, 0.12, 0.1)), Vector3(0, 0, 90), 12)

static func fence(p: Node3D, length: float, height := 2.6) -> void:
	if not Geo.visuals:
		return
	if Poly.available("PM/Fbx/SM_Prop_Fence_01.fbx"):
		var n := int(ceil(length / 3.0))
		for i in n:
			_sy(p, "PM/Fbx/SM_Prop_Fence_01.fbx", Vector3(3.0, 0, 0.1), false, A, Vector3(-length * 0.5 + 1.5 + i * 3.0, 0, 0))
		return
	var post := Mat.metal(Color(0.45, 0.46, 0.45))
	var n := int(length / 3.0) + 1
	for i in n:
		Geo.tube(p, 0.04, height, Vector3(-length * 0.5 + i * length / maxi(1, n - 1), height * 0.5, 0), post, Vector3.ZERO, 6)
	Geo.tube(p, 0.03, length, Vector3(0, height, 0), post, Vector3(0, 0, 90), 6)
	var mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(length, height - 0.1)
	mesh.mesh = q
	mesh.position = Vector3(0, height * 0.5, 0)
	mesh.material_override = _chainlink()
	p.add_child(mesh)

static var _chain_mat: StandardMaterial3D
static func _chainlink() -> StandardMaterial3D:
	if _chain_mat:
		return _chain_mat
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d1 := absi((x + y) % 16 - 8)
			var d2 := absi((x - y + 64) % 16 - 8)
			var a := 1.0 if d1 >= 7 or d2 >= 7 else 0.0
			img.set_pixel(x, y, Color(0.6, 0.62, 0.6, a))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic = 0.6
	m.roughness = 0.5
	m.uv1_scale = Vector3(10, 10, 1)
	_chain_mat = m
	return m

## Hanging industrial lamp: housing + emissive lens + light.
static func hanging_lamp(p: Node3D, pos: Vector3, energy := 1.8, rng := 14.0, color := Color(1.0, 0.86, 0.62)) -> void:
	if not Geo.visuals:
		return
	Geo.tube(p, 0.012, 1.2, pos + Vector3(0, 0.6, 0), Mat.metal(Color(0.2, 0.2, 0.2)), Vector3.ZERO, 4)
	Geo.tube(p, 0.38, 0.28, pos, Mat.painted(Color(0.3, 0.33, 0.3)), Vector3.ZERO, 10, 0.14)
	Geo.tube(p, 0.33, 0.02, pos - Vector3(0, 0.15, 0), Mat.emissive(color, 5.0), Vector3.ZERO, 10)
	var l := OmniLight3D.new()
	l.position = pos - Vector3(0, 0.4, 0)
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	p.add_child(l)

## Wall-mounted sign board showing one of the supplied Synty icons.
static func sign_board(p: Node3D, pos: Vector3, rot_y: float, icon_rel: String, board: Color, icon_tint: Color, size := 0.9) -> void:
	if not Geo.visuals:
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	p.add_child(n)
	Geo.part(n, Vector3(size, size, 0.04), Vector3.ZERO, Mat.painted(board, 0.5), Vector3.ZERO, 0.01)
	var s := Sprite3D.new()
	s.texture = UiKit.tex(icon_rel)
	s.pixel_size = size * 0.75 / 256.0
	s.modulate = icon_tint
	s.position = Vector3(0, 0, 0.03)
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	if s.texture:
		s.pixel_size = size * 0.75 / float(s.texture.get_width())
	n.add_child(s)

## Projected decal of a supplied sprite (painted markings, emblems, grime).
static func decal(p: Node3D, rel: String, pos: Vector3, size: Vector3, tint: Color, rot := Vector3.ZERO) -> void:
	if not Geo.visuals:
		return
	var d := Decal.new()
	d.texture_albedo = UiKit.tex(rel)
	d.modulate = tint
	d.size = size
	d.position = pos
	d.rotation_degrees = rot
	d.cull_mask = 1
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	p.add_child(d)

## Dominion faction banner: dark cloth with the supplied skull emblem.
static func banner(p: Node3D, pos: Vector3, rot_y: float) -> void:
	if not Geo.visuals:
		return
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	p.add_child(n)
	Geo.part(n, Vector3(1.6, 0.05, 0.05), Vector3(0, 1.3, 0), Mat.metal())
	Geo.part(n, Vector3(1.4, 2.5, 0.02), Vector3.ZERO, Mat.fabric(Color(0.42, 0.08, 0.07)), Vector3.ZERO, 0.0)
	Geo.part(n, Vector3(1.4, 0.15, 0.025), Vector3(0, -1.1, 0), Mat.fabric(Color(0.1, 0.1, 0.1)), Vector3.ZERO, 0.0)
	var s := Sprite3D.new()
	s.texture = UiKit.tex(UiKit.BADGE_DOMINION)
	if s.texture:
		s.pixel_size = 1.1 / float(s.texture.get_width())
	s.modulate = Color(0.85, 0.82, 0.75)
	s.position = Vector3(0, 0.2, 0.02)
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	n.add_child(s)

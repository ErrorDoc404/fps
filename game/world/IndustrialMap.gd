class_name IndustrialMap
## OP-01 "First Contact": abandoned industrial facility. Graybox geometry built in code
## (no 3D environment assets were supplied). Produces map metadata used by missions, the minimap and AI.

const C_GROUND := Color(0.36, 0.34, 0.3)
const C_CONCRETE := Color(0.55, 0.53, 0.5)
const C_WALL := Color(0.48, 0.45, 0.4)
const C_METAL := Color(0.38, 0.4, 0.42)
const C_RUST := Color(0.45, 0.3, 0.2)
const C_ROOF := Color(0.3, 0.3, 0.32)

var root: Node3D
var rng := RandomNumberGenerator.new()  # fixed seed: client and server must build identical collision
var info := {"zones": {}, "interactables": {}, "footprints": [], "bounds": Rect2(-70, -70, 140, 140), "extraction": Vector3.ZERO}

func build(parent: Node3D) -> Dictionary:
	root = parent
	rng.seed = 1337
	_ground()
	_perimeter()
	_warehouse()
	_maintenance()
	_yard()
	_north()
	_east_tanks()
	info["zones"]["warehouse_interior"] = AABB(Vector3(-18, -1, -24), Vector3(36, 9, 26))
	info["zones"]["loading_yard"] = AABB(Vector3(-22, -1, 8), Vector3(44, 8, 34))
	info["zones"]["extraction_zone"] = AABB(Vector3(-7, -1, -59), Vector3(14, 8, 14))
	info["extraction"] = Vector3(0, 0, -52)
	return info

func _solid(size: Vector3, pos: Vector3, color: Color, rot := 0.0, footprint := true) -> StaticBody3D:
	var b := Geo.solid(root, size, pos, color, rot)
	if footprint and size.y > 0.8:
		info["footprints"].append([pos.x, pos.z, size.x, size.z, deg_to_rad(rot)])
	return b

func _ground() -> void:
	_solid(Vector3(160, 1, 160), Vector3(0, -0.5, 0), C_GROUND, 0, false)
	# concrete pads + road for readability
	Geo.box(Vector3(46, 0.02, 36), C_CONCRETE.darkened(0.15), Vector3(0, 0.01, 25), root)
	Geo.box(Vector3(8, 0.02, 30), C_CONCRETE.darkened(0.25), Vector3(0, 0.012, 55), root)
	Geo.box(Vector3(20, 0.02, 30), C_CONCRETE.darkened(0.2), Vector3(0, 0.011, -40), root)

func _wall_x(z: float, x0: float, x1: float, h: float, gaps: Array, color := C_WALL, t := 0.4, door_h := 3.2) -> void:
	# wall running along X at fixed Z with door gaps [[a, b], ...]
	var cuts := [x0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(x1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]; var b: float = cuts[i + 1]
		if b - a > 0.05:
			_solid(Vector3(b - a, h, t), Vector3((a + b) * 0.5, h * 0.5, z), color)
	for g in gaps:
		if h > door_h:
			_solid(Vector3(g[1] - g[0], h - door_h, t), Vector3((g[0] + g[1]) * 0.5, door_h + (h - door_h) * 0.5, z), color, 0, false)

func _wall_z(x: float, z0: float, z1: float, h: float, gaps: Array, color := C_WALL, t := 0.4, door_h := 3.2) -> void:
	var cuts := [z0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(z1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]; var b: float = cuts[i + 1]
		if b - a > 0.05:
			_solid(Vector3(t, h, b - a), Vector3(x, h * 0.5, (a + b) * 0.5), color)
	for g in gaps:
		if h > door_h:
			_solid(Vector3(t, h - door_h, g[1] - g[0]), Vector3(x, door_h + (h - door_h) * 0.5, (g[0] + g[1]) * 0.5), color, 0, false)

func _light(pos: Vector3, color := Color(1.0, 0.85, 0.6), energy := 1.6, rng := 14.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	root.add_child(l)
	var lamp := Geo.box(Vector3(0.6, 0.08, 0.25), Color(1, 0.95, 0.8), pos + Vector3(0, 0.1, 0), root)
	lamp.material_override = Geo.mat(Color(1, 0.95, 0.8), 1.0, 0.0, color)

func _perimeter() -> void:
	var c := Color(0.42, 0.44, 0.4)
	_wall_x(-70, -70, 70, 3.5, [], c)
	_wall_x(70, -70, 70, 3.5, [[-6, 6]], c)
	_wall_z(-70, -70, 70, 3.5, [], c)
	_wall_z(70, -70, 70, 3.5, [], c)
	# gate posts + insertion vehicle
	_solid(Vector3(1, 4.5, 1), Vector3(-6.5, 2.25, 70), C_METAL)
	_solid(Vector3(1, 4.5, 1), Vector3(6.5, 2.25, 70), C_METAL)
	_vehicle(Vector3(6, 0, 60), 0.0, Color(0.3, 0.33, 0.25))

func _vehicle(pos: Vector3, rot: float, color: Color) -> void:
	var b := _solid(Vector3(2.4, 1.6, 5.5), pos + Vector3(0, 1.1, 0), color, rot)
	Geo.box(Vector3(2.2, 1.0, 2.0), color.darkened(0.15), Vector3(0, 1.2, -1.5), b)
	for x in [-1.1, 1.1]:
		for z in [-1.8, 1.8]:
			Geo.cyl(0.45, 0.35, Color(0.08, 0.08, 0.08), Vector3(x, -0.65, z), b, Vector3(0, 0, 90))

func _warehouse() -> void:
	var h := 8.0
	_wall_x(2, -18, 18, h, [[-8, -4], [6, 10]])
	_wall_x(-24, -18, 18, h, [[-2, 2]])
	_wall_z(-18, -24, 2, h, [[-6, -3]])
	_wall_z(18, -24, 2, h, [[-12, -8]])
	_solid(Vector3(36.8, 0.4, 26.8), Vector3(0, h + 0.2, -11), C_ROOF, 0, false)
	Geo.box(Vector3(35.6, 0.02, 25.6), C_CONCRETE, Vector3(0, 0.015, -11), root)
	# rack rows with gaps (cover + multiple routes)
	for x in [-12.0, -6.0]:
		for z in [-19.0, -10.0]:
			var rack := _solid(Vector3(1.2, 3.2, 6.5), Vector3(x, 1.6, z), C_RUST)
			for y in [0.9, 2.0]:
				Geo.box(Vector3(1.1, 0.5, 6.0), Color(0.55, 0.45, 0.3), Vector3(0, y - 1.6, 0), rack)
	# crates + forklift-sized blocks
	for p in [Vector3(2, 0, -4), Vector3(3.3, 0, -4), Vector3(2.6, 1.2, -4), Vector3(-2, 0, -15), Vector3(6, 0, -14), Vector3(-15, 0, -2)]:
		_solid(Vector3(1.2, 1.2, 1.2), p + Vector3(0, 0.6, 0), Color(0.5, 0.4, 0.25))
	_solid(Vector3(1.6, 2.0, 3.0), Vector3(4, 1.0, -19), Color(0.75, 0.6, 0.15))
	# site office (north-east corner)
	_wall_z(10, -24, -16, 3.0, [[-21, -19]], Color(0.6, 0.6, 0.58), 0.2, 2.4)
	_wall_x(-16, 10, 18, 3.0, [[13, 15]], Color(0.6, 0.6, 0.58), 0.2, 2.4)
	_solid(Vector3(8.2, 0.2, 8.2), Vector3(14, 3.1, -20), Color(0.5, 0.5, 0.5), 0, false)
	_solid(Vector3(2.0, 0.9, 1.0), Vector3(15, 0.45, -22.5), Color(0.35, 0.28, 0.2), 0, false)
	info["interactables"]["intel_laptop"] = {"pos": Vector3(15, 1.0, -22.5), "label": "Download intelligence"}
	var laptop := Geo.box(Vector3(0.4, 0.03, 0.3), Color(0.1, 0.1, 0.1), Vector3(15, 0.92, -22.5), root)
	var screen := Geo.box(Vector3(0.4, 0.28, 0.02), Color(0.2, 0.6, 1.0), Vector3(0, 0.15, 0.14), laptop)
	screen.material_override = Geo.mat(Color(0.2, 0.6, 1.0), 0.5, 0.0, Color(0.2, 0.5, 1.0))
	for p in [Vector3(-10, 7.4, -18), Vector3(-10, 7.4, -5), Vector3(4, 7.4, -18), Vector3(4, 7.4, -5), Vector3(14, 2.8, -20)]:
		_light(p)

func _maintenance() -> void:
	var h := 4.5
	_wall_x(0, -46, -34, h, [[-42, -39]], Color(0.5, 0.48, 0.42))
	_wall_x(-12, -46, -34, h, [], Color(0.5, 0.48, 0.42))
	_wall_z(-46, -12, 0, h, [], Color(0.5, 0.48, 0.42))
	_wall_z(-34, -12, 0, h, [[-7, -4]], Color(0.5, 0.48, 0.42))
	_solid(Vector3(12.8, 0.3, 12.8), Vector3(-40, h + 0.15, -6), C_ROOF, 0, false)
	var rack := _solid(Vector3(1.0, 2.2, 2.4), Vector3(-45, 1.1, -9), Color(0.15, 0.15, 0.17))
	for i in range(6):
		var led := Geo.box(Vector3(0.02, 0.04, 0.04), Color(0.2, 1, 0.3), Vector3(0.51, -0.8 + i * 0.3, -0.8 + (i % 3) * 0.4), rack)
		led.material_override = Geo.mat(Color(0.2, 1, 0.3), 0.5, 0.0, Color(0.1, 1, 0.2))
	info["interactables"]["data_server"] = {"pos": Vector3(-44.3, 1.2, -9), "label": "Download server logs"}
	_solid(Vector3(3, 1.0, 1.0), Vector3(-38, 0.5, -11), C_METAL)
	_light(Vector3(-40, 4.1, -6), Color(0.8, 0.9, 1.0), 1.2, 10.0)
	# scrap / cover outside
	for p in [Vector3(-30, 0, 8), Vector3(-26, 0, -18), Vector3(-50, 0, 12)]:
		_solid(Vector3(3, 1.4, 2), p + Vector3(0, 0.7, 0), C_RUST, rng.randf() * 40.0)

func _container(pos: Vector3, rot: float, color: Color) -> void:
	var c := _solid(Vector3(2.5, 2.6, 6.1), pos + Vector3(0, 1.3, 0), color, rot)
	for i in range(5):
		Geo.box(Vector3(2.55, 2.4, 0.08), color.darkened(0.15), Vector3(0, 0, -2.4 + i * 1.2), c)

func _yard() -> void:
	_container(Vector3(-14, 0, 16), 0, Color(0.55, 0.2, 0.15))
	_container(Vector3(-6, 0, 27), 90, Color(0.2, 0.35, 0.5))
	_container(Vector3(8, 0, 17), 0, Color(0.25, 0.4, 0.25))
	_container(Vector3(15, 0, 30), 90, Color(0.6, 0.45, 0.15))
	_container(Vector3(15, 2.6, 30), 90, Color(0.4, 0.4, 0.42))
	_vehicle(Vector3(-1, 0, 36), 90.0, Color(0.5, 0.48, 0.42))
	for p in [Vector3(-18, 0, 30), Vector3(0, 0, 12), Vector3(19, 0, 12), Vector3(4, 0, 44), Vector3(-10, 0, 44)]:
		_solid(Vector3(3.2, 0.95, 0.6), p + Vector3(0, 0.475, 0), C_CONCRETE, rng.randf_range(-20, 20))
	for p in [Vector3(-3, 0, 20), Vector3(-2, 0, 20), Vector3(11, 0, 24)]:
		_solid(Vector3(1.1, 1.1, 1.1), p + Vector3(0, 0.55, 0), Color(0.5, 0.4, 0.25))
	for p in [Vector3(-20, 6, 10), Vector3(20, 6, 40)]:
		_solid(Vector3(0.3, 6, 0.3), Vector3(p.x, 3, p.z), C_METAL, 0, false)
		_light(p + Vector3(0, 0.2, 0), Color(1.0, 0.75, 0.45), 2.5, 22.0)

func _north() -> void:
	# helipad
	Geo.cyl(6.5, 0.06, Color(0.25, 0.25, 0.27), Vector3(0, 0.03, -52), root)
	Geo.box(Vector3(0.8, 0.02, 5), Color(0.62, 0.55, 0.22), Vector3(-1.4, 0.07, -52), root)
	Geo.box(Vector3(0.8, 0.02, 5), Color(0.62, 0.55, 0.22), Vector3(1.4, 0.07, -52), root)
	Geo.box(Vector3(2.0, 0.02, 0.8), Color(0.62, 0.55, 0.22), Vector3(0, 0.07, -52), root)
	for p in [Vector3(-10, 0, -34), Vector3(9, 0, -36), Vector3(-4, 0, -42), Vector3(12, 0, -46)]:
		_solid(Vector3(3.2, 0.95, 0.6), p + Vector3(0, 0.475, 0), C_CONCRETE, rng.randf_range(-30, 30))
	# sandbag nest + guard tower
	_solid(Vector3(4, 1.1, 1), Vector3(20, 0.55, -38), Color(0.55, 0.5, 0.35))
	_solid(Vector3(1, 1.1, 3), Vector3(18.5, 0.55, -40), Color(0.55, 0.5, 0.35))
	for x in [-26.0, -23.0]:
		for z in [-38.0, -35.0]:
			_solid(Vector3(0.3, 5, 0.3), Vector3(x, 2.5, z), C_METAL, 0, false)
	_solid(Vector3(3.6, 0.3, 3.6), Vector3(-24.5, 5.1, -36.5), C_METAL, 0, false)
	_light(Vector3(0, 5, -45), Color(1.0, 0.8, 0.5), 2.0, 20.0)

func _east_tanks() -> void:
	for p in [Vector3(42, 0, -10), Vector3(42, 0, 4), Vector3(54, 0, -3)]:
		var b := StaticBody3D.new()
		b.position = p + Vector3(0, 4, 0)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 4.5
		sh.height = 8
		cs.shape = sh
		b.add_child(cs)
		Geo.cyl(4.5, 8, Color(0.62, 0.6, 0.55), Vector3.ZERO, b)
		root.add_child(b)
		info["footprints"].append([p.x, p.z, 9.0, 9.0, 0.0])
	_solid(Vector3(16, 0.6, 0.6), Vector3(34, 3, -3), C_METAL, 0, false)
	_solid(Vector3(10, 3, 0.4), Vector3(30, 1.5, 20), C_WALL)
	_solid(Vector3(0.4, 3, 12), Vector3(30, 1.5, 26), C_WALL)

class_name IndustrialMap
## OP-01 "First Contact": Vessk Industrial — an abandoned facility taken over by The Dominion.
## Colliders (identical on client and server, fixed RNG seed) define gameplay space; everything else is
## client-only presentation built from Props/Mat/Geo plus supplied Synty sprites as decals, signage and banners.

var root: Node3D
var rng := RandomNumberGenerator.new()
var info := {"zones": {}, "interactables": {}, "footprints": [], "bounds": Rect2(-70, -70, 140, 140), "extraction": Vector3.ZERO}
var V := Geo.visuals   # presentation enabled (false on the dedicated server)

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
	_dressing()
	info["zones"]["warehouse_interior"] = AABB(Vector3(-18, -1, -24), Vector3(36, 9, 26))
	info["zones"]["loading_yard"] = AABB(Vector3(-22, -1, 8), Vector3(44, 8, 34))
	info["zones"]["extraction_zone"] = AABB(Vector3(-7, -1, -59), Vector3(14, 8, 14))
	info["extraction"] = Vector3(0, 0, -52)
	return info

# ------------------------------------------------------------------ helpers
func m(f: Callable) -> Variant:
	return f.call() if V else null

func _solid(size: Vector3, pos: Vector3, mat_f: Callable, rot := 0.0, footprint := true, bevel := 0.03) -> StaticBody3D:
	var b := Geo.solid(root, size, pos, m(mat_f), rot, bevel)
	if footprint and size.y > 0.8:
		info["footprints"].append([pos.x, pos.z, size.x, size.z, deg_to_rad(rot)])
	return b

## Collider-only box (visuals supplied separately).
func _block(size: Vector3, pos: Vector3, rot := 0.0, footprint := true) -> StaticBody3D:
	var b := Geo.solid(root, size, pos, null, rot)
	if footprint and size.y > 0.8:
		info["footprints"].append([pos.x, pos.z, size.x, size.z, deg_to_rad(rot)])
	return b

func _node(pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees.y = rot_y
	root.add_child(n)
	return n

# ------------------------------------------------------------------ terrain
func _ground() -> void:
	Geo.solid(root, Vector3(160, 1, 160), Vector3(0, -0.5, 0), null)
	if not V:
		return
	Geo.part(root, Vector3(160, 0.02, 160), Vector3(0, -0.01, 0), Mat.ground(), Vector3.ZERO, 0.0)
	Geo.part(root, Vector3(48, 0.03, 38), Vector3(0, 0.0, 25), Mat.asphalt(), Vector3.ZERO, 0.0)       # yard apron
	Geo.part(root, Vector3(9, 0.03, 30), Vector3(0, 0.0, 55), Mat.asphalt(), Vector3.ZERO, 0.0)        # access road
	Geo.part(root, Vector3(22, 0.03, 32), Vector3(0, 0.0, -40), Mat.concrete(Color(0.6, 0.58, 0.54)), Vector3.ZERO, 0.0)
	Geo.part(root, Vector3(14, 0.03, 16), Vector3(-40, 0.0, -6), Mat.concrete(Color(0.56, 0.54, 0.5)), Vector3.ZERO, 0.0)
	# painted lane markings on the apron and road
	for z in range(12, 42, 4):
		Geo.part(root, Vector3(0.18, 0.01, 2.0), Vector3(0, 0.02, z), Mat.painted(Color(0.85, 0.82, 0.7), 0.8), Vector3.ZERO, 0.0)
	for x in [-23.5, 23.5]:
		Geo.part(root, Vector3(0.2, 0.01, 36), Vector3(x, 0.02, 25), Mat.painted(Color(0.85, 0.7, 0.2), 0.8), Vector3.ZERO, 0.0)
	for z in range(44, 70, 5):
		Geo.part(root, Vector3(0.18, 0.01, 2.4), Vector3(0, 0.02, z), Mat.painted(Color(0.85, 0.82, 0.7), 0.8), Vector3.ZERO, 0.0)

# ------------------------------------------------------------------ walls
func _wall_x(z: float, x0: float, x1: float, h: float, gaps: Array, style: String, t := 0.4, door_h := 3.2) -> void:
	var cuts := [x0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(x1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]; var b: float = cuts[i + 1]
		if b - a > 0.05:
			_block(Vector3(b - a, h, t), Vector3((a + b) * 0.5, h * 0.5, z))
			_wall_visual(Vector3(b - a, h, t), Vector3((a + b) * 0.5, h * 0.5, z), false, style)
	for g in gaps:
		if h > door_h:
			var sz := Vector3(g[1] - g[0], h - door_h, t)
			var p := Vector3((g[0] + g[1]) * 0.5, door_h + (h - door_h) * 0.5, z)
			_block(sz, p, 0.0, false)
			_wall_visual(sz, p, false, style)
			_door_frame(Vector3((g[0] + g[1]) * 0.5, 0, z), g[1] - g[0], door_h, false, t, style)

func _wall_z(x: float, z0: float, z1: float, h: float, gaps: Array, style: String, t := 0.4, door_h := 3.2) -> void:
	var cuts := [z0]
	for g in gaps:
		cuts.append(g[0]); cuts.append(g[1])
	cuts.append(z1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]; var b: float = cuts[i + 1]
		if b - a > 0.05:
			_block(Vector3(t, h, b - a), Vector3(x, h * 0.5, (a + b) * 0.5))
			_wall_visual(Vector3(t, h, b - a), Vector3(x, h * 0.5, (a + b) * 0.5), true, style)
	for g in gaps:
		if h > door_h:
			var sz := Vector3(t, h - door_h, g[1] - g[0])
			var p := Vector3(x, door_h + (h - door_h) * 0.5, (g[0] + g[1]) * 0.5)
			_block(sz, p, 0.0, false)
			_wall_visual(sz, p, true, style)
			_door_frame(Vector3(x, 0, (g[0] + g[1]) * 0.5), g[1] - g[0], door_h, true, t, style)

## Layered wall presentation: concrete plinth, cladding, top flashing, structural columns.
func _wall_visual(size: Vector3, pos: Vector3, along_z: bool, style: String) -> void:
	if not V:
		return
	var plinth_h := minf(1.1, size.y)
	var long := size.z if along_z else size.x
	var thick := size.x if along_z else size.z
	var axis := Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var bottom := pos.y - size.y * 0.5
	match style:
		"warehouse":
			var dims := func(l, h, t): return Vector3(t, h, l) if along_z else Vector3(l, h, t)
			if bottom < 0.1:
				Geo.part(root, dims.call(long, plinth_h, thick + 0.06), Vector3(pos.x, plinth_h * 0.5, pos.z), Mat.concrete(Color(0.62, 0.6, 0.56)), Vector3.ZERO, 0.02)
				Geo.part(root, dims.call(long, size.y - plinth_h, thick), Vector3(pos.x, plinth_h + (size.y - plinth_h) * 0.5, pos.z), Mat.corrugated(Color(0.46, 0.48, 0.42)), Vector3.ZERO, 0.0)
			else:
				Geo.part(root, size, pos, Mat.corrugated(Color(0.46, 0.48, 0.42)), Vector3.ZERO, 0.0)
			Geo.part(root, dims.call(long + 0.05, 0.25, thick + 0.12), Vector3(pos.x, bottom + size.y - 0.12, pos.z), Mat.painted(Color(0.55, 0.5, 0.36)), Vector3.ZERO, 0.02)
			if long > 3.0 and bottom < 0.1:
				var n := int(long / 6.0)
				for i in range(1, n + 1):
					var off := -long * 0.5 + i * long / (n + 1)
					for side in [-1, 1]:
						Geo.part(root, dims.call(0.3, size.y, 0.25), pos + axis * off + Vector3(0, 0, 0) + (Vector3(side * (thick * 0.5 + 0.12), 0, 0) if along_z else Vector3(0, 0, side * (thick * 0.5 + 0.12))), Mat.painted(Color(0.45, 0.46, 0.42)), Vector3.ZERO, 0.02)
		"brick":
			Geo.part(root, size, pos, Mat.concrete(Color(0.62, 0.48, 0.38)), Vector3.ZERO, 0.02)
			var dims2 := Vector3(thick + 0.1, 0.2, long + 0.05) if along_z else Vector3(long + 0.05, 0.2, thick + 0.1)
			Geo.part(root, dims2, Vector3(pos.x, bottom + size.y - 0.1, pos.z), Mat.concrete(Color(0.7, 0.68, 0.64)), Vector3.ZERO, 0.02)
		"perimeter":
			Geo.part(root, size, pos, Mat.concrete(Color(0.66, 0.64, 0.6)), Vector3.ZERO, 0.04)
			var n2 := int(long / 5.0)
			for i in n2 + 1:
				var off2 := -long * 0.5 + i * long / maxi(1, n2)
				Geo.part(root, Vector3(0.6, size.y + 0.3, 0.6), Vector3(pos.x, (size.y + 0.3) * 0.5, pos.z) + axis * off2, Mat.concrete(Color(0.58, 0.56, 0.52)), Vector3.ZERO, 0.05)
			# razor wire coil along the top
			var coil := Geo.tube(root, 0.22, long, Vector3(pos.x, size.y + 0.45, pos.z), Mat.metal(Color(0.6, 0.6, 0.6), 0.3), Vector3(90, 0, 0) if along_z else Vector3(0, 0, 90), 8)
			if coil is GeometryInstance3D:
				coil.transparency = 0.35
		"office":
			Geo.part(root, size, pos, Mat.painted(Color(0.74, 0.72, 0.66), 0.85), Vector3.ZERO, 0.01)

func _door_frame(base: Vector3, width: float, h: float, along_z: bool, t: float, style: String) -> void:
	if not V:
		return
	var rot := Vector3(0, 90, 0) if along_z else Vector3.ZERO
	var n := Node3D.new()
	n.position = base
	n.rotation_degrees = rot
	root.add_child(n)
	var frame_m := Mat.painted(Color(0.78, 0.6, 0.12), 0.6) if style == "warehouse" else Mat.painted(Color(0.3, 0.32, 0.3))
	for s in [-1, 1]:
		Geo.part(n, Vector3(0.18, h, t + 0.14), Vector3(s * (width * 0.5 + 0.09), h * 0.5, 0), frame_m, Vector3.ZERO, 0.02)
		for i in 5:   # hazard bands
			Geo.part(n, Vector3(0.19, 0.2, t + 0.15), Vector3(s * (width * 0.5 + 0.09), 0.3 + i * 0.6, 0), Mat.painted(Color(0.08, 0.08, 0.08)), Vector3(0, 0, 25), 0.0)
	Geo.part(n, Vector3(width + 0.36, 0.2, t + 0.14), Vector3(0, h + 0.1, 0), frame_m, Vector3.ZERO, 0.02)
	if style == "warehouse":   # rolled-up shutter housing
		Geo.tube(n, 0.32, width + 0.2, Vector3(0, h + 0.45, t * 0.5 + 0.3), Mat.metal(Color(0.5, 0.5, 0.48)), Vector3(0, 0, 90), 12)

# ------------------------------------------------------------------ areas
func _perimeter() -> void:
	_wall_x(-70, -70, 70, 3.5, [], "perimeter")
	_wall_x(70, -70, 70, 3.5, [[-6, 6]], "perimeter")
	_wall_z(-70, -70, 70, 3.5, [], "perimeter")
	_wall_z(70, -70, 70, 3.5, [], "perimeter")
	_solid(Vector3(1, 4.5, 1), Vector3(-6.5, 2.25, 70), func(): return Mat.concrete(Color(0.5, 0.48, 0.45)))
	_solid(Vector3(1, 4.5, 1), Vector3(6.5, 2.25, 70), func(): return Mat.concrete(Color(0.5, 0.48, 0.45)))
	# insertion vehicle (collider unchanged)
	_block(Vector3(2.4, 1.6, 5.5), Vector3(6, 1.1, 60))
	Props.truck(_node(Vector3(6, 1.35, 60)), Color(0.36, 0.38, 0.27))
	if V:
		# gate: open sliding gate parked beside the opening, boom barrier, guard booth
		var g := _node(Vector3(-11, 0, 69.3))
		Props.fence(g, 9.0, 2.6)
		var booth := _node(Vector3(9.5, 0, 66))
		Geo.part(booth, Vector3(2.2, 2.6, 2.2), Vector3(0, 1.3, 0), Mat.painted(Color(0.7, 0.68, 0.6)), Vector3.ZERO, 0.04)
		Geo.part(booth, Vector3(2.5, 0.15, 2.5), Vector3(0, 2.7, 0), Mat.painted(Color(0.3, 0.32, 0.28)), Vector3.ZERO, 0.02)
		Geo.part(booth, Vector3(1.6, 0.8, 0.04), Vector3(0, 1.6, -1.11), Mat.glass())
		Props.sign_board(root, Vector3(-7.4, 2.6, 70.6), 180.0, UiKit.ICON_MAP_DANGER, Color(0.85, 0.7, 0.15), Color(0.1, 0.1, 0.1), 1.0)

func _warehouse() -> void:
	var h := 8.0
	_wall_x(2, -18, 18, h, [[-8, -4], [6, 10]], "warehouse")
	_wall_x(-24, -18, 18, h, [[-2, 2]], "warehouse")
	_wall_z(-18, -24, 2, h, [[-6, -3]], "warehouse")
	_wall_z(18, -24, 2, h, [[-12, -8]], "warehouse")
	_block(Vector3(36.8, 0.4, 26.8), Vector3(0, h + 0.2, -11), 0.0, false)
	if V:
		Geo.part(root, Vector3(37.2, 0.3, 27.2), Vector3(0, h + 0.25, -11), Mat.corrugated(Color(0.4, 0.4, 0.4)), Vector3(0, 0, 0), 0.0)
		Geo.part(root, Vector3(35.6, 0.03, 25.6), Vector3(0, 0.015, -11), Mat.concrete(Color(0.58, 0.57, 0.54)), Vector3.ZERO, 0.0)
		# roof trusses + skylights
		for x in range(-15, 18, 6):
			Geo.part(root, Vector3(0.25, 0.5, 25.6), Vector3(x, h - 0.4, -11), Mat.painted(Color(0.42, 0.44, 0.4)), Vector3.ZERO, 0.02)
			for z in range(-22, 1, 4):
				Geo.part(root, Vector3(0.08, 0.7, 0.08), Vector3(x, h - 0.75, z), Mat.metal(), Vector3(0, 0, 30), 0.0)
		for z in range(-21, 0, 6):
			Geo.part(root, Vector3(35, 0.2, 0.2), Vector3(0, h - 0.2, z), Mat.painted(Color(0.42, 0.44, 0.4)), Vector3.ZERO, 0.02)
		for x in [-9.0, 3.0, 13.0]:
			Geo.part(root, Vector3(3.0, 0.05, 9.0), Vector3(x, h + 0.42, -11), Mat.glass(Color(0.75, 0.8, 0.75, 0.55)), Vector3.ZERO, 0.0)
		# floor markings: walkway lines + hazard zones (supplied hazard-stripe sprite as decal)
		for x in [-15.5, -3.0, 8.5]:
			Geo.part(root, Vector3(0.15, 0.01, 24), Vector3(x, 0.035, -11), Mat.painted(Color(0.85, 0.7, 0.18), 0.8), Vector3.ZERO, 0.0)
		Props.decal(root, UiKit.SPR_HAZARD, Vector3(-6, 0.0, 0.8), Vector3(4.2, 1.0, 1.0), Color(0.95, 0.75, 0.15, 0.9))
		Props.decal(root, UiKit.SPR_HAZARD, Vector3(8, 0.0, 0.8), Vector3(4.2, 1.0, 1.0), Color(0.95, 0.75, 0.15, 0.9))
		Props.decal(root, UiKit.SPR_HAZARD, Vector3(0, 0.0, -23.2), Vector3(4.2, 1.0, 1.0), Color(0.95, 0.75, 0.15, 0.9))
	# rack rows (colliders unchanged) with detailed shelving
	for x in [-12.0, -6.0]:
		for z in [-19.0, -10.0]:
			_block(Vector3(1.2, 3.2, 6.5), Vector3(x, 1.6, z))
			_rack_visual(Vector3(x, 0, z))
	for p in [Vector3(2, 0, -4), Vector3(3.3, 0, -4), Vector3(2.6, 1.2, -4), Vector3(-2, 0, -15), Vector3(6, 0, -14), Vector3(-15, 0, -2)]:
		_block(Vector3(1.2, 1.2, 1.2), p + Vector3(0, 0.6, 0))
		Props.crate(_node(p + Vector3(0, 0.6, 0), rng.randf_range(-6, 6)), 1.2, int(p.x * 10) % 2 == 0)
	_block(Vector3(1.6, 2.0, 3.0), Vector3(4, 1.0, -19))
	Props.forklift(_node(Vector3(4, 1.0, -19)))
	# site office (north-east corner)
	_wall_z(10, -24, -16, 3.0, [[-21, -19]], "office", 0.2, 2.4)
	_wall_x(-16, 10, 18, 3.0, [[13, 15]], "office", 0.2, 2.4)
	_solid(Vector3(8.2, 0.2, 8.2), Vector3(14, 3.1, -20), func(): return Mat.painted(Color(0.7, 0.7, 0.66)), 0.0, false)
	_block(Vector3(2.0, 0.9, 1.0), Vector3(15, 0.45, -22.5), 0.0, false)
	info["interactables"]["intel_laptop"] = {"pos": Vector3(15, 1.0, -22.5), "label": "Download intelligence"}
	if V:
		var desk := _node(Vector3(15, 0, -22.5))
		Geo.part(desk, Vector3(2.0, 0.06, 1.0), Vector3(0, 0.87, 0), Mat.wood(Color(0.5, 0.4, 0.3)), Vector3.ZERO, 0.01)
		for sx in [-0.9, 0.9]:
			Geo.part(desk, Vector3(0.06, 0.84, 0.9), Vector3(sx, 0.42, 0), Mat.metal(Color(0.3, 0.3, 0.3)), Vector3.ZERO, 0.0)
		Geo.part(desk, Vector3(0.5, 0.6, 0.85), Vector3(0.6, 0.35, 0), Mat.painted(Color(0.42, 0.44, 0.42)), Vector3.ZERO, 0.02)  # drawer unit
		# rugged laptop (intel objective) with a supplied HUD sprite on its screen
		var lap := Node3D.new()
		lap.position = Vector3(0, 0.91, 0)
		desk.add_child(lap)
		Geo.part(lap, Vector3(0.42, 0.03, 0.3), Vector3.ZERO, Mat.polymer(Color(0.2, 0.22, 0.18)), Vector3.ZERO, 0.01)
		var lid := Geo.part(lap, Vector3(0.42, 0.28, 0.02), Vector3(0, 0.14, -0.15), Mat.polymer(Color(0.2, 0.22, 0.18)), Vector3(-12, 0, 0), 0.01)
		var scr := Sprite3D.new()
		scr.texture = UiKit.tex(UiKit.SPR_TECHY)
		scr.modulate = Color(0.4, 0.9, 1.0)
		scr.pixel_size = 0.36 / float(maxi(1, scr.texture.get_width())) if scr.texture else 0.001
		scr.position = Vector3(0, 0.0, 0.012)   # lid at the far side; the screen faces the player south of the desk
		scr.shaded = false
		lid.add_child(scr)
		Geo.part(desk, Vector3(0.28, 0.22, 0.04), Vector3(-0.6, 1.0, 0.2), Mat.polymer(), Vector3(0, 15, 0), 0.01)  # radio
		Geo.part(desk, Vector3(0.5, 0.06, 0.4), Vector3(-0.2, 0.92, -0.15), Mat.painted(Color(0.85, 0.83, 0.75)), Vector3(0, 12, 0), 0.0)  # papers
		# chair, filing cabinets, whiteboard, maps
		Geo.part(root, Vector3(0.5, 0.08, 0.5), Vector3(15, 0.5, -21.5), Mat.fabric(Color(0.15, 0.15, 0.15)), Vector3.ZERO, 0.03)
		Geo.part(root, Vector3(0.5, 0.55, 0.08), Vector3(15, 0.8, -21.25), Mat.fabric(Color(0.15, 0.15, 0.15)), Vector3.ZERO, 0.03)
		Geo.tube(root, 0.03, 0.45, Vector3(15, 0.25, -21.5), Mat.metal(), Vector3.ZERO, 6)
		for i in 3:
			Geo.part(root, Vector3(0.5, 1.3, 0.6), Vector3(17.5, 0.65, -18.0 + i * 0.55), Mat.painted(Color(0.45, 0.47, 0.44)), Vector3.ZERO, 0.02)
		Geo.part(root, Vector3(0.05, 1.0, 1.8), Vector3(10.15, 1.6, -18), Mat.painted(Color(0.92, 0.92, 0.9), 0.3), Vector3.ZERO, 0.01)
		var mapboard := Sprite3D.new()
		mapboard.texture = UiKit.tex(UiKit.SPR_SAMPLE_MAP)
		if mapboard.texture:
			mapboard.pixel_size = 0.95 / float(mapboard.texture.get_width())
		mapboard.position = Vector3(10.2, 1.6, -18)
		mapboard.rotation_degrees.y = 90
		mapboard.shaded = true
		root.add_child(mapboard)
		# office windows (glass strip) + broken glass decal on the floor
		Geo.part(root, Vector3(0.04, 0.8, 2.5), Vector3(10.0, 1.7, -23), Mat.glass(), Vector3.ZERO, 0.0)
		Props.decal(root, "FX/SPR_FX_MilitaryCombat_BrokenGlass_01.png", Vector3(9.2, 0.0, -22.5), Vector3(1.6, 0.6, 1.6), Color(0.9, 0.95, 1.0, 0.8))
		Props.hanging_lamp(root, Vector3(14, 2.85, -20), 2.6, 10.0, Color(0.9, 0.95, 1.0))
		Props.sign_board(root, Vector3(14, 2.5, -15.88), 0.0, UiKit.ICON_MAP_HOME, Color(0.2, 0.3, 0.25), Color(0.9, 0.9, 0.85), 0.6)
		for p in [Vector3(-10, 7.2, -18), Vector3(-10, 7.2, -5), Vector3(4, 7.2, -18), Vector3(4, 7.2, -5), Vector3(-3, 7.2, -11.5)]:
			Props.hanging_lamp(root, p, 3.2, 17.0)
		Props.banner(root, Vector3(0, 4.6, -23.75), 0.0)
		Props.banner(root, Vector3(-17.75, 4.6, -15), 90.0)

func _rack_visual(base: Vector3) -> void:
	if not V:
		return
	var n := _node(base)
	var frame := Mat.painted(Color(0.18, 0.32, 0.55), 0.55)
	var beam := Mat.painted(Color(0.85, 0.45, 0.1), 0.55)
	for z in [-3.15, -1.05, 1.05, 3.15]:
		for x in [-0.55, 0.55]:
			Geo.part(n, Vector3(0.08, 3.2, 0.08), Vector3(x, 1.6, z), frame, Vector3.ZERO, 0.01)
	for y in [0.15, 1.15, 2.15, 3.1]:
		for x in [-0.55, 0.55]:
			Geo.part(n, Vector3(0.06, 0.12, 6.4), Vector3(x, y, 0), beam, Vector3.ZERO, 0.01)
		Geo.part(n, Vector3(1.1, 0.03, 6.3), Vector3(0, y + 0.07, 0), Mat.wood(Color(0.55, 0.45, 0.32)), Vector3.ZERO, 0.0)
	for y in [0.2, 1.2, 2.2]:
		for z in [-2.1, 0.0, 2.1]:
			var kind := int(absf(base.x * 3 + z * 7 + y * 11)) % 4
			if kind == 0:
				continue
			var c := _node(Vector3.ZERO)
			c.reparent(n, false)
			c.position = Vector3(0, y + 0.08, z)
			if kind == 1:
				Props.pallet(c, Vector3.ZERO, 2)
			elif kind == 2:
				for i in 3:
					Geo.part(c, Vector3(0.5, 0.4, 0.5), Vector3(-0.25 + (i % 2) * 0.5, 0.22 + (i / 2) * 0.42, 0.2 - (i % 2) * 0.4), Mat.painted(Color(0.6, 0.5, 0.35), 0.9), Vector3(0, i * 9, 0), 0.03)
			else:
				var b := Node3D.new()
				b.position = Vector3(0, 0.1, 0)
				c.add_child(b)
				Props.barrel(b, Color(0.22, 0.3, 0.45))

func _maintenance() -> void:
	var h := 4.5
	_wall_x(0, -46, -34, h, [[-42, -39]], "brick")
	_wall_x(-12, -46, -34, h, [], "brick")
	_wall_z(-46, -12, 0, h, [], "brick")
	_wall_z(-34, -12, 0, h, [[-7, -4]], "brick")
	_solid(Vector3(12.8, 0.3, 12.8), Vector3(-40, h + 0.15, -6), func(): return Mat.painted(Color(0.36, 0.36, 0.36)), 0.0, false)
	_block(Vector3(1.0, 2.2, 2.4), Vector3(-45, 1.1, -9))
	info["interactables"]["data_server"] = {"pos": Vector3(-44.3, 1.2, -9), "label": "Download server logs"}
	_block(Vector3(3, 1.0, 1.0), Vector3(-38, 0.5, -11))
	if V:
		var rack := _node(Vector3(-45, 1.1, -9))
		Geo.part(rack, Vector3(1.0, 2.2, 2.4), Vector3.ZERO, Mat.painted(Color(0.12, 0.12, 0.13), 0.4), Vector3.ZERO, 0.02)
		for i in 9:
			Geo.part(rack, Vector3(0.02, 0.16, 2.1), Vector3(0.51, -0.9 + i * 0.22, 0), Mat.metal(Color(0.3, 0.3, 0.32)), Vector3.ZERO, 0.0)
			for j in 6:
				var led := Mat.emissive(Color(0.2, 1.0, 0.35) if (i + j) % 3 else Color(1.0, 0.6, 0.1), 3.0)
				Geo.part(rack, Vector3(0.02, 0.03, 0.03), Vector3(0.53, -0.9 + i * 0.22, -0.9 + j * 0.3), led, Vector3.ZERO, 0.0)
		var bench := _node(Vector3(-38, 0, -11))
		Geo.part(bench, Vector3(3, 0.08, 1.0), Vector3(0, 0.96, 0), Mat.wood(Color(0.45, 0.36, 0.26)), Vector3.ZERO, 0.01)
		Geo.part(bench, Vector3(2.9, 0.9, 0.9), Vector3(0, 0.45, 0), Mat.painted(Color(0.35, 0.4, 0.36)), Vector3.ZERO, 0.02)
		Geo.part(bench, Vector3(0.6, 0.25, 0.3), Vector3(-0.8, 1.13, 0), Mat.painted(Color(0.7, 0.15, 0.1), 0.5), Vector3(0, 10, 0), 0.02)  # toolbox
		Geo.part(bench, Vector3(2.9, 1.2, 0.04), Vector3(0, 1.8, 0.47), Mat.painted(Color(0.4, 0.42, 0.38)), Vector3.ZERO, 0.0)   # pegboard
		# rooftop AC + pipes
		Geo.part(root, Vector3(2, 0.9, 1.4), Vector3(-42, h + 0.75, -3), Mat.painted(Color(0.6, 0.6, 0.58)), Vector3.ZERO, 0.05)
		Geo.tube(root, 0.12, 4.6, Vector3(-33.7, 2.3, -10), Mat.metal(Color(0.5, 0.48, 0.45)), Vector3.ZERO, 8)
		Props.hanging_lamp(root, Vector3(-40, 4.0, -6), 1.6, 10.0, Color(0.8, 0.9, 1.0))
		Props.sign_board(root, Vector3(-33.75, 3.4, -5.5), 90.0, UiKit.ICON_MAP_LIGHTNING, Color(0.85, 0.7, 0.15), Color(0.1, 0.1, 0.1), 0.7)
		Props.decal(root, "FX/SPR_FX_MilitaryCombat_BloodSplats_01.png", Vector3(-37, 0.0, -4), Vector3(1.6, 0.6, 1.6), Color(0.1, 0.08, 0.06, 0.55))  # oil stain
	for p in [Vector3(-30, 0, 8), Vector3(-26, 0, -18), Vector3(-50, 0, 12)]:
		var rot := rng.randf() * 40.0
		_block(Vector3(3, 1.4, 2), p + Vector3(0, 0.7, 0), rot)
		if V:
			var s := _node(p + Vector3(0, 0.7, 0), rot)
			Geo.part(s, Vector3(3, 0.5, 2), Vector3(0, -0.45, 0), Mat.rust(), Vector3(0, 0, 3), 0.1)
			Geo.part(s, Vector3(1.6, 0.9, 1.4), Vector3(-0.5, 0.2, 0.1), Mat.rust(Color(0.4, 0.32, 0.25)), Vector3(8, 20, 0), 0.08)
			Props.tire_stack(_node(p + Vector3(1.0, 0.0, 0.4)), 2)
			Props.barrel(_node(p + Vector3(0.9, 0.3, -0.5)), Color(0.5, 0.25, 0.15), true)

func _container(pos: Vector3, rot: float, color: Color) -> void:
	_block(Vector3(2.5, 2.6, 6.1), pos + Vector3(0, 1.3, 0), rot)
	Props.container(_node(pos + Vector3(0, 1.3, 0), rot), color)

func _yard() -> void:
	_container(Vector3(-14, 0, 16), 0, Props.C_CONTAINER[0])
	_container(Vector3(-6, 0, 27), 90, Props.C_CONTAINER[1])
	_container(Vector3(8, 0, 17), 0, Props.C_CONTAINER[2])
	_container(Vector3(15, 0, 30), 90, Props.C_CONTAINER[3])
	_container(Vector3(15, 2.6, 30), 90, Props.C_CONTAINER[4])
	_block(Vector3(2.4, 1.6, 5.5), Vector3(-1, 1.1, 36), 90.0)
	Props.truck(_node(Vector3(-1, 1.35, 36), 90.0), Color(0.55, 0.5, 0.4), false)
	for p in [Vector3(-18, 0, 30), Vector3(0, 0, 12), Vector3(19, 0, 12), Vector3(4, 0, 44), Vector3(-10, 0, 44)]:
		var rot := rng.randf_range(-20, 20)
		_block(Vector3(3.2, 0.95, 0.6), p + Vector3(0, 0.475, 0), rot)
		Props.jersey_barrier(_node(p + Vector3(0, 0.475, 0), rot))
	for p in [Vector3(-3, 0, 20), Vector3(-2, 0, 20), Vector3(11, 0, 24)]:
		_block(Vector3(1.1, 1.1, 1.1), p + Vector3(0, 0.55, 0))
		Props.crate(_node(p + Vector3(0, 0.55, 0), rng.randf_range(-8, 8)), 1.1)
	for p in [Vector3(-20, 0, 10), Vector3(20, 0, 40)]:
		_block(Vector3(0.3, 6, 0.3), Vector3(p.x, 3, p.z), 0.0, false)
		Props.light_pole(_node(Vector3(p.x, 0, p.z), 90.0 if p.x < 0 else -90.0))
		if V:
			var l := SpotLight3D.new()
			l.position = Vector3(p.x + (1.0 if p.x < 0 else -1.0), 5.7, p.z)
			l.rotation_degrees = Vector3(-70, -90 if p.x < 0 else 90, 0)
			l.light_color = Color(1.0, 0.78, 0.5)
			l.light_energy = 4.0
			l.spot_range = 26.0
			l.spot_angle = 55.0
			root.add_child(l)

func _north() -> void:
	if V:
		var pad := _node(Vector3(0, 0, -52))
		Geo.tube(pad, 6.6, 0.08, Vector3(0, 0.04, 0), Mat.concrete(Color(0.42, 0.42, 0.42)), Vector3.ZERO, 32)
		Geo.tube(pad, 6.2, 0.02, Vector3(0, 0.085, 0), Mat.painted(Color(0.28, 0.29, 0.3), 0.7), Vector3.ZERO, 32)
		var paint := Mat.painted(Color(0.85, 0.82, 0.74), 0.7)
		Geo.part(pad, Vector3(0.7, 0.01, 4.2), Vector3(-1.3, 0.1, 0), paint, Vector3.ZERO, 0.0)
		Geo.part(pad, Vector3(0.7, 0.01, 4.2), Vector3(1.3, 0.1, 0), paint, Vector3.ZERO, 0.0)
		Geo.part(pad, Vector3(1.9, 0.01, 0.7), Vector3(0, 0.1, 0), paint, Vector3.ZERO, 0.0)
		for i in 12:
			var a := TAU * i / 12.0
			Geo.part(pad, Vector3(0.18, 0.08, 0.18), Vector3(cos(a) * 6.4, 0.12, sin(a) * 6.4), Mat.emissive(Color(1.0, 0.75, 0.2), 3.0), Vector3.ZERO, 0.02)
		# windsock
		var ws := _node(Vector3(9, 0, -58))
		Geo.tube(ws, 0.06, 5.0, Vector3(0, 2.5, 0), Mat.painted(Color(0.85, 0.85, 0.8)), Vector3.ZERO, 6)
		Geo.tube(ws, 0.35, 1.8, Vector3(0.9, 4.8, 0), Mat.fabric(Color(0.9, 0.4, 0.1)), Vector3(0, 0, 80), 10, 0.15)
		Props.sign_board(root, Vector3(-7.6, 1.5, -45.5), 0.0, UiKit.ICON_HELI, Color(0.2, 0.32, 0.25), Color(0.95, 0.9, 0.7), 1.0)
		var post := Geo.tube(root, 0.05, 1.5, Vector3(-7.6, 0.75, -45.55), Mat.metal(), Vector3.ZERO, 6)
	for p in [Vector3(-10, 0, -34), Vector3(9, 0, -36), Vector3(-4, 0, -42), Vector3(12, 0, -46)]:
		var rot := rng.randf_range(-30, 30)
		_block(Vector3(3.2, 0.95, 0.6), p + Vector3(0, 0.475, 0), rot)
		Props.jersey_barrier(_node(p + Vector3(0, 0.475, 0), rot))
	_block(Vector3(4, 1.1, 1), Vector3(20, 0.55, -38))
	_block(Vector3(1, 1.1, 3), Vector3(18.5, 0.55, -40))
	if V:
		var sb1 := _node(Vector3(20, 0.55, -38))
		Props.sandbag_wall(sb1, 4.0, 5)
		var sb2 := _node(Vector3(18.5, 0.55, -40), 90.0)
		Props.sandbag_wall(sb2, 3.0, 5)
		Props.crate(_node(Vector3(21, 0.4, -39.5), 15.0), 0.8)
	for x in [-26.0, -23.0]:
		for z in [-38.0, -35.0]:
			_block(Vector3(0.3, 5, 0.3), Vector3(x, 2.5, z), 0.0, false)
	_block(Vector3(3.6, 0.3, 3.6), Vector3(-24.5, 5.1, -36.5), 0.0, false)
	Props.tower(_node(Vector3(-24.5, 0, -36.5)))
	if V:
		Props.light_pole(_node(Vector3(0, 0, -45)), 6.0)
		var l := OmniLight3D.new()
		l.position = Vector3(1, 5.4, -45)
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 2.4
		l.omni_range = 20.0
		root.add_child(l)

func _east_tanks() -> void:
	for p in [Vector3(42, 0, -10), Vector3(42, 0, 4), Vector3(54, 0, -3)]:
		Geo.solid_cyl(root, 4.5, 8, p + Vector3(0, 4, 0), null)
		info["footprints"].append([p.x, p.z, 9.0, 9.0, 0.0])
		Props.tank(_node(p + Vector3(0, 4, 0)), 4.5, 8.0)
	_block(Vector3(16, 0.6, 0.6), Vector3(34, 3, -3), 0.0, false)
	if V:
		var pipe := _node(Vector3(34, 3, -3))
		Geo.tube(pipe, 0.3, 16, Vector3.ZERO, Mat.painted(Color(0.55, 0.5, 0.3)), Vector3(0, 0, 90), 12)
		for x in [-6.0, -2.0, 2.0, 6.0]:
			Geo.part(pipe, Vector3(0.2, 3.0, 0.2), Vector3(x, -1.5, 0), Mat.painted(Color(0.42, 0.44, 0.42)), Vector3.ZERO, 0.02)
			Geo.tube(pipe, 0.34, 0.12, Vector3(x, 0, 0), Mat.metal(), Vector3(0, 0, 90), 12)
	_solid(Vector3(10, 3, 0.4), Vector3(30, 1.5, 20), func(): return Mat.concrete(Color(0.62, 0.6, 0.56)))
	_solid(Vector3(0.4, 3, 12), Vector3(30, 1.5, 26), func(): return Mat.concrete(Color(0.62, 0.6, 0.56)))
	if V:
		Props.generator(_node(Vector3(33, 0.65, 23)))
		Props.cable_spool(_node(Vector3(34.5, 0, 28)))
		Props.sign_board(root, Vector3(29.78, 2.0, 24), -90.0, UiKit.ICON_MAP_DANGER, Color(0.85, 0.7, 0.15), Color(0.1, 0.1, 0.1), 0.8)

## Visual-only set dressing away from movement lanes (no colliders, so it never changes gameplay space).
func _dressing() -> void:
	if not V:
		return
	for p in [Vector3(-16.5, 0, -22.5), Vector3(16.5, 0, 0.5), Vector3(-16.4, 0, 0.6)]:
		Props.pallet(root, p, 1)
	for p in [Vector3(17.2, 0.0, -9.5), Vector3(17.3, 0.0, -13.5), Vector3(-17.3, 0.0, -9.0)]:
		Props.barrel(_node(p), Color(0.27, 0.34, 0.22))
	for p in [Vector3(-23.0, 0.0, 41.0), Vector3(23.0, 0.0, 8.0), Vector3(-45.0, 0.0, 3.0), Vector3(48.0, 0.0, 12.0)]:
		Props.tire_stack(_node(p), 3)
	for p in [Vector3(-22.6, 0.0, 22.0), Vector3(22.8, 0.0, 22.0)]:
		Props.barrel(_node(p), Color(0.55, 0.2, 0.12))
		Props.barrel(_node(p + Vector3(0, 0, 0.65)), Color(0.2, 0.3, 0.45))
	Props.pallet(root, Vector3(22.3, 0, 33.0), 2)
	Props.pallet(root, Vector3(-22.3, 0, 36.0), 1)
	# perimeter fence lines inside the wall on the east side
	for z in [-30.0, 40.0]:
		Props.fence(_node(Vector3(60, 0, z), 90.0), 24.0)
	# Dominion presence: banners on the yard containers and perimeter
	Props.banner(root, Vector3(-14, 2.0, 12.88), 180.0)
	Props.banner(root, Vector3(0, 2.2, 2.25), 0.0)
	Props.decal(root, "FX/SPR_FX_MilitaryCombat_BloodSplats_02.png", Vector3(3, 0.0, 22), Vector3(2.0, 0.6, 2.0), Color(0.08, 0.07, 0.05, 0.6))
	Props.decal(root, "FX/SPR_FX_MilitaryCombat_BloodSplats_01.png", Vector3(-8, 0.0, 34), Vector3(2.5, 0.6, 2.5), Color(0.08, 0.07, 0.05, 0.5))
	Props.decal(root, UiKit.BADGE_DOMINION, Vector3(15, 1.4, 12.94), Vector3(1.8, 0.5, 1.8), Color(0.75, 0.1, 0.08, 0.9), Vector3(90, 0, 0))
	# distant ridge silhouettes beyond the walls for depth
	for i in 14:
		var a := TAU * i / 14.0
		var r := rng.randf_range(115, 135)
		var hgt := rng.randf_range(10, 26)
		Geo.part(root, Vector3(rng.randf_range(30, 50), hgt, 20), Vector3(cos(a) * r, hgt * 0.4, sin(a) * r), Mat.ground(Color(0.5, 0.42, 0.34)), Vector3(0, rad_to_deg(-a) + 90, rng.randf_range(-8, 8)), 2.5)

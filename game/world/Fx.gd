class_name Fx
extends Node3D
## Client-only visual effects: tracers, impacts, throwables, smoke, flash detonation, extraction helicopter.

var _throwables := {}   # id -> {node, vel}
var _heli: Node3D
var _heli_t := 0.0
var _heli_target := Vector3.ZERO

func tracer(from: Vector3, to: Vector3) -> void:
	var len := from.distance_to(to)
	if len < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.015, 0.015, min(len, 6.0))
	mi.mesh = bm
	mi.material_override = Geo.mat(Color(1.0, 0.85, 0.5), 1.0, 0.0, Color(1.0, 0.75, 0.35))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.look_at_from_position(from, to, Vector3.UP if abs((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := create_tween()
	var dur: float = clampf(len / 400.0, 0.03, 0.25)
	tw.tween_property(mi, "global_position", to, dur).from(from + (to - from).normalized() * min(len, 6.0) * 0.5)
	tw.tween_callback(mi.queue_free)

func impact(pos: Vector3, normal: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 10
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.025
	m.height = 0.05
	m.radial_segments = 4
	m.rings = 2
	p.mesh = m
	p.material_override = Geo.mat(Color(0.55, 0.5, 0.42))
	add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	Sfx.play_3d("impact", pos, -12.0)

func throwable(id: int, kind: String, pos: Vector3, vel: Vector3) -> void:
	var n := Geo.cyl(0.04, 0.12, Color(0.3, 0.35, 0.3) if kind == "smoke" else Color(0.2, 0.2, 0.25), Vector3.ZERO, self)
	n.global_position = pos
	_throwables[id] = {"node": n, "vel": vel}

func detonate(id: int, kind: String, pos: Vector3) -> void:
	if _throwables.has(id):
		_throwables[id]["node"].queue_free()
		_throwables.erase(id)
	if kind == "flash":
		var l := OmniLight3D.new()
		l.light_energy = 16.0
		l.omni_range = 14.0
		add_child(l)
		l.global_position = pos + Vector3.UP * 0.3
		var tw := create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.4)
		tw.tween_callback(l.queue_free)
		Sfx.play_3d("bang", pos, 2.0)
	else:
		Sfx.play_3d("smoke", pos, -2.0)

func smoke(pos: Vector3, radius: float, duration: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 100) ^ int(pos.z * 100)
	for i in range(14):
		var s := Geo.sphere(radius * rng.randf_range(0.35, 0.6), Color(0.78, 0.78, 0.76, 0.9), Vector3(rng.randf_range(-1, 1) * radius * 0.6, rng.randf_range(-0.8, 1.4), rng.randf_range(-1, 1) * radius * 0.6), root)
		s.material_override = Geo.mat(Color(0.78, 0.78, 0.76, 0.92), 1.0)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.scale = Vector3.ONE * 0.1
		create_tween().tween_property(s, "scale", Vector3.ONE, 1.5)
	var tw := create_tween()
	tw.tween_interval(max(duration - 2.0, 0.1))
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 2.0)
	tw.tween_callback(root.queue_free)

func helicopter(at: Vector3) -> void:
	if _heli:
		return
	_heli = Node3D.new()
	add_child(_heli)
	var body := Geo.box(Vector3(2.6, 2.2, 7.0), Color(0.22, 0.25, 0.2), Vector3(0, 1.4, 0), _heli)
	Geo.box(Vector3(0.6, 0.6, 5.0), Color(0.22, 0.25, 0.2), Vector3(0, 1.8, 5.5), _heli)
	Geo.box(Vector3(2.2, 1.0, 1.2), Color(0.1, 0.15, 0.2), Vector3(0, 1.8, -3.3), body)
	var rotor := Geo.box(Vector3(14, 0.06, 0.4), Color(0.1, 0.1, 0.1), Vector3(0, 2.7, 0), _heli)
	rotor.name = "Rotor"
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.2, 0.2)
	light.light_energy = 2.0
	light.position = Vector3(0, 0.2, 0)
	_heli.add_child(light)
	_heli_target = at + Vector3(11, 0.3, -4)
	_heli.global_position = at + Vector3(10, 60, -120)
	Sfx.loop_3d("heli", _heli)

func _process(dt: float) -> void:
	for id in _throwables:
		var t: Dictionary = _throwables[id]
		var n: Node3D = t["node"]
		var v: Vector3 = t["vel"]
		v.y -= 9.8 * dt
		var next := n.global_position + v * dt
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(n.global_position, next, 1))
		if hit:
			next = hit["position"] + hit["normal"] * 0.05
			v = Vector3.ZERO
		n.global_position = next
		t["vel"] = v
	if _heli:
		_heli.get_node("Rotor").rotate_y(dt * 25.0)
		_heli.global_position = _heli.global_position.lerp(_heli_target, min(1.0, dt * 0.35))

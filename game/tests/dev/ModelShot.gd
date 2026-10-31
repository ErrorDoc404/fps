extends SceneTree
## Dev utility: renders imported models side by side with a given atlas texture and saves a PNG.
## Usage (needs a display/Xvfb): --script res://tests/ModelShot.gd -- out.png texture.png cam_dist model1.fbx[+part.fbx...] model2...
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	var tex: Texture2D = load(a[1])
	var dist := float(a[2])
	var root := Node3D.new()
	get_root().add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.8
	var x := 0.0
	for i in range(3, a.size()):
		var holder := Node3D.new()
		holder.position.x = x
		root.add_child(holder)
		for p in a[i].split("+"):
			var n: Node = (load(p) as PackedScene).instantiate()
			holder.add_child(n)
			_mat(n, mat)
		x += dist * 0.6
	var cam := Camera3D.new()
	root.add_child(cam)
	if OS.get_environment("SIDE") != "":
		# orthographic side view along -X: Z to the right, Y up; 1 unit = grid line
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = dist
		cam.position = Vector3(5, float(OS.get_environment("SIDE_Y")), float(OS.get_environment("SIDE_Z")))
		cam.rotation_degrees = Vector3(0, 90, 0)
		for gz in range(-10, 11):
			var l := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.001, 2, 0.002) if true else Vector3.ZERO
			l.mesh = bm
			l.position = Vector3(-1, 0, gz * 0.1)
			root.add_child(l)
			var h := MeshInstance3D.new()
			var hm := BoxMesh.new()
			hm.size = Vector3(0.001, 0.002, 2)
			h.mesh = hm
			h.position = Vector3(-1, gz * 0.1, 0)
			root.add_child(h)
	else:
		cam.position = Vector3(x * 0.5 - dist * 0.3, dist * 0.35, dist)
		cam.look_at(Vector3(x * 0.5 - dist * 0.3, dist * 0.12, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.45)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()
func _mat(n: Node, m: Material) -> void:
	if n is MeshInstance3D:
		n.material_override = m
	for c in n.get_children():
		_mat(c, m)

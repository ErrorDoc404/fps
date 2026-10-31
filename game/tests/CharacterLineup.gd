extends Node3D
## Visual check: every character kind in several poses + all weapons. Run:
##   godot --path game res://tests/CharacterLineup.tscn -- --shot=<out.png>
func _ready() -> void:
	var kinds := ["assault", "medic", "recon", "support", "infantry", "heavy", "spotter", "command"]
	var weps := ["ar_a", "ar_b", "smg_a", "dmr_a", "pistol_a", "ar_a", "dmr_a", "pistol_a"]
	var models := []
	for i in kinds.size():
		var m := SoldierModel.new()
		add_child(m)
		m.build_kind(kinds[i], weps[i])
		m.position = Vector3(-6.3 + i * 1.8, 0, 0)
		m.rotation_degrees.y = float(Args.get_value("yaw", "200"))
		models.append(m)
	var extra := [[1, 0.0, 0.0, "alive"], [0, 0.0, 4.0, "alive"], [2, 0.0, 0.0, "alive"], [0, 0.0, 0.0, "downed"]]
	for j in extra.size():
		var m := SoldierModel.new()
		add_child(m)
		m.build_kind("assault", "ar_b")
		m.position = Vector3(-4.5 + j * 3.0, 0, -4.0)
		m.rotation_degrees.y = 240
		m.set_meta("p", extra[j])
		models.append(m)
	var cam := Camera3D.new()
	var focus := float(Args.get_value("focus", "-99"))
	add_child(cam)
	if Args.has("side"):
		cam.position = Vector3(focus + 3.0, 1.3, 0)
		cam.look_at(Vector3(focus, 1.1, 0))
	elif focus > -90.0:
		cam.position = Vector3(focus, 1.5, 2.2)
		cam.look_at(Vector3(focus, 1.25, 0))
	else:
		cam.position = Vector3(0, 2.4, 7.5)
		cam.look_at(Vector3(0, 0.6, -1.5))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	add_child(ground)
	for f in 30:
		for m in models:
			var p: Array = m.get_meta("p", [0, 0.0, 0.0, "alive"])
			m.pose(0.05, p[0], p[1], p[2], p[3])
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Args.get_value("shot", "/tmp/lineup.png"))
	get_tree().quit()

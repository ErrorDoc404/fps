extends Node3D
## Visual check of the first-person rig (weapon + IK arms). Run:
##   godot --path game res://tests/ViewModelShot.tscn -- --shot=out.png --weapon=ar_a --ads=0|1 --class=assault
class StubController extends Node:
	var yaw := 0.0
	var pitch := 0.0
func _ready() -> void:
	var w := Node3D.new()
	add_child(w)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	g.mesh = pm
	g.material_override = Mat.tiled("PW/Textures/Dirt_Dry_01.png", "", 0.25)
	w.add_child(g)
	Poly.place(w, "PW/FBX/SM_Prop_Shipping_Container_01.fbx", Props.A, Vector3(1.5, 0, -9), 80.0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.65, 0.72)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.65, 0.62, 0.58)
	add_child(env)
	var p := Player.new()
	p.class_id = Args.get_value("class", "assault")
	add_child(p)
	var ctrl := StubController.new()
	ctrl.name = "Controller"
	p.add_child(ctrl)
	var rig := preload("res://player/FirstPersonRig.gd").new()
	rig.player = p
	rig.controller = ctrl
	p.add_child(rig)
	p.motor["ads"] = Args.get_value("ads", "0") == "1"
	var wid := Args.get_value("weapon", "ar_a")
	p.set_inventory_mirror({"weapons": [{"id": wid, "mag": 30, "reserve": 90, "mode_idx": 0}], "active": 0, "equipment": {}})
	for i in 60:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(Args.get_value("shot", "/tmp/vm.png"))
	get_tree().quit()

extends SceneTree
## Dev utility: prints the node tree / skeleton of an imported model. Usage: --script res://tests/InspectScene.gd -- res://path.fbx
func _initialize() -> void:
	var path := OS.get_cmdline_user_args()[0]
	var ps: PackedScene = load(path)
	var n := ps.instantiate()
	_dump(n, 0)
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is Skeleton3D:
		var names := []
		for i in n.get_bone_count():
			names.append("%d:%s<%d" % [i, n.get_bone_name(i), n.get_bone_parent(i)])
		extra = " bones=" + str(names)
	if n is MeshInstance3D:
		var mats := []
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			mats.append(m.resource_name if m else "null")
			if m is StandardMaterial3D:
				mats.append(str(m.albedo_texture.resource_path if m.albedo_texture else "notex"))
		extra = " aabb=%s mats=%s" % [n.get_aabb(), mats]
	print("  ".repeat(d), n.name, " (", n.get_class(), ")", extra, " pos=", n.position if n is Node3D else "")
	for c in n.get_children():
		_dump(c, d + 1)

extends SceneTree
## Dev utility: prints global rest positions + scale of key bones of a rigged model.
func _initialize() -> void:
	var n: Node = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
	print("skeleton xform: ", sk.transform, " parent ", sk.get_parent().name, " ", (sk.get_parent() as Node3D).transform)
	for b in ["Pelvis", "spine_01", "spine_03", "neck_01", "head", "eyes", "clavicle_l", "UpperArm_L", "lowerarm_l", "Hand_L", "indexFinger_01_l", "UpperArm_R", "lowerarm_r", "Hand_R", "Thigh_L", "calf_l", "Foot_L", "ball_l", "Thigh_R", "Foot_R"]:
		var i := sk.find_bone(b)
		var g := sk.get_bone_global_rest(i)
		print(b, " ", g.origin, " xaxis=", g.basis.x.normalized(), " yaxis=", g.basis.y.normalized(), " scale=", g.basis.get_scale())
	quit()

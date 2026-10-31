extends SceneTree
## Dev utility: measures muzzle / sight line / grip / handguard points of a weapon body mesh (Synty space, +Z = muzzle).
func _initialize() -> void:
	for path in OS.get_cmdline_user_args():
		var n: Node = (load(path) as PackedScene).instantiate()
		var verts := PackedVector3Array()
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var arr: Array = mi.mesh.surface_get_arrays(0)
			for v in arr[Mesh.ARRAY_VERTEX]:
				verts.append(mi.transform * v)
		var maxz := -INF
		var minz := INF
		for v in verts:
			maxz = maxf(maxz, v.z); minz = minf(minz, v.z)
		var my := 0.0; var mc := 0
		var sight := -INF
		var gy := 0.0; var gz := 0.0; var gc := 0
		var hy_top := -INF; var hy_bot := INF
		for v in verts:
			if v.z > maxz - 0.02: my += v.y; mc += 1
			if v.z > -0.12 and v.z < 0.12: sight = maxf(sight, v.y)
			if v.y < -0.05 and v.z > -0.15 and v.z < 0.06: gy += v.y; gz += v.z; gc += 1
			if v.z > 0.24 and v.z < 0.34: hy_top = maxf(hy_top, v.y); hy_bot = minf(hy_bot, v.y)
		print(path.get_file(), " len=%.3f..%.3f muzzle=(0,%.3f,%.3f) sight_y=%.3f grip=(0,%.3f,%.3f) handguard_y=%.3f..%.3f" % [minz, maxz, my / max(1, mc), maxz, sight, gy / max(1, gc), gz / max(1, gc), hy_bot, hy_top])
	quit()

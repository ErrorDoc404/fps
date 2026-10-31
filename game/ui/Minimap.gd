extends Control
## Rotating minimap drawn from the map footprints. Shows squad, revealed enemies, objectives and extraction.

var world: Node
const RANGE := 45.0   # metres shown from centre to edge

func _ready() -> void:
	custom_minimum_size = Vector2(230, 230)
	clip_contents = true
	var ring := UiKit.icon(UiKit.SPR_MAP_RING, 230, Color(UiKit.ACCENT, 0.7))
	add_child(UiKit.full_rect(ring))

func _process(_dt: float) -> void:
	queue_redraw()

func _to_map(p: Vector3, center: Vector3, yaw: float, r: float) -> Vector2:
	var d := Vector2(p.x - center.x, p.z - center.z).rotated(yaw)
	return size * 0.5 + d * (r / RANGE)

func _draw() -> void:
	if not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(world.local_player):
		return
	var lp: Player = world.local_player
	if lp == null:
		return
	var r := size.x * 0.5 - 6.0
	var c := size * 0.5
	draw_circle(c, r, Color(0.03, 0.05, 0.04, 0.78))
	var yaw := lp.rotation.y
	var center := lp.global_position
	for f in world.map_info.get("footprints", []):
		var pts := PackedVector2Array()
		var hx: float = f[2] * 0.5
		var hz: float = f[3] * 0.5
		for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
			var w: Vector2 = corner.rotated(-f[4]) + Vector2(f[0], f[1])
			pts.append(_to_map(Vector3(w.x, 0, w.y), center, yaw, r))
		var inside := false
		for p in pts:
			if p.distance_to(c) < r * 1.4:
				inside = true
		if inside:
			draw_colored_polygon(pts, Color(0.55, 0.6, 0.5, 0.45))
	var obj_tex := UiKit.tex(UiKit.ICON_MAP_OBJ)
	for mp in world.get_objective_markers():
		var m := _to_map(mp["pos"], center, yaw, r)
		var dv := m - c
		if dv.length() > r - 12.0:
			m = c + dv.normalized() * (r - 12.0)
		var t: Texture2D = UiKit.tex(UiKit.ICON_HELI) if mp["kind"] == "extract" else obj_tex
		draw_texture_rect(t, Rect2(m - Vector2(11, 11), Vector2(22, 22)), false, UiKit.ACCENT)
	var dot := UiKit.tex(UiKit.SPR_MAP_DOT)
	var now := Time.get_ticks_msec() / 1000.0
	for e in world.enemies.values():
		if e.is_dead() or (e.net_flags & 1) == 0:
			continue
		var m := _to_map(e.global_position, center, yaw, r)
		if m.distance_to(c) < r - 4.0:
			draw_texture_rect(dot, Rect2(m - Vector2(6, 6), Vector2(12, 12)), false, UiKit.BAD)
	for p in world.players.values():
		if p == lp:
			continue
		var m := _to_map(p.global_position, center, yaw, r)
		var dv := m - c
		if dv.length() > r - 8.0:
			m = c + dv.normalized() * (r - 8.0)
		var col: Color = UiKit.BAD if p.is_downed_net() else Color(0.4, 0.85, 1.0)
		if p.is_downed_net() and fmod(now, 0.8) < 0.4:
			col = Color.WHITE
		draw_texture_rect(dot, Rect2(m - Vector2(7, 7), Vector2(14, 14)), false, col)
	var arrow := UiKit.tex(UiKit.SPR_MAP_PLAYER)
	draw_texture_rect(arrow, Rect2(c - Vector2(10, 12), Vector2(20, 24)), false, UiKit.ACCENT)
	var n_dir := Vector2(0, -1).rotated(yaw)
	draw_string(UiKit.font(true), c + n_dir * (r - 12.0) + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.ACCENT)

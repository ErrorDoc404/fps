extends Control
## Horizontal compass strip with cardinal labels, tick sprites and the active objective bearing.

var world: Node
const FOV_DEG := 120.0

func _ready() -> void:
	custom_minimum_size = Vector2(560, 46)

func _process(_dt: float) -> void:
	queue_redraw()

func _x_for(bearing_deg: float, heading_deg: float) -> float:
	var d := wrapf(bearing_deg - heading_deg, -180.0, 180.0)
	return size.x * 0.5 + d / FOV_DEG * size.x

func _draw() -> void:
	var lp: Player = world.local_player
	if lp == null:
		return
	draw_rect(Rect2(Vector2(0, 6), Vector2(size.x, 26)), Color(0, 0, 0, 0.35))
	var heading := wrapf(-rad_to_deg(lp.rotation.y), 0.0, 360.0)  # 0 = north (-Z)
	var tick := UiKit.tex(UiKit.SPR_COMPASS_TICK)
	var f := UiKit.font(true)
	for b in range(0, 360, 15):
		var x := _x_for(b, heading)
		if x < 0 or x > size.x:
			continue
		var major := b % 45 == 0
		var h := 14.0 if major else 7.0
		draw_texture_rect(tick, Rect2(Vector2(x - 1.5, 8), Vector2(3, h)), false, Color(UiKit.TEXT, 0.9 if major else 0.5))
		if major:
			var names := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
			draw_string(f, Vector2(x - 20, 40), names[b], HORIZONTAL_ALIGNMENT_CENTER, 40, 14, UiKit.ACCENT if b == 0 else UiKit.TEXT)
	draw_string(f, Vector2(size.x * 0.5 - 20, 4), "%03d" % int(heading), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, UiKit.DIM)
	draw_rect(Rect2(Vector2(size.x * 0.5 - 1, 4), Vector2(2, 26)), UiKit.ACCENT)
	var obj := UiKit.tex(UiKit.SPR_OBJ_ACTIVE)
	for mp in world.get_objective_markers():
		var to: Vector3 = mp["pos"] - lp.global_position
		var bearing := wrapf(rad_to_deg(atan2(to.x, -to.z)), 0.0, 360.0)
		var x := clampf(_x_for(bearing, heading), 8.0, size.x - 8.0)
		var t: Texture2D = UiKit.tex(UiKit.ICON_HELI) if mp["kind"] == "extract" else obj
		draw_texture_rect(t, Rect2(Vector2(x - 9, 10), Vector2(18, 18)), false, UiKit.ACCENT)

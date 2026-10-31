extends Control
## Mission debrief: result, objectives, squad performance, XP / credits earned and level progress.

var app: Node
var r: Dictionary

func _init(a: Node, results: Dictionary) -> void:
	app = a
	r = results
	UiKit.full_rect(self)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.045)
	add_child(UiKit.full_rect(bg))
	var ok: bool = r.get("result", "") == "completed"
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.position = Vector2(-520, -330)
	root.custom_minimum_size = Vector2(1040, 0)
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.add_child(UiKit.icon(UiKit.ICON_TROPHY if ok else UiKit.ICON_DEAD, 64, UiKit.ACCENT if ok else UiKit.BAD))
	var tv := VBoxContainer.new()
	tv.add_child(UiKit.label("%s  %s" % [r.get("code", ""), r.get("mission_name", "")], 20, UiKit.DIM, true))
	tv.add_child(UiKit.label("MISSION COMPLETE" if ok else "MISSION FAILED", 48, UiKit.OK if ok else UiKit.BAD, true))
	if r.get("reason", "") != "":
		tv.add_child(UiKit.label(r["reason"], 16, UiKit.DIM))
	tv.add_child(UiKit.label("Duration %d:%02d" % [int(r.get("duration", 0)) / 60, int(r.get("duration", 0)) % 60], 14, UiKit.DIM))
	top.add_child(tv)
	root.add_child(top)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)
	var op := UiKit.panel(Vector2(420, 0))
	var ov := VBoxContainer.new()
	op.add_child(ov)
	ov.add_child(UiKit.header("Objectives"))
	for o in r.get("objectives", []):
		var row := HBoxContainer.new()
		row.add_child(UiKit.icon(UiKit.SPR_OBJ_INACTIVE if o["completed"] else UiKit.SPR_OBJ_ACTIVE, 16, UiKit.OK if o["completed"] else UiKit.BAD))
		row.add_child(UiKit.label("%s%s" % [o["name"], "" if o["primary"] else " (optional)"], 16, UiKit.TEXT if o["completed"] else UiKit.DIM))
		ov.add_child(row)
	cols.add_child(op)
	var sp := UiKit.panel(Vector2(600, 0))
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	sv.add_child(UiKit.header("Squad"))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 18)
	for h in ["OPERATOR", "CLASS", "KILLS", "DOWNS", "REVIVES", "STATUS", "XP"]:
		grid.add_child(UiKit.label(h, 13, UiKit.ACCENT, true))
	for s in r.get("squad", []):
		grid.add_child(UiKit.label(s["name"], 15))
		grid.add_child(UiKit.label(GameData.klass(s["class"]).get("name", ""), 15, UiKit.DIM))
		grid.add_child(UiKit.label(str(s["kills"]), 15))
		grid.add_child(UiKit.label(str(s["downs"]), 15))
		grid.add_child(UiKit.label(str(s["revives"]), 15))
		var status := "EXTRACTED" if s["extracted"] else ("KIA" if s["eliminated"] else "LEFT BEHIND")
		grid.add_child(UiKit.label(status, 15, UiKit.OK if s["extracted"] else UiKit.BAD))
		grid.add_child(UiKit.label("+%d" % s["xp"], 15, UiKit.ACCENT))
	sv.add_child(grid)
	cols.add_child(sp)
	var you: Dictionary = r.get("you", {})
	var prof: Dictionary = r.get("profile", Session.my_profile)
	var rw := UiKit.panel()
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 14)
	rw.add_child(rh)
	rh.add_child(UiKit.icon(UiKit.ICON_XP, 36, UiKit.ACCENT))
	rh.add_child(UiKit.label("+%d XP" % you.get("xp", 0), 26, UiKit.ACCENT, true))
	rh.add_child(UiKit.icon(UiKit.ICON_CREDITS, 34, UiKit.ACCENT))
	rh.add_child(UiKit.label("+%d CREDITS" % you.get("credits", 0), 26, UiKit.ACCENT, true))
	var lv := VBoxContainer.new()
	lv.add_child(UiKit.label("LEVEL %d %s  ·  %d XP total  ·  %d credits" % [prof.get("level", 1), prof.get("title", ""), prof.get("xp", 0), prof.get("credits", 0)], 16))
	var bar := UiKit.bar(UiKit.ACCENT, Vector2(420, 14))
	var lo := float(prof.get("prev_level_xp", 0))
	var hi := float(prof.get("next_level_xp", -1))
	bar.value = 100.0 if hi <= 0 else (float(prof.get("xp", 0)) - lo) / max(1.0, hi - lo) * 100.0
	lv.add_child(bar)
	var unlocks := []
	for wid in GameData.weapons:
		if int(GameData.weapon(wid)["unlock_level"]) == int(prof.get("level", 1)) and int(prof.get("level", 1)) > 1:
			unlocks.append(GameData.weapon(wid)["name"])
	if not unlocks.is_empty():
		lv.add_child(UiKit.label("UNLOCKED: " + ", ".join(unlocks), 16, UiKit.OK, true))
	rh.add_child(lv)
	root.add_child(rw)
	root.add_child(UiKit.button("RETURN TO HQ", func(): app.show_lobby(), 300))

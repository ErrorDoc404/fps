class_name PlayerInventory
extends RefCounted
## Server-authoritative weapons, ammunition and equipment for one operator.
## The owning client receives a mirror via `to_dict()` whenever it changes.

var weapons: Array = []        # [{id, mag, reserve, mode_idx}]
var active := 0
var equipment := {}            # id -> count
var cooldowns := {}            # id -> seconds remaining
var reload_timer := 0.0
var switch_timer := 0.0
var next_fire_time := 0.0
var use_timer := 0.0           # e.g. medkit application
var use_item := ""
var dirty := true

func setup(class_id: String, primary: String, secondary: String) -> void:
	var c := GameData.klass(class_id)
	var mult: float = c["modifiers"].get("reserve_mult", 1.0)
	weapons.clear()
	for id in [primary, secondary]:
		var w := GameData.weapon(id)
		weapons.append({"id": id, "mag": int(w["mag"]), "reserve": int(round(float(w["reserve"]) * mult)), "mode_idx": 0})
	equipment = c["equipment"].duplicate()
	active = 0
	dirty = true

func def() -> Dictionary:
	return GameData.weapon(weapons[active]["id"])

func current() -> Dictionary:
	return weapons[active]

func fire_mode() -> String:
	return def()["fire_modes"][current()["mode_idx"]]

func total_weight() -> float:
	var w := 0.0
	for e in weapons:
		w += float(GameData.weapon(e["id"]).get("weight", 0.0))
	return w

func is_reloading() -> bool:
	return reload_timer > 0.0

func can_fire(now: float) -> bool:
	return current()["mag"] > 0 and reload_timer <= 0.0 and switch_timer <= 0.0 and use_timer <= 0.0 and now + 0.02 >= next_fire_time

## Consumes one round. Caller must have checked can_fire().
func consume_round(now: float) -> void:
	current()["mag"] -= 1
	next_fire_time = now + 60.0 / float(def()["rpm"])
	dirty = true

func start_reload() -> bool:
	var c := current()
	var d := def()
	if reload_timer > 0.0 or switch_timer > 0.0 or c["reserve"] <= 0 or c["mag"] >= int(d["mag"]):
		return false
	reload_timer = d["reload_empty_time"] if c["mag"] == 0 else d["reload_time"]
	dirty = true
	return true

func cancel_reload() -> void:
	if reload_timer > 0.0:
		reload_timer = 0.0
		dirty = true

func switch_to(idx: int) -> bool:
	if idx == active or idx < 0 or idx >= weapons.size() or use_timer > 0.0:
		return false
	cancel_reload()
	active = idx
	switch_timer = 0.45
	dirty = true
	return true

func cycle_fire_mode() -> void:
	var modes: Array = def()["fire_modes"]
	current()["mode_idx"] = (current()["mode_idx"] + 1) % modes.size()
	dirty = true

func add_magazines(n: int) -> void:
	for e in weapons:
		var d := GameData.weapon(e["id"])
		e["reserve"] = min(int(e["reserve"]) + int(d["mag"]) * n, int(d["reserve"]) * 2)
	dirty = true

func tick(dt: float) -> void:
	if switch_timer > 0.0:
		switch_timer -= dt
	for k in cooldowns.keys():
		cooldowns[k] -= dt
		if cooldowns[k] <= 0.0:
			cooldowns.erase(k)
			dirty = true
	if reload_timer > 0.0:
		reload_timer -= dt
		if reload_timer <= 0.0:
			reload_timer = 0.0
			var c := current()
			var need: int = int(def()["mag"]) - int(c["mag"])
			var take: int = min(need, int(c["reserve"]))
			c["mag"] += take
			c["reserve"] -= take
			dirty = true

func to_dict() -> Dictionary:
	return {"weapons": weapons.duplicate(true), "active": active, "equipment": equipment.duplicate(),
		"cooldowns": cooldowns.duplicate(), "reloading": reload_timer > 0.0, "reload_left": reload_timer,
		"fire_mode": fire_mode(), "use_item": use_item, "use_left": use_timer}

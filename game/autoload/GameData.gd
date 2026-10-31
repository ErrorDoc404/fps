extends Node
## Loads all data-driven definitions from res://data/*.json and exposes typed lookups.
## Gameplay code must read balance values from here, never hardcode them.

var weapons: Dictionary = {}
var classes: Dictionary = {}
var equipment: Dictionary = {}
var enemies: Dictionary = {}
var missions: Dictionary = {}
var progression: Dictionary = {}
var player_rules: Dictionary = {}

func _ready() -> void:
	weapons = _index(_load("weapons"))
	classes = _index(_load("classes"))
	equipment = _index(_load("equipment"))
	enemies = _index(_load("enemies"))
	missions = _index(_load("missions"))
	progression = _load("progression")
	player_rules = _load("player")
	Log.info("data", "definitions loaded", {"weapons": weapons.size(), "classes": classes.size(),
		"equipment": equipment.size(), "enemies": enemies.size(), "missions": missions.size()})

func _load(name: String) -> Variant:
	var path := "res://data/%s.json" % name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		Log.error("data", "missing data file", {"path": path})
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		Log.error("data", "invalid JSON", {"path": path})
		return {}
	return parsed

func _index(list: Variant) -> Dictionary:
	var out := {}
	if list is Array:
		for entry in list:
			out[entry["id"]] = entry
	return out

func weapon(id: String) -> Dictionary: return weapons.get(id, {})
func klass(id: String) -> Dictionary: return classes.get(id, {})
func equip(id: String) -> Dictionary: return equipment.get(id, {})
func enemy(id: String) -> Dictionary: return enemies.get(id, {})
func mission(id: String) -> Dictionary: return missions.get(id, {})

## Level reached for a given XP total, using the progression curve.
func level_for_xp(xp: int) -> int:
	var lvl := 1
	for threshold in progression.get("level_xp", []):
		if xp >= int(threshold):
			lvl += 1
		else:
			break
	return lvl

func xp_for_level(level: int) -> int:
	var arr: Array = progression.get("level_xp", [])
	if level - 1 < arr.size():
		return int(arr[level - 1])
	return -1

## Weapons and equipment unlocked at a given level (plus explicit purchases).
func is_unlocked(item_id: String, level: int, purchased: Array) -> bool:
	if purchased.has(item_id):
		return true
	var def := weapon(item_id)
	if def.is_empty():
		def = equip(item_id)
	return not def.is_empty() and level >= int(def.get("unlock_level", 1))

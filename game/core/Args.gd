class_name Args
## Command-line argument helper. Accepts `--key=value` and `--flag` after `--` (user args) or anywhere.

static var _cache: Dictionary = {}
static var _parsed := false

static func _parse() -> void:
	if _parsed:
		return
	_parsed = true
	var all := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in all:
		if not a.begins_with("--"):
			continue
		var s := a.substr(2)
		var eq := s.find("=")
		if eq >= 0:
			_cache[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			_cache[s] = "true"

static func has(key: String) -> bool:
	_parse()
	return _cache.has(key)

static func get_value(key: String, default: String = "") -> String:
	_parse()
	return _cache.get(key, default)

static func get_int(key: String, default: int) -> int:
	_parse()
	return int(_cache[key]) if _cache.has(key) else default

static func is_server() -> bool:
	return has("server") or DisplayServer.get_name() == "headless" and has("dedicated")

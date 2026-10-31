class_name ProfileStore
extends RefCounted
## Persistence + progression authority. Runs only on the dedicated server (trusted side).
## One JSON document per profile. Rewards are applied idempotently per mission session id.

var _dir: String
var realm_id := ""   # persistent identity of this server's profile database

func _init(data_dir: String) -> void:
	_dir = data_dir.path_join("profiles")
	DirAccess.make_dir_recursive_absolute(_dir)
	var realm_path := data_dir.path_join("realm.id")
	if FileAccess.file_exists(realm_path):
		realm_id = FileAccess.get_file_as_string(realm_path).strip_edges()
	if realm_id == "":
		realm_id = Crypto.new().generate_random_bytes(8).hex_encode()
		FileAccess.open(realm_path, FileAccess.WRITE).store_string(realm_id)
	Log.info("persist", "profile store ready", {"dir": ProjectSettings.globalize_path(_dir)})

static func valid_id(profile_id: String) -> bool:
	if profile_id.length() != 32:
		return false
	for c in profile_id:
		if not "0123456789abcdef".contains(c):
			return false
	return true

func _path(profile_id: String) -> String:
	return _dir.path_join(profile_id + ".json")

func exists(profile_id: String) -> bool:
	return FileAccess.file_exists(_path(profile_id))

func load_profile(profile_id: String) -> Dictionary:
	var f := FileAccess.open(_path(profile_id), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func save(profile: Dictionary) -> void:
	var tmp := _path(profile["id"]) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Log.error("persist", "cannot write profile", {"id": profile["id"]})
		return
	f.store_string(JSON.stringify(profile, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, _path(profile["id"]))  # atomic replace

## Returns {"ok": bool, "profile": Dictionary, "new_secret": String, "reason": String}.
## Trust-on-first-use: the first hello for a profile id creates it and issues a secret the client must present afterwards.
func authenticate(profile_id: String, secret: String, display_name: String) -> Dictionary:
	if not valid_id(profile_id):
		return {"ok": false, "reason": "invalid profile id"}
	if not exists(profile_id):
		var new_secret := Crypto.new().generate_random_bytes(24).hex_encode()
		var p := {
			"id": profile_id, "name": display_name, "secret_hash": new_secret.sha256_text(),
			"xp": 0, "credits": 0, "level": 1, "purchased": [], "loadouts": {},
			"campaign": {"completed": []}, "history": [], "claimed_sessions": [],
			"created": Time.get_datetime_string_from_system(true),
		}
		save(p)
		Log.info("persist", "profile created", {"id": profile_id})
		return {"ok": true, "profile": p, "new_secret": new_secret}
	var prof := load_profile(profile_id)
	if prof.is_empty() or secret.sha256_text() != prof.get("secret_hash", ""):
		return {"ok": false, "reason": "authentication failed"}
	if display_name != "" and display_name != prof["name"]:
		prof["name"] = display_name
		save(prof)
	return {"ok": true, "profile": prof, "new_secret": ""}

## Applies validated rewards once per (profile, session). Returns the updated profile, or {} if already claimed.
func grant_rewards(profile_id: String, session_id: String, mission_id: String, result: String, xp: int, credits: int) -> Dictionary:
	var prof := load_profile(profile_id)
	if prof.is_empty():
		return {}
	var claimed: Array = prof.get("claimed_sessions", [])
	if claimed.has(session_id):
		Log.warn("persist", "duplicate reward claim rejected", {"id": profile_id, "session": session_id})
		return {}
	claimed.append(session_id)
	if claimed.size() > 200:
		claimed = claimed.slice(claimed.size() - 200)
	prof["claimed_sessions"] = claimed
	var old_level := int(prof["level"])
	prof["xp"] = int(prof["xp"]) + max(xp, 0)
	prof["credits"] = int(prof["credits"]) + max(credits, 0)
	prof["level"] = GameData.level_for_xp(int(prof["xp"]))
	if result == "completed" and not prof["campaign"]["completed"].has(mission_id):
		prof["campaign"]["completed"].append(mission_id)
	var hist: Array = prof.get("history", [])
	hist.append({"session": session_id, "mission": mission_id, "result": result, "xp": xp, "credits": credits,
		"time": Time.get_datetime_string_from_system(true)})
	prof["history"] = hist.slice(max(0, hist.size() - 50))
	save(prof)
	Log.info("persist", "rewards granted", {"id": profile_id, "xp": xp, "credits": credits, "level": prof["level"], "level_up": prof["level"] > old_level})
	return prof

## Public view sent to clients (never includes the secret hash).
static func public_view(p: Dictionary) -> Dictionary:
	var lvl := int(p.get("level", 1))
	return {"id": p.get("id", ""), "name": p.get("name", ""), "xp": p.get("xp", 0), "credits": p.get("credits", 0),
		"level": lvl, "next_level_xp": GameData.xp_for_level(lvl), "prev_level_xp": GameData.xp_for_level(lvl - 1) if lvl > 1 else 0,
		"title": GameData.progression.get("titles", {}).get(str(lvl), ""), "purchased": p.get("purchased", []),
		"loadouts": p.get("loadouts", {}), "campaign": p.get("campaign", {}), "history": p.get("history", []).slice(-10)}

extends Node
## Headless co-op test bot. Runs the real client (App, World, LocalController, HUD) against a real dedicated
## server and drives input through the Input singleton. Bots coordinate through squad chat ("TEST:*").
## Args: --autotest --connect=host:port --role=leader|member|casualty|leaver --class=<id> --expect=<n> --report=<path>

var app: Node
var role := "member"
var checks := []
var _results := {}
var _world: Node
var _done := false
var _kills := 0
var _hits := 0
var _last_list: Array = []
var _list_seq := 0
var _notices: Array = []

func _ready() -> void:
	role = Args.get_value("role", "member")
	var addr := Args.get_value("connect", "127.0.0.1:7777").split(":")
	Session.welcomed.connect(_on_welcomed)
	Session.chat_received.connect(_on_chat)
	Session.mission_loading.connect(func(_m, _s, _r): _on_mission.call_deferred())
	Session.room_list_received.connect(func(l, _i): _last_list = l; _list_seq += 1)
	Session.notice.connect(func(t): _notices.append(t))
	Session.results_received.connect(_on_results)
	Session.kicked.connect(func(r): _fail_all("kicked: " + r))
	get_tree().create_timer(float(Args.get_value("timeout", "240"))).timeout.connect(func(): _fail_all("timeout"))
	Session.connect_to(addr[0], int(addr[1]))

func check(name: String, ok: bool, detail := "") -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	Log.info("test", ("PASS " if ok else "FAIL ") + name, {"role": role, "detail": detail})

func _fail_all(reason: String) -> void:
	if _done:
		return
	check("completed_without_" + reason.split(":")[0], false, reason)
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	var path := Args.get_value("report", "")
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"role": role, "checks": checks, "results": _results}, "\t"))
		f.close()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if checks.all(func(c): return c["ok"]) else 1)

func _list_rooms(filters: Dictionary) -> Array:
	var seq := _list_seq
	Session.request_rooms(filters)
	await _wait_until(func(): return _list_seq > seq, 3.0)
	return _last_list

func _find_room(room_name: String, secs: float) -> Dictionary:
	var t := 0.0
	while t < secs:
		for r in await _list_rooms({"search": room_name}):
			if r["name"] == room_name:
				return r
		await get_tree().create_timer(0.5).timeout
		t += 0.6
	return {}

func _on_welcomed(profile: Dictionary) -> void:
	check("authenticated", profile.has("level"), "level %s" % profile.get("level"))
	var room_name := Args.get_value("room", "Alpha")
	if role == "viewer":   # screenshots of the browsers (rendered runs)
		app.show_rooms()
		await get_tree().create_timer(3.0).timeout
		await shot("09_room_browser")
		Settings.set_v("favorites", [Args.get_value("connect", "")])
		app.show_menu()
		app.screen._show(preload("res://ui/ServerBrowser.gd").new(app))
		await get_tree().create_timer(3.0).timeout
		await shot("10_server_browser")
		_finish()
		return
	if role == "prober":
		await _probe(room_name)
		return
	var wrong := Args.get_value("probe-password-room", "")
	if wrong != "":
		var pr := await _find_room(wrong, 30.0)
		check("password_room_found", not pr.is_empty() and pr["locked"], wrong)
		_notices.clear()
		Session.request_join_room(pr.get("id", 0), "not-the-password")
		check("wrong_password_rejected", await _wait_until(func(): return _notices.any(func(n): return n.contains("Wrong password")), 3.0) and Session.room_id == 0)
	if role == "leader":
		Session.request_create_room(room_name, "", 4, "op01")
	else:
		var r := await _find_room(room_name, 30.0)
		check("room_listed", not r.is_empty(), room_name)
		if r.is_empty():
			_finish()
			return
		Session.request_join_room(r["id"], "")
	check("joined_room", await _wait_until(func(): return Session.room_id != 0, 10.0), room_name)
	await get_tree().create_timer(0.3).timeout
	Session.request_class(Args.get_value("class", "assault"))
	await get_tree().create_timer(0.3).timeout
	Session.request_set_ready(true)
	if role == "leader":
		_leader_lobby()

func _leader_lobby() -> void:
	var expect := Args.get_int("expect", 1)
	var t := 0.0
	while t < 60.0:
		var ms: Dictionary = Session.lobby.get("members", {})
		var ready := ms.size() >= expect and ms.values().all(func(m): return m["ready"])
		if ready:
			break
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	check("lobby_full_and_ready", Session.lobby.get("members", {}).size() >= expect, "%d members" % Session.lobby.get("members", {}).size())
	await get_tree().create_timer(float(Args.get_value("deploy-delay", "0"))).timeout
	check("is_leader", Session.is_leader())
	await shot("01_lobby")
	Session.request_deploy()

func _on_chat(from: String, text: String) -> void:
	if not text.begins_with("TEST:") or _world == null:
		return
	var lp: Player = _world.local_player
	match text:
		"TEST:down":
			if role == "casualty":
				_world.rpc_id(1, "c_test", "damage_self", 1000.0)
		"TEST:extract":
			if lp and role != "leaver":
				var off := Vector3(randf_range(-2, 2), 0.2, randf_range(-2, 2))
				_world.rpc_id(1, "c_test", "teleport", _world.map_info["extraction"] + off)

func _on_mission() -> void:
	_world = app.world
	var t := 0.0
	while (_world == null or _world.local_player == null) and t < 15.0:
		await get_tree().create_timer(0.2).timeout
		_world = app.world
		t += 0.2
	check("local_player_spawned", _world != null and _world.local_player != null)
	if _world == null or _world.local_player == null:
		_finish()
		return
	if Args.has("invulnerable"):
		_world.rpc_id(1, "c_test", "invulnerable", true)
	if role == "leaver":
		await get_tree().create_timer(4.0).timeout
		check("leaver_disconnecting", true)
		Net.leave()
		_finish()
		return
	if role == "leader":
		await _leader_mission()

## Saves a viewport screenshot when --screenshots=<dir> is given (requires a rendering display, e.g. Xvfb).
func shot(name: String) -> void:
	var dir := Args.get_value("screenshots", "")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	Log.info("test", "screenshot", {"name": name})

func _press(action: String, secs: float) -> void:
	if action in ["crouch", "prone", "reload", "weapon_primary", "weapon_secondary", "medkit", "equip_1", "equip_2"]:
		_tap(action)  # discrete actions are handled from input events
		await get_tree().create_timer(secs).timeout
		return
	Input.action_press(action)
	await get_tree().create_timer(secs).timeout
	Input.action_release(action)

func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)

func _ctrl() -> Node:
	return _world.local_player.get_node("Controller")

func _look_at(target: Vector3) -> void:
	var lp: Player = _world.local_player
	var eye := lp.global_position + Vector3.UP * PlayerMotor.eye_height(lp.motor)
	var to := target - eye
	_ctrl().yaw = atan2(-to.x, -to.z)
	_ctrl().pitch = atan2(to.y, Vector2(to.x, to.z).length())

func _teleport(pos: Vector3) -> void:
	_world.rpc_id(1, "c_test", "teleport", pos)
	await get_tree().create_timer(0.6).timeout
	Log.info("test", "teleported", {"want": str(pos), "local": str(_world.local_player.global_position), "server": str(_ctrl().last_server_pos)})

func _wait_until(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return cond.call()

func _leader_mission() -> void:
	var w := _world
	var lp: Player = w.local_player
	var expect := Args.get_int("expect", 1)
	check("all_players_synced", await _wait_until(func(): return w.players.size() >= expect, 8.0), "%d players" % w.players.size())
	check("room_world_isolated_enemies", w.enemies.size() == 10, "%d enemies (10 per mission instance)" % w.enemies.size())
	check("objectives_synced", not w.objective_state.is_empty())
	await _wait_until(func(): return not lp.inv_mirror.is_empty(), 5.0)
	check("inventory_received", not lp.inv_mirror.is_empty())
	if Args.has("down-self"):
		w.rpc_id(1, "c_test", "damage_self", 1000.0)
		return
	if Args.has("fail-fast"):
		w.rpc_id(1, "c_test", "fail_mission", 0)
		return
	await get_tree().create_timer(1.5).timeout
	await shot("02_spawn")
	for p in w.players.values():   # close-up of a squadmate (third-person operator model)
		if p != lp and Args.get_value("screenshots", "") != "":
			_ctrl().yaw = atan2(-(p.global_position.x - lp.global_position.x), -(p.global_position.z - lp.global_position.z))
			_ctrl().pitch = -0.05
			await get_tree().create_timer(0.5).timeout
			await shot("02b_squadmate")
			break
	# --- movement (prediction vs authoritative position)
	_ctrl().yaw = PI  # face south (+Z), open ground behind spawn
	await get_tree().create_timer(0.3).timeout
	var p0 := lp.global_position
	var t0 := Time.get_ticks_msec()
	Input.action_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	var p1 := lp.global_position
	var held := (Time.get_ticks_msec() - t0) / 1000.0
	Input.action_release("move_forward")
	var speed := Vector2(p1.x - p0.x, p1.z - p0.z).length() / held
	check("walk_speed_matches_data", speed > 2.4 and speed <= float(GameData.player_rules["speeds"]["walk"]) + 0.2, "%.2f m/s over %.2fs" % [speed, held])
	await get_tree().create_timer(1.0).timeout
	var drift: float = lp.global_position.distance_to(_ctrl().last_server_pos)
	check("prediction_matches_server", drift < 0.15, "drift %.3fm" % drift)
	# --- sprint + stamina (authoritative)
	_ctrl().yaw = 0.0
	Input.action_press("sprint")
	await _press("move_forward", 2.5)
	Input.action_release("sprint")
	await get_tree().create_timer(0.3).timeout
	check("sprint_consumes_stamina", float(lp.net["stamina"]) < 80.0, "stamina %.1f" % lp.net["stamina"])
	# --- crouch / prone replicated as server stance
	await _press("crouch", 0.1)
	await get_tree().create_timer(0.6).timeout
	check("crouch_replicated", int(lp.net["flags"]) & 3 == 1)
	await _press("prone", 0.1)
	await get_tree().create_timer(0.6).timeout
	check("prone_replicated", int(lp.net["flags"]) & 3 == 2)
	await _press("prone", 0.1)
	await get_tree().create_timer(1.0).timeout
	check("stand_replicated", int(lp.net["flags"]) & 3 == 0)
	# --- combat: engage the nearest enemy
	var target: Enemy = null
	var bd := INF
	for e in w.enemies.values():
		if not e.is_dead() and e.global_position.distance_to(Vector3(10, 0, 26)) < bd:
			bd = e.global_position.distance_to(Vector3(10, 0, 26))
			target = e
	var mag0: int = lp.inv_mirror["weapons"][0]["mag"]
	await _teleport(target.global_position + Vector3(0, 0.2, 7))
	if Args.get_value("screenshots", "") != "":
		_look_at(target.global_position + Vector3.UP * 1.0)
		await get_tree().create_timer(0.4).timeout
		await shot("03a_enemy")
	var killed := false
	for i in range(200):
		if target.is_dead():
			killed = true
			break
		_look_at(target.global_position + Vector3.UP * 1.25)
		Input.action_press("aim")
		if i % 3 == 0:
			Input.action_release("fire")  # re-pull the trigger so semi-automatic weapons keep firing
		else:
			Input.action_press("fire")
		await get_tree().create_timer(0.1).timeout
		if i == 6:
			await shot("03_combat_ads")
	Input.action_release("fire")
	await get_tree().create_timer(0.4).timeout
	Input.action_release("aim")
	var mag1: int = lp.inv_mirror["weapons"][0]["mag"]
	check("server_ammo_decrements", mag1 < mag0, "%d -> %d" % [mag0, mag1])
	check("enemy_killed_server_authoritative", killed and target.state == Enemy.State.DEAD, "enemy %d" % target.eid)
	# --- reload
	var res0: int = lp.inv_mirror["weapons"][0]["reserve"]
	await _press("reload", 0.1)
	await get_tree().create_timer(3.5).timeout
	var wv: Dictionary = lp.inv_mirror["weapons"][0]
	check("reload_refills_magazine", int(wv["mag"]) == int(GameData.weapon(wv["id"])["mag"]) and int(wv["reserve"]) < res0, "mag %d reserve %d" % [wv["mag"], wv["reserve"]])
	# --- weapon switch
	await _press("weapon_secondary", 0.1)
	await get_tree().create_timer(0.6).timeout
	check("weapon_switch_secondary", int(lp.inv_mirror["active"]) == 1)
	await _press("weapon_primary", 0.1)
	await get_tree().create_timer(0.6).timeout
	check("weapon_switch_primary", int(lp.inv_mirror["active"]) == 0)
	# --- clear hostiles for the cooperative flow (prevents random squad wipes during the scripted test)
	w.rpc_id(1, "c_test", "kill_all_enemies", 0)
	await get_tree().create_timer(0.8).timeout
	check("all_enemies_dead_replicated", w.enemies.values().all(func(e): return e.is_dead()))
	# --- downed + revive
	var casualty: Player = null
	for p in w.players.values():
		if p != lp and p.display_name.begins_with("Casualty"):
			casualty = p
	if casualty:
		Session.send_chat("TEST:down")
		check("teammate_downed_replicated", await _wait_until(func(): return casualty.is_downed_net(), 4.0))
		await _teleport(casualty.global_position + Vector3(1.0, 0.3, 0))
		_look_at(casualty.global_position + Vector3.UP * 0.4)
		await shot("04_teammate_downed")
		Input.action_press("interact")
		var revived: bool = await _wait_until(func(): return casualty.is_alive_net(), 12.0)
		Input.action_release("interact")
		check("teammate_revived", revived, "hp %.0f" % casualty.net["hp"])
	# --- objectives
	await _teleport(Vector3(0, 0.2, -6))
	check("objective_infiltrate", await _wait_until(func(): return _status("obj_infiltrate") == "completed", 3.0))
	if Args.get_value("screenshots", "") != "":
		_ctrl().yaw = 1.2   # look west across the rack rows
		_ctrl().pitch = 0.05
		await get_tree().create_timer(0.6).timeout
		await shot("05a_warehouse")
	await _teleport(Vector3(15, 0.2, -21.0))
	_look_at(Vector3(15, 1.0, -22.5))
	await get_tree().create_timer(0.3).timeout
	var it: Dictionary = w.find_interaction(lp, false)
	check("interaction_prompt_visible", not it.is_empty(), str(it.get("label", "")))
	Input.action_press("interact")
	await get_tree().create_timer(1.5).timeout
	await shot("05_interact")
	var intel: bool = await _wait_until(func(): return _status("obj_intel") == "completed", 8.0)
	Input.action_release("interact")
	check("objective_intel", intel)
	check("extraction_open", await _wait_until(func(): return w.extraction["open"], 2.0))
	await get_tree().create_timer(1.0).timeout
	w.rpc_id(1, "c_test", "kill_all_enemies", 0)  # reinforcements spawned by the intel objective
	await get_tree().create_timer(0.5).timeout
	Session.send_chat("TEST:extract")
	await _teleport(w.map_info["extraction"] + Vector3(0, 0.2, 0))
	_ctrl().yaw = 0.4
	await get_tree().create_timer(3.0).timeout
	await shot("06_extraction")
	# results arrive via _on_results

func _status(id: String) -> String:
	return _world.objective_state.get("objectives", {}).get(id, {}).get("status", "")

func _on_results(results: Dictionary) -> void:
	_results = results
	check("mission_result_completed", results.get("result", "") == "completed", results.get("result", ""))
	check("rewards_granted", int(results.get("you", {}).get("xp", 0)) > 0, "xp %s credits %s" % [results.get("you", {}).get("xp"), results.get("you", {}).get("credits")])
	check("profile_persisted", results.has("profile") and int(results["profile"].get("xp", 0)) >= int(results.get("you", {}).get("xp", 0)), "profile xp %s level %s" % [results.get("profile", {}).get("xp"), results.get("profile", {}).get("level")])
	await get_tree().create_timer(0.5).timeout
	await shot("07_results")
	await get_tree().create_timer(1.5).timeout
	check("returned_to_lobby", Session.lobby.get("phase", "") == "lobby")
	_finish()

## Room-browser checks run by a separate client while room `target` fills up and deploys.
func _probe(target: String) -> void:
	var r := {}
	var t := 0.0
	while t < 60.0:
		r = await _find_room(target, 1.0)
		if not r.is_empty() and r["players"] >= r["max"]:
			break
		await get_tree().create_timer(0.5).timeout
		t += 1.0
	check("full_room_listed", not r.is_empty() and r["players"] == 4, "%s/%s" % [r.get("players"), r.get("max")])
	var nf := await _list_rooms({"search": target, "not_full": true})
	check("filter_not_full_hides_full_room", nf.all(func(x): return x["name"] != target))
	_notices.clear()
	Session.request_join_room(r.get("id", 0), "")
	var rejected: bool = await _wait_until(func(): return _notices.any(func(n): return n.contains("full")), 3.0)
	check("full_room_join_rejected", rejected and Session.room_id == 0, str(_notices))
	Session.request_create_room("Bravo", "secret", 2, "op01")
	check("created_password_room", await _wait_until(func(): return Session.room_id != 0, 5.0))
	var b := await _find_room("Bravo", 3.0)
	check("password_room_listed_locked", b.get("locked", false) and b.get("players", 0) == 1 and b.get("max", 0) == 2)
	var np := await _list_rooms({"search": "Bravo", "no_password": true})
	check("filter_no_password", np.is_empty())
	var hp := await _list_rooms({"search": "Bravo", "has_players": true})
	check("filter_has_players", hp.size() == 1)
	for i in range(40):
		var cur := await _list_rooms({"search": target})
		if cur.any(func(x): return x["name"] == target and x["phase"] != "lobby"):
			break
		await get_tree().create_timer(0.5).timeout
	var nip := await _list_rooms({"search": target, "not_in_progress": true})
	check("filter_not_in_progress_hides_mission", nip.is_empty())
	await get_tree().create_timer(12.0).timeout   # keep Bravo open so another client can try a wrong password
	Session.request_leave_room()
	await _wait_until(func(): return Session.room_id == 0, 3.0)
	await get_tree().create_timer(0.5).timeout
	var gone := await _list_rooms({"search": "Bravo"})
	check("empty_room_closed", gone.is_empty())
	_finish()

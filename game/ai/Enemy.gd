class_name Enemy
extends CharacterBody3D
## Enemy combatant. Simulated only on the dedicated server (perception, state machine, navigation, firing).
## Clients hold a puppet that interpolates server snapshots and renders a SoldierModel.

enum State { IDLE, PATROL, INVESTIGATE, ALERT, COMBAT, SEARCH, RETREAT, DISABLED, DEAD }
const STATE_NAMES := ["Idle", "Patrol", "Investigate", "Alert", "Combat", "Search", "Retreat", "Disabled", "Dead"]
const PERCEPTION_INTERVAL := 0.15

var eid := 0
var type_id := "infantry"
var def: Dictionary
var world: Node
var state := State.IDLE
var health := 100.0
var armor := 0.0
var aim_pitch := 0.0
var revealed_until := 0.0

# server AI
var agent: NavigationAgent3D
var patrol: Array = []
var patrol_idx := 0
var home := Vector3.ZERO
var target: Player
var last_known := Vector3.ZERO
var awareness := 0.0
var _perc_t := 0.0
var _lost_t := 0.0
var _state_t := 0.0
var _react_t := 0.0
var _burst_left := 0
var _fire_t := 0.0
var _mag := 30
var _reload_t := 0.0
var _retreated := false
var _stun_t := 0.0
var _nav_goal := Vector3.INF
var _wait_t := 0.0

# client puppet
var _snaps: Array = []
var model: SoldierModel
var _last_pos := Vector3.ZERO
var net_flags := 0

func _init() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)

func setup(id: int, t: String, w: Node, patrol_points: Array, server: bool) -> void:
	eid = id
	type_id = t
	def = GameData.enemy(t)
	world = w
	name = "E%d" % id
	health = def["health"]
	armor = def["armor"]
	_mag = def["mag"]
	patrol = patrol_points
	var s: float = def.get("scale", 1.0)
	($Shape.shape as CapsuleShape3D).height = 1.8 * s
	$Shape.position.y = 0.9 * s
	if server:
		agent = NavigationAgent3D.new()
		agent.path_desired_distance = 0.6
		agent.target_desired_distance = 0.8
		agent.radius = 0.35
		agent.height = 1.8
		add_child(agent)
		state = State.PATROL if patrol.size() > 1 else State.IDLE
	else:
		model = SoldierModel.new()
		model.build_kind(def.get("model", "infantry"), def.get("weapon_model", "ar_b"), s)
		add_child(model)

func _ready() -> void:
	home = global_position
	_last_pos = global_position

func is_dead() -> bool:
	return state == State.DEAD

func chest() -> Vector3:
	return global_position + Vector3.UP * 1.3 * float(def.get("scale", 1.0))

func eye() -> Vector3:
	return global_position + Vector3.UP * 1.6 * float(def.get("scale", 1.0))

# ======================================================================= server
func set_state(s: int) -> void:
	if state == s or state == State.DEAD:
		return
	Log.debug("ai", "state", {"enemy": eid, "from": STATE_NAMES[state], "to": STATE_NAMES[s]})
	state = s
	_state_t = 0.0
	if s == State.COMBAT:
		_react_t = def["reaction_time"]
		_lost_t = 0.0
		if def.get("behaviour", "") in ["alert_others", "coordinate"]:
			world.ai_alert_radius(self, float(def.get("alert_radius", 25.0)))

func engage(p: Player, hunt := false) -> void:
	if state == State.DEAD or p == null:
		return
	target = p
	last_known = p.global_position
	awareness = 1.0
	set_state(State.COMBAT)
	if hunt:
		_nav_to(p.global_position)

func hear(pos: Vector3, source: Player, loudness: float) -> void:
	if state in [State.DEAD, State.DISABLED, State.COMBAT]:
		return
	var d := global_position.distance_to(pos)
	if d > float(def["hearing_range"]) * loudness:
		return
	awareness = max(awareness, 0.55 if d > 12.0 else 0.9)
	last_known = pos
	if source and d < 10.0:
		engage(source)
	else:
		set_state(State.INVESTIGATE)
		_nav_to(pos)

func stun(t: float) -> void:
	if state == State.DEAD:
		return
	_stun_t = t
	set_state(State.DISABLED)

## Returns damage dealt to health.
func take_damage(amount: float, attacker: Player) -> float:
	if state == State.DEAD:
		return 0.0
	var to_armor: float = min(armor, amount * float(def.get("armor_absorb", 0.0)))
	armor -= to_armor
	var dmg := amount - to_armor
	health -= dmg
	if health <= 0.0:
		health = 0.0
		state = State.DEAD
		$Shape.set_deferred("disabled", true)
		velocity = Vector3.ZERO
		world.on_enemy_killed(self, attacker)
		return dmg
	if attacker and state != State.DISABLED:
		if state != State.COMBAT:
			engage(attacker)
		elif target == null or not target.health.alive():
			target = attacker
		last_known = attacker.global_position
	if state == State.COMBAT and health < float(def["health"]) * 0.3 and not _retreated and def.get("behaviour", "") == "standard":
		_retreated = true
		set_state(State.RETREAT)
		var away := (global_position - last_known).normalized() * 10.0
		_nav_to(global_position + away)
	return dmg

func server_tick(dt: float) -> void:
	if state == State.DEAD:
		return
	_state_t += dt
	if state == State.DISABLED:
		_stun_t -= dt
		_move(Vector3.ZERO, 0.0, dt)
		if _stun_t <= 0.0:
			set_state(State.COMBAT if target else State.SEARCH)
		return
	_perc_t -= dt
	if _perc_t <= 0.0:
		_perc_t = PERCEPTION_INTERVAL
		_perceive(PERCEPTION_INTERVAL)
	if _reload_t > 0.0:
		_reload_t -= dt
		if _reload_t <= 0.0:
			_mag = def["mag"]
	match state:
		State.IDLE: _tick_idle(dt)
		State.PATROL: _tick_patrol(dt)
		State.INVESTIGATE, State.SEARCH: _tick_search(dt)
		State.ALERT: _tick_alert(dt)
		State.COMBAT: _tick_combat(dt)
		State.RETREAT: _tick_retreat(dt)

func _perceive(dt: float) -> void:
	var best: Player = null
	var best_d := INF
	var sight: float = def["sight_range"]
	if state in [State.COMBAT, State.ALERT, State.SEARCH]:
		sight *= 1.3
	for p in world.players.values():
		if not p.health.alive() or not p.connected:
			continue
		var to: Vector3 = p.global_position + Vector3.UP * PlayerMotor.eye_height(p.motor) * 0.8 - eye()
		var d := to.length()
		var stance_mult: float = [1.0, 0.75, 0.5][int(p.motor["stance"])]
		if d > sight * stance_mult:
			continue
		if state != State.COMBAT and d > 4.0:
			var fwd := -global_basis.z
			if rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > float(def["fov_deg"]) * 0.5:
				continue
		if not world.has_los(eye(), eye() + to):
			continue
		if d < best_d:
			best_d = d
			best = p
	if best:
		var gain := (1.6 * (1.0 - best_d / sight) + 0.35) * dt * 3.0
		if best.motor["sprinting"]:
			gain *= 1.3
		awareness = min(1.0, awareness + gain)
		last_known = best.global_position
		_lost_t = 0.0
		if state == State.COMBAT:
			target = best if (target == null or not target.health.alive() or target.global_position.distance_to(global_position) > best_d + 5.0) else target
		elif awareness >= 1.0:
			engage(best)
		elif awareness > 0.3 and state != State.ALERT:
			set_state(State.ALERT)
	else:
		awareness = max(0.0, awareness - dt * 0.08)
		if state == State.COMBAT:
			_lost_t += dt
			if _lost_t > 5.0 or (target and not target.health.alive()):
				target = null
				set_state(State.SEARCH)
				_nav_to(last_known)

func _tick_idle(dt: float) -> void:
	_move(Vector3.ZERO, 0.0, dt)

func _tick_patrol(dt: float) -> void:
	if _wait_t > 0.0:
		_wait_t -= dt
		_move(Vector3.ZERO, 0.0, dt)
		return
	var p: Vector3 = Vector3(patrol[patrol_idx][0], patrol[patrol_idx][1], patrol[patrol_idx][2])
	_nav_to(p)
	if _follow_path(float(def["speed_walk"]), dt):
		patrol_idx = (patrol_idx + 1) % patrol.size()
		_wait_t = randf_range(1.5, 4.0)

func _tick_alert(dt: float) -> void:
	_face(last_known, dt)
	_move(Vector3.ZERO, 0.0, dt)
	if _state_t > 3.0 and awareness < 1.0:
		set_state(State.INVESTIGATE)
		_nav_to(last_known)

func _tick_search(dt: float) -> void:
	if _follow_path(float(def["speed_walk"]) * 1.3, dt):
		_wait_t -= dt
		if _wait_t <= 0.0:
			_wait_t = 2.0
			var r := Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			_nav_goal = Vector3.INF
			_nav_to(last_known + r)
	if _state_t > (12.0 if state == State.SEARCH else 8.0):
		awareness = 0.0
		set_state(State.PATROL if patrol.size() > 1 else State.IDLE)
		if patrol.size() <= 1:
			_nav_to(home)

func _tick_retreat(dt: float) -> void:
	_follow_path(float(def["speed_run"]), dt)
	if _state_t > 3.5:
		set_state(State.COMBAT)

func _tick_combat(dt: float) -> void:
	if target == null or not target.health.alive():
		target = null
		set_state(State.SEARCH)
		_nav_to(last_known)
		return
	var tpos := target.global_position + Vector3.UP * PlayerMotor.eye_height(target.motor) * 0.75
	var d := global_position.distance_to(target.global_position)
	var los: bool = world.has_los(eye(), tpos)
	var engage_r: float = def["engage_range"]
	var advancing: bool = def.get("behaviour", "") == "advance"
	if los and d <= engage_r:
		_face(tpos, dt)
		if advancing and d > 8.0:
			_nav_to(target.global_position)
			_follow_path(float(def["speed_walk"]), dt, false)
		else:
			_move(Vector3.ZERO, 0.0, dt)
		_react_t -= dt
		if _react_t <= 0.0:
			_fire_logic(dt, tpos, d)
	else:
		_react_t = max(_react_t, float(def["reaction_time"]) * 0.5)
		_nav_to(last_known)
		if _follow_path(float(def["speed_run"]), dt):
			_face(last_known, dt)

func _fire_logic(dt: float, tpos: Vector3, dist: float) -> void:
	if _reload_t > 0.0:
		return
	if _mag <= 0:
		_reload_t = def["reload_time"]
		return
	_fire_t -= dt
	if _fire_t > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = randi_range(int(def["burst"][0]), int(def["burst"][1]))
	_burst_left -= 1
	_mag -= 1
	_fire_t = 60.0 / float(def["rpm"])
	if _burst_left <= 0:
		_fire_t += randf_range(0.5, 1.1)
	var acc: float = def["accuracy"]
	acc *= clampf(1.25 - dist / float(def["engage_range"]) * 0.6, 0.4, 1.2)
	acc *= [1.0, 0.85, 0.65][int(target.motor["stance"])]
	if target.motor["sprinting"]:
		acc *= 0.75
	var from := eye() - global_basis.z * 0.5
	var hit := randf() < acc
	var end := tpos
	if not hit:
		end = tpos + Vector3(randf_range(-1, 1), randf_range(-0.6, 0.8), randf_range(-1, 1)).normalized() * randf_range(0.6, 1.8)
		end = from + (end - from).normalized() * (dist + 6.0)
	world.enemy_fired(self, from, end, target if hit else null, float(def["damage"]))

func _face(p: Vector3, dt: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	var want := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, want, min(1.0, dt * 8.0))
	aim_pitch = atan2(to.y - 1.4, Vector2(to.x, to.z).length())

func _nav_to(p: Vector3) -> void:
	if _nav_goal.distance_to(p) < 1.0:
		return
	_nav_goal = p
	agent.target_position = p

## Moves along the nav path; returns true when the destination has been reached.
func _follow_path(speed: float, dt: float, face_move := true) -> bool:
	if agent.is_navigation_finished():
		_move(Vector3.ZERO, 0.0, dt)
		return true
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.05:
		_move(Vector3.ZERO, 0.0, dt)
		return agent.is_navigation_finished()
	dir = dir.normalized()
	if face_move:
		_face(global_position + dir, dt)
	_move(dir, speed, dt)
	return false

func _move(dir: Vector3, speed: float, dt: float) -> void:
	var v := velocity
	var hv := Vector2(v.x, v.z).move_toward(Vector2(dir.x, dir.z) * speed, 20.0 * dt)
	v.x = hv.x
	v.z = hv.y
	v.y = -0.5 if is_on_floor() else v.y - 14.0 * dt
	velocity = v
	move_and_slide()

func snapshot() -> Array:
	var flags := 0
	if revealed_until > Time.get_ticks_msec() / 1000.0:
		flags |= 1
	return [eid, global_position, rotation.y, state, health / float(def["health"]), flags, aim_pitch]

# ======================================================================= client puppet
func apply_snapshot(s: Array, now: float) -> void:
	var was_dead := state == State.DEAD
	state = s[3]
	net_flags = s[5]
	if state == State.DEAD and not was_dead:
		$Shape.set_deferred("disabled", true)
	_snaps.append([now, s[1], s[2], s[6]])
	if _snaps.size() > 30:
		_snaps.pop_front()

func on_fire_visual() -> void:
	if model:
		model.kick()

func _physics_process(dt: float) -> void:
	if Net.is_server():
		return
	if not _snaps.is_empty():
		var t := Time.get_ticks_msec() / 1000.0 - Player.INTERP_DELAY
		while _snaps.size() >= 2 and _snaps[1][0] <= t:
			_snaps.pop_front()
		if _snaps.size() >= 2:
			var a: Array = _snaps[0]
			var b: Array = _snaps[1]
			var f := clampf((t - a[0]) / maxf(0.001, b[0] - a[0]), 0.0, 1.0)
			global_position = (a[1] as Vector3).lerp(b[1], f)
			rotation.y = lerp_angle(a[2], b[2], f)
			aim_pitch = lerpf(a[3], b[3], f)
		else:
			global_position = _snaps[0][1]
	var speed := (global_position - _last_pos).length() / maxf(dt, 0.001)
	_last_pos = global_position
	if model:
		var st := "dead" if state == State.DEAD else "alive"
		model.pose(dt, 0, aim_pitch, speed, st)
		model.set_gun_visible(st == "alive")

extends Node3D
## Local-only first-person presentation: camera, arms + weapon view model, sway, bob, recoil,
## ADS transition, reload/switch animation, sprint pose and damage shake. No gameplay authority.

const VM_SCALE := 0.3          # view model is scaled toward the camera so it never clips into walls
const HIP_POS := Vector3(0.17, -0.2, -0.5)
const SPRINT_POS := Vector3(0.12, -0.26, -0.42)
const SPRINT_ROT := Vector3(-0.35, 0.8, 0.25)

var player: Player
var controller: Node
var camera: Camera3D
var _pivot: Node3D       # scaled container
var _vm_anchor: Node3D
var _vm: Node3D
var _vm_weapon := ""
var _ads := 0.0
var _bob_t := 0.0
var _kick := 0.0
var _kick_rot := Vector3.ZERO
var _shake := 0.0
var _sway := Vector2.ZERO
var _last_yaw := 0.0
var _last_pitch := 0.0
var _switch_anim := 0.0
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _flash_t := 0.0
var _eye := 1.65

func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.01
	camera.far = 600.0
	camera.current = true
	add_child(camera)
	_pivot = Node3D.new()
	_pivot.scale = Vector3.ONE * VM_SCALE
	camera.add_child(_pivot)
	_vm_anchor = Node3D.new()
	_pivot.add_child(_vm_anchor)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.5)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	camera.add_child(_flash)
	_flash.position = Vector3(0.05, -0.04, -0.4)
	player.inventory_changed.connect(_on_inv)

func _on_inv(inv: Dictionary) -> void:
	if inv.is_empty():
		return
	var id: String = inv["weapons"][inv["active"]]["id"]
	if id != _vm_weapon:
		_vm_weapon = id
		if _vm:
			_vm.queue_free()
		_vm = ViewModel.build(GameData.weapon(id))
		_vm_anchor.add_child(_vm)
		_set_no_shadow(_vm)
		_switch_anim = 1.0
		_flash_mesh = Geo.sphere(0.035, Color(1, 0.85, 0.5), Vector3.ZERO, _vm.get_node("Muzzle"))
		_flash_mesh.material_override = Geo.mat(Color(1, 0.8, 0.4), 1.0, 0.0, Color(1, 0.7, 0.3))
		_flash_mesh.visible = false

func _set_no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_set_no_shadow(c)

func on_fire(def: Dictionary) -> void:
	_kick = 1.0
	_kick_rot = Vector3(deg_to_rad(float(def["recoil_pitch"])) * 2.0, randf_range(-0.03, 0.03), randf_range(-0.05, 0.05))
	_flash_t = 0.05
	Sfx.play_2d("shot_" + String(def.get("sound", "rifle")), -2.0)
	if _vm:
		var muzzle: Node3D = _vm.get_node("Muzzle")
		var from := muzzle.global_position
		var to := camera.global_position - camera.global_basis.z * 200.0
		var q := PhysicsRayQueryParameters3D.create(camera.global_position, to, 1 | 4)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			to = hit["position"]
		player.world.fx.tracer(from, to)
		if hit and hit["collider"] is StaticBody3D:
			player.world.fx.impact(hit["position"], hit["normal"])

func dry_fire() -> void:
	Sfx.play_2d("dry", -6.0)

func add_shake(amount: float) -> void:
	_shake = min(1.0, _shake + amount)

func _process(dt: float) -> void:
	var m := player.motor
	var bob_mult: float = Settings.get_v("camera_bob")
	# eye height follows stance smoothly
	_eye = lerpf(_eye, PlayerMotor.eye_height(m), min(1.0, dt * 12.0))
	position = Vector3(0, _eye, 0)
	# ADS blend
	var ads_target := 1.0 if m["ads"] and not player.inv_mirror.get("reloading", false) else 0.0
	var def := GameData.weapon(_vm_weapon)
	var ads_time: float = def.get("ads_time", 0.2)
	_ads = move_toward(_ads, ads_target, dt / ads_time)
	var base_fov: float = Settings.get_v("fov")
	var fov_target: float = lerpf(base_fov, base_fov * float(def.get("ads_fov_mult", 0.8)), _ads)
	if m["sprinting"]:
		fov_target += 4.0 * bob_mult
	camera.fov = lerpf(camera.fov, fov_target, min(1.0, dt * 10.0))
	# head bob from horizontal speed
	var hspeed := Vector2(player.velocity.x, player.velocity.z).length()
	_bob_t += dt * hspeed * 2.2
	var bob_amt := 0.0 if not player.is_on_floor() else clampf(hspeed / 5.0, 0.0, 1.0) * bob_mult * (1.0 - _ads * 0.85)
	var bob := Vector3(sin(_bob_t) * 0.012, absf(cos(_bob_t)) * 0.018, 0) * bob_amt
	# look sway (weapon lags behind mouse)
	var dyaw := wrapf(controller.yaw - _last_yaw, -PI, PI)
	var dpitch: float = controller.pitch - _last_pitch
	_last_yaw = controller.yaw
	_last_pitch = controller.pitch
	_sway = _sway.lerp(Vector2(clampf(dyaw * 2.5, -0.08, 0.08), clampf(dpitch * 2.5, -0.08, 0.08)), min(1.0, dt * 10.0))
	_sway = _sway.lerp(Vector2.ZERO, min(1.0, dt * 6.0))
	# recoil + shake decay
	_kick = move_toward(_kick, 0.0, dt * 9.0)
	_shake = move_toward(_shake, 0.0, dt * 2.0)
	var shake_v := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02 * bob_mult
	camera.rotation = Vector3(controller.pitch + _kick_rot.x * _kick * 0.25, 0, _kick_rot.z * _kick * 0.3) + shake_v
	camera.position = bob * 0.5
	# view model placement
	if _vm:
		var sight_y: float = _vm.get_node("Sight").position.y
		var ads_pos := Vector3(0, -sight_y, -0.34)
		var pos := HIP_POS.lerp(ads_pos, _ads)
		var rot := Vector3.ZERO
		var sprint_blend := 1.0 if m["sprinting"] else 0.0
		pos = pos.lerp(SPRINT_POS, sprint_blend * 0.9)
		rot = rot.lerp(SPRINT_ROT, sprint_blend * 0.9)
		var reload_left: float = player.inv_mirror.get("reload_left", 0.0)
		var reloading: bool = player.inv_mirror.get("reloading", false)
		var mag: Node3D = _vm.get_node("Mag")
		if reloading:
			rot += Vector3(0.35, -0.3, 0.6)
			pos += Vector3(-0.03, -0.04, 0.0)
			var phase := fmod(Time.get_ticks_msec() / 1000.0, 1.6) / 1.6
			mag.position.y = -0.04 - (0.25 * sin(phase * PI)) if reload_left > 0.3 else -0.04
		else:
			mag.position.y = -0.04
		if player.is_downed_net() or player.is_eliminated_net() or player.inv_mirror.get("use_left", 0.0) > 0.0:
			pos += Vector3(0, -0.4, 0)
		_switch_anim = move_toward(_switch_anim, 0.0, dt * 2.5)
		pos += Vector3(0, -0.3 * _switch_anim, 0)
		pos += Vector3(0, 0, 0.05 * _kick)
		pos += Vector3(-_sway.x * 0.3, _sway.y * 0.3, 0) * (1.0 - _ads * 0.7)
		pos += Vector3(bob.x, -bob.y, 0)
		_vm_anchor.position = _vm_anchor.position.lerp(pos, min(1.0, dt * 18.0))
		var target_rot := rot + Vector3(_kick * 0.08, _sway.x * 1.5, _sway.x * 1.0)
		_vm_anchor.rotation = _vm_anchor.rotation.lerp(target_rot, min(1.0, dt * 14.0))
	# muzzle flash
	_flash_t -= dt
	_flash.light_energy = 3.0 if _flash_t > 0.0 else 0.0
	if _flash_mesh:
		_flash_mesh.visible = _flash_t > 0.0
		_flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.4)

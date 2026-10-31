extends Node3D
## Third-person presentation of another operator: soldier model, poses, name tag, weapon kick.

var player: Player
var model: SoldierModel
var tag: Label3D
var _last_pos := Vector3.ZERO
var _weapon := ""

func _ready() -> void:
	var c: Array = GameData.klass(player.class_id).get("color", [0.8, 0.8, 0.8])
	var accent := Color(c[0], c[1], c[2])
	model = SoldierModel.new()
	_weapon = player.net.get("weapon", "")
	if _weapon == "":
		_weapon = GameData.klass(player.class_id).get("default_primary", "ar_a")
	model.build_kind(player.class_id, _weapon)
	add_child(model)
	tag = Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = true
	tag.pixel_size = 0.0012
	tag.font_size = 22
	tag.outline_size = 6
	tag.modulate = accent.lightened(0.3)
	tag.position.y = 2.15
	tag.text = "%s\n%s" % [player.display_name, GameData.klass(player.class_id).get("name", "")]
	add_child(tag)
	_last_pos = player.global_position

func on_fire() -> void:
	model.kick()

func _process(dt: float) -> void:
	var speed := (player.global_position - _last_pos).length() / maxf(dt, 0.001)
	_last_pos = player.global_position
	var state := "alive"
	if player.is_downed_net(): state = "downed"
	elif player.is_eliminated_net(): state = "dead"
	model.pose(dt, int(player.motor["stance"]), player.pitch, speed, state)
	model.set_gun_visible(state == "alive")
	if player.net.get("weapon", "") != "" and player.net["weapon"] != _weapon:
		_weapon = player.net["weapon"]
		model.set_weapon(_weapon)
	tag.position.y = 2.15 if state == "alive" and int(player.motor["stance"]) == 0 else 1.0
	tag.modulate.a = 1.0 if not (int(player.net["flags"]) & Player.F_DISCONNECTED) else 0.4

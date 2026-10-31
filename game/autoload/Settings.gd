extends Node
## Client settings (persisted to user://settings.cfg) and input map bootstrap.

signal changed

var values := {
	"mouse_sensitivity": 0.12,
	"fov": 80.0,
	"camera_bob": 1.0,       # 0..1 head bob / sway multiplier (motion-sickness control)
	"hud_scale": 1.0,
	"master_volume": 0.8,
	"invert_y": false,
	"player_name": "",
	"profile_id": "",
	"last_server": "127.0.0.1:7777",
}

## `--profile=<name>` selects a separate local profile (settings + identity), e.g. for several clients on one PC.
var PATH := "user://settings%s.cfg" % ("" if Args.get_value("profile") == "" else "_" + Args.get_value("profile").validate_filename())

const BINDINGS := {
	"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
	"sprint": [KEY_SHIFT], "crouch": [KEY_C], "prone": [KEY_Z], "jump": [KEY_SPACE],
	"reload": [KEY_R], "interact": [KEY_E], "fire_mode": [KEY_B],
	"weapon_primary": [KEY_1], "weapon_secondary": [KEY_2], "weapon_next": [],
	"equip_1": [KEY_G], "equip_2": [KEY_H], "medkit": [KEY_Q], "pause": [KEY_ESCAPE], "chat": [KEY_T],
	"scoreboard": [KEY_TAB],
}
const MOUSE_BINDINGS := {"fire": MOUSE_BUTTON_LEFT, "aim": MOUSE_BUTTON_RIGHT}
## Controller support is planned; actions are defined so a pad can be bound without code changes.
const PAD_BUTTONS := {"jump": JOY_BUTTON_A, "crouch": JOY_BUTTON_B, "reload": JOY_BUTTON_X,
	"interact": JOY_BUTTON_X, "weapon_next": JOY_BUTTON_Y, "sprint": JOY_BUTTON_LEFT_STICK,
	"pause": JOY_BUTTON_START, "equip_1": JOY_BUTTON_RIGHT_SHOULDER, "equip_2": JOY_BUTTON_LEFT_SHOULDER}

func _ready() -> void:
	_load()
	_setup_input()
	if values["profile_id"] == "":
		values["profile_id"] = _new_id()
		save()
	if Args.has("name"):
		values["player_name"] = Args.get_value("name").left(24)
	if values["player_name"] == "":
		values["player_name"] = "Operator-%s" % values["profile_id"].substr(0, 4).to_upper()
	_apply_audio()

func get_v(key: String) -> Variant:
	return values.get(key)

func set_v(key: String, v: Variant) -> void:
	values[key] = v
	_apply_audio()
	save()
	changed.emit()

func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values:
		values[k] = cfg.get_value("settings", k, values[k])

func _apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(values["master_volume"]), 0.0001, 1.0)))

func _new_id() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(16).hex_encode()

func _setup_input() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	for action in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BINDINGS[action]
		InputMap.action_add_event(action, mb)
	for action in PAD_BUTTONS:
		var jb := InputEventJoypadButton.new()
		jb.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, jb)
	var axes := {"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"fire": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "aim": [JOY_AXIS_TRIGGER_LEFT, 1.0]}
	for action in axes:
		var ja := InputEventJoypadMotion.new()
		ja.axis = axes[action][0]
		ja.axis_value = axes[action][1]
		InputMap.action_add_event(action, ja)

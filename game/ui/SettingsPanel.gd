extends PanelContainer
## Settings: sensitivity, FOV, camera motion (motion-sickness control), HUD scale, volume, invert Y.

func _ready() -> void:
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiKit.header("Settings"))
	_slider(v, "Mouse sensitivity", "mouse_sensitivity", 0.02, 0.5, 0.01)
	_slider(v, "Field of view", "fov", 60.0, 100.0, 1.0)
	_slider(v, "Camera motion (bob / sway / shake)", "camera_bob", 0.0, 1.0, 0.05)
	_slider(v, "HUD scale", "hud_scale", 0.75, 1.25, 0.05)
	_slider(v, "Master volume", "master_volume", 0.0, 1.0, 0.05)
	var inv := CheckButton.new()
	inv.text = "Invert Y axis"
	inv.button_pressed = Settings.get_v("invert_y")
	inv.toggled.connect(func(b): Settings.set_v("invert_y", b))
	v.add_child(inv)
	v.add_child(UiKit.label("Controls: WASD move · Shift sprint · C crouch · Z prone · Space jump · RMB aim · LMB fire · R reload\n1/2 or wheel switch · B fire mode · E interact/revive (hold) · Q medkit · G/H equipment · T chat · Esc pause", 13, UiKit.DIM))

func _slider(v: VBoxContainer, title: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	var l := UiKit.label(title, 16)
	l.custom_minimum_size.x = 280
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_v(key))
	s.custom_minimum_size = Vector2(180, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := UiKit.label(str(snappedf(s.value, step)), 16, UiKit.ACCENT)
	row.add_child(val)
	s.value_changed.connect(func(x):
		val.text = str(snappedf(x, step))
		Settings.set_v(key, x))
	v.add_child(row)

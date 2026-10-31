extends Control
## In-mission pause overlay. The simulation keeps running on the server (co-op), so this only blocks local input.

var app: Node

func _init(a: Node) -> void:
	app = a
	UiKit.full_rect(self)

func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(UiKit.full_rect(dim))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_CENTER)
	h.position = Vector2(-460, -260)
	h.add_theme_constant_override("separation", 30)
	add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	h.add_child(v)
	v.add_child(UiKit.label("PAUSED", 40, UiKit.ACCENT, true))
	v.add_child(UiKit.label("The operation continues for your squad.", 14, UiKit.DIM))
	v.add_child(UiKit.button("RESUME", func(): app.toggle_pause(), 280))
	v.add_child(UiKit.button("LEAVE OPERATION", func(): Session.request_leave_room(), 280))
	v.add_child(UiKit.button("DISCONNECT", func(): app.leave_session(), 280))
	v.add_child(UiKit.button("QUIT GAME", func(): get_tree().quit(), 280))
	h.add_child(preload("res://ui/SettingsPanel.gd").new())

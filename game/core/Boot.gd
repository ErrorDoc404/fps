extends Node
## Entry point. `--server` (or a headless run with --dedicated) boots the dedicated server; otherwise the client app.

func _ready() -> void:
	if Args.has("server") or DisplayServer.get_name() == "headless" and not Args.has("autotest"):
		var s := preload("res://server/ServerMain.gd").new()
		s.name = "ServerMain"
		get_tree().root.add_child.call_deferred(s)
	else:
		var app := preload("res://ui/App.gd").new()
		app.name = "App"
		get_tree().root.add_child.call_deferred(app)
	queue_free()

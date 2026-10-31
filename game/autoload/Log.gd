extends Node
## Structured logger. Emits one line per event: `ts level [tag] message {json fields}`.
## Server builds also append to a log file when `--log-file=<path>` is passed.

enum Level { DEBUG, INFO, WARN, ERROR }
const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR"]

var min_level: int = Level.INFO
var _file: FileAccess

func _ready() -> void:
	var path := Args.get_value("log-file", "")
	if path != "":
		_file = FileAccess.open(path, FileAccess.WRITE)
	if Args.has("verbose"):
		min_level = Level.DEBUG

func debug(tag: String, msg: String, fields: Dictionary = {}) -> void: _emit(Level.DEBUG, tag, msg, fields)
func info(tag: String, msg: String, fields: Dictionary = {}) -> void: _emit(Level.INFO, tag, msg, fields)
func warn(tag: String, msg: String, fields: Dictionary = {}) -> void: _emit(Level.WARN, tag, msg, fields)
func error(tag: String, msg: String, fields: Dictionary = {}) -> void: _emit(Level.ERROR, tag, msg, fields)

func _emit(level: int, tag: String, msg: String, fields: Dictionary) -> void:
	if level < min_level:
		return
	var line := "%s %s [%s] %s" % [Time.get_datetime_string_from_system(true), LEVEL_NAMES[level], tag, msg]
	if not fields.is_empty():
		line += " " + JSON.stringify(fields)
	if level >= Level.ERROR:
		printerr(line)
	else:
		print(line)
	if _file:
		_file.store_line(line)
		_file.flush()

class_name DebugLog
extends RefCounted

const MAX_BUFFERED_EVENTS := 500

var _buffer: Array[Dictionary] = []
var _file: FileAccess = null
var _file_path := ""

func _init() -> void:
	_open_file_if_enabled()
	log_event("log_open", {
		"engine": Engine.get_version_info().get("string", "unknown"),
	})

func _open_file_if_enabled() -> void:
	if not ProjectSettings.get_setting("game/debug/log_to_file", true):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("[debug] cannot open user:// directory for debug log")
		return
	dir.make_dir_recursive("debug")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	_file_path = "user://debug/session_%s.jsonl" % stamp
	_file = FileAccess.open(_file_path, FileAccess.WRITE)
	if _file == null:
		push_warning("[debug] cannot open debug log file: %s" % _file_path)
		_file_path = ""

func log_event(kind: String, data: Dictionary = {}) -> void:
	var entry := {
		"t_ms": float(Time.get_ticks_msec()),
		"ts": Time.get_datetime_string_from_system(),
		"kind": kind,
		"data": data,
	}
	_buffer.push_front(entry)
	while _buffer.size() > MAX_BUFFERED_EVENTS:
		_buffer.pop_back()
	if _file != null:
		_file.store_line(JSON.stringify(entry))
		_file.flush()

func recent_events(limit: int = 25) -> Array:
	var result: Array = []
	for index in range(min(limit, _buffer.size())):
		result.append(_buffer[index])
	return result

func close() -> void:
	log_event("log_close", {})
	if _file != null:
		_file.close()
		_file = null

func file_path() -> String:
	return _file_path

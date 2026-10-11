extends Node

const SAVE_VERSION := 1
const SAVE_PATH := "user://saves/save.json"
var _save_version := SAVE_VERSION
var last_error: StringName = &""

func save_game(payload: Dictionary) -> Error:
	last_error = &""
	var data := payload.duplicate(true)
	data["save_version"] = _save_version
	data["saved_at"] = Time.get_datetime_string_from_system()
	var directory := DirAccess.open("user://")
	if directory == null:
		last_error = &"write_failed"
		return ERR_CANT_CREATE
	directory.make_dir_recursive("saves")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		last_error = &"write_failed"
		return ERR_CANT_CREATE
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK

func load_game() -> Dictionary:
	last_error = &""
	return _read_save(SAVE_PATH)

func load_corrupt_for_test(path: String) -> Dictionary:
	return _read_save(path)

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		last_error = &"no_save"
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = &"read_failed"
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		last_error = &"corrupt_save"
		return {}
	var data: Dictionary = parsed
	var version: int = data.get("save_version", 0)
	if version != _save_version:
		last_error = &"unsupported_version"
		data["loaded_version"] = version
		return data
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func can_load_version(version: int) -> bool:
	return version == _save_version

func version() -> int:
	return _save_version

extends Node

signal mob_died(mob_id: StringName, xp: float, definition: Resource)
signal player_died

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

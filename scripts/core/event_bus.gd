extends Node

signal mob_died(mob_id: StringName, xp: float, definition: Resource)
signal player_died
signal damage_applied(result: DamageResult)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

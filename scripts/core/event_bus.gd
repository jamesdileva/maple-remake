extends Node

signal mob_died(mob_id: StringName, xp: float, definition: Resource)
signal player_died
signal damage_applied(result: DamageResult)
signal ability_cast_started(ability: AbilityDefinition)
signal ability_cast_completed(ability: AbilityDefinition, targets_hit: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

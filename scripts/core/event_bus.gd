extends Node

signal mob_died(mob_id: StringName, xp: float, definition: Resource)
signal mob_died_at(mob_id: StringName, xp: float, definition: Resource, position: Vector2)
signal player_died
signal damage_applied(result: DamageResult)
signal ability_cast_started(ability: AbilityDefinition)
signal ability_cast_completed(ability: AbilityDefinition, targets_hit: int)
signal loot_collected(item_id: StringName, amount: int)
signal summon_spawned(ability_id: StringName, count: int)
signal shield_applied(ability_id: StringName, amount: float)
signal lethal_protection(new_hp: float, class_id: StringName)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

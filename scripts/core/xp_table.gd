class_name XpTable
extends Resource

@export var max_level := 50
@export var base_xp := 100.0
@export var growth := 1.35

func xp_for_level(level: int) -> float:
	if level <= 1:
		return 0.0
	return base_xp * pow(growth, float(level - 2))

func xp_required(from_level: int) -> float:
	if from_level >= max_level:
		return 0.0
	return xp_for_level(from_level + 1) - xp_for_level(from_level)

func is_max_level(level: int) -> bool:
	return level >= max_level

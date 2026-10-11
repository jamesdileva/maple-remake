class_name LootEntry
extends Resource

@export var item: ItemDefinition
@export var weight := 1.0
@export var min_amount := 1
@export var max_amount := 1

func roll_amount(rng: RandomNumberGenerator) -> int:
	var low: int = mini(min_amount, max_amount)
	var high: int = maxi(min_amount, max_amount)
	return rng.randi_range(low, high)

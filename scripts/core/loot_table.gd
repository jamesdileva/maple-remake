class_name LootTable
extends Resource

@export var rolls := 1
@export var entries: Array[LootEntry] = []

func roll() -> Array:
	var drops: Array = []
	if entries.is_empty():
		return drops
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var total_weight := 0.0
	for entry in entries:
		total_weight += maxf(0.0, entry.weight)
	if total_weight <= 0.0:
		return drops
	for _i in range(maxi(1, rolls)):
		var threshold := rng.randf() * total_weight
		var cumulative := 0.0
		for entry in entries:
			cumulative += maxf(0.0, entry.weight)
			if threshold <= cumulative:
				drops.append({"item": entry.item, "amount": entry.roll_amount(rng)})
				break
	return drops

class_name EquipmentDefinition
extends Resource

enum Slot { WEAPON, TOP, BOTTOM, HELMET }

@export var id := &"rusty_blade"
@export var display_name := "Rusty Blade"
@export var slot: Slot = Slot.WEAPON
@export var level_requirement := 1
@export var power := 0.0
@export var defense_bonus := 0.0
@export var max_hp_bonus := 0.0
@export var max_mana_bonus := 0.0

func slot_name() -> StringName:
	match slot:
		Slot.WEAPON:
			return &"weapon"
		Slot.TOP:
			return &"top"
		Slot.BOTTOM:
			return &"bottom"
		Slot.HELMET:
			return &"helmet"
	return &""

func summary() -> String:
	var lines: Array = [display_name]
	if power > 0.0:
		lines.append("+%d Power" % int(power))
	if defense_bonus > 0.0:
		lines.append("+%d Defense" % int(defense_bonus))
	if max_hp_bonus > 0.0:
		lines.append("+%d Max HP" % int(max_hp_bonus))
	if max_mana_bonus > 0.0:
		lines.append("+%d Max MP" % int(max_mana_bonus))
	if level_requirement > 1:
		lines.append("Requires Lv %d" % level_requirement)
	return "\n".join(lines)

func stat_delta(other: EquipmentDefinition) -> Dictionary:
	var mine := _stat_map()
	var theirs: Dictionary = other._stat_map() if other != null else {"power": 0.0, "defense": 0.0, "max_hp": 0.0, "max_mana": 0.0}
	return {
		"power": float(mine.power) - float(theirs.power),
		"defense": float(mine.defense) - float(theirs.defense),
		"max_hp": float(mine.max_hp) - float(theirs.max_hp),
		"max_mana": float(mine.max_mana) - float(theirs.max_mana),
	}

func _stat_map() -> Dictionary:
	return {
		"power": power,
		"defense": defense_bonus,
		"max_hp": max_hp_bonus,
		"max_mana": max_mana_bonus,
	}

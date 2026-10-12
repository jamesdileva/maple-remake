class_name AbilityDefinition
extends Resource

enum AreaMode { FRONTAL, CENTERED }
enum Element { NONE, FIRE, ICE, LIGHTNING }

@export var id := &"arcane_burst"
@export var display_name := "Arcane Burst"
@export var ability_class := &"base"
@export var element: Element = Element.NONE
@export var mana_cost := 20.0
@export var cast_time := 0.5
@export var damage := 25.0
@export var range := 120.0
@export var width := 90.0
@export var max_targets := 0
@export var area_mode: AreaMode = AreaMode.FRONTAL
@export var cast_effect: PackedScene
@export var impact_effect: PackedScene
@export var max_level := 5
@export var unlock_level := 1
@export var damage_per_level := 5.0
@export var mana_per_level := 0.0
@export var slow_duration := 0.0
@export var slow_factor := 0.0
@export var shield_absorb := 0.0
@export var shield_duration := 0.0
@export var summon_count := 0
@export var summon_duration := 0.0
@export var summon_damage := 0.0
@export var summon_interval := 1.0
@export var summon_scene: PackedScene

func damage_at(ability_level: int) -> float:
	return damage + damage_per_level * float(maxi(1, ability_level) - 1)

func mana_cost_at(ability_level: int) -> float:
	return maxf(0.0, mana_cost + mana_per_level * float(maxi(1, ability_level) - 1))

func is_elemental() -> bool:
	return element != Element.NONE

func is_shield() -> bool:
	return shield_absorb > 0.0

func is_summon() -> bool:
	return summon_count > 0 and summon_scene != null

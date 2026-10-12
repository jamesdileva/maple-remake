class_name ClassDefinition
extends Resource

@export var id := &"mage"
@export var display_name := "Mage"
@export var ability_slots: Array[AbilityDefinition] = []
@export var advanced_ability_slots: Array[AbilityDefinition] = []
@export var advancement_level := 20
@export var starting_hp := 100.0
@export var starting_mana := 100.0
@export var defense := 0.0
@export var crit_chance := 0.05
@export var crit_multiplier := 2.0
@export var mana_regen_per_second := 8.0

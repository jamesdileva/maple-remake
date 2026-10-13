class_name ClassDefinition
extends Resource

@export var id := &"mage"
@export var display_name := "Mage"
@export var ability_slots: Array[AbilityDefinition] = []
@export var advanced_ability_slots: Array[AbilityDefinition] = []
@export var alternate_ability_slots: Array[AbilityDefinition] = []
@export var advancement_level := 20
@export var party_buff_interval := 12.0
@export var party_buff_duration := 2.0
@export var starting_hp := 100.0
@export var starting_mana := 100.0
@export var defense := 0.0
@export var crit_chance := 0.05
@export var crit_multiplier := 2.0
@export var mana_regen_per_second := 8.0
@export var advanced_defense_bonus := 0.0
@export var advanced_crit_bonus := 0.0
@export var advanced_speed_bonus := 0.0
@export var party_hp_bonus := 0.0
@export var party_mp_bonus := 0.0
@export var party_crit_bonus := 0.0
@export var party_range_bonus := 0.0

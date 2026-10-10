class_name AbilityDefinition
extends Resource

enum AreaMode { FRONTAL, CENTERED }

@export var id := &"arcane_burst"
@export var display_name := "Arcane Burst"
@export var ability_class := &"base"
@export var mana_cost := 20.0
@export var cast_time := 0.5
@export var damage := 25.0
@export var range := 120.0
@export var width := 90.0
@export var max_targets := 0
@export var area_mode: AreaMode = AreaMode.FRONTAL
@export var cast_effect: PackedScene
@export var impact_effect: PackedScene

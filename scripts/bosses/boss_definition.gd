class_name BossDefinition
extends MobDefinition

@export var phases: Array[BossPhaseDefinition] = []
@export var display_scale := 1.0
@export var tint := Color(1.0, 1.0, 1.0, 1.0)
@export var is_final := false

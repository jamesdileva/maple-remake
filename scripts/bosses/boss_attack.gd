class_name BossAttackDefinition
extends Resource

enum Area { FRONTAL, CENTERED }

@export var id := &"swipe"
@export var display_name := "Swipe"
@export var windup_time := 0.6
@export var active_time := 0.15
@export var recover_time := 0.5
@export var cooldown := 0.4
@export var damage := 15.0
@export var range := 120.0
@export var width := 80.0
@export var area_mode: Area = Area.FRONTAL
@export var telegraph_color := Color(1.0, 0.25, 0.2, 1.0)

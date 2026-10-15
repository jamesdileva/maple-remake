class_name LessonDefinition
extends Resource

enum Bind { PLAYER, ATTACK, SKILL_CAST, TIMER, EXTERNAL, ADVANCED }

@export var id := &"move"
@export var title := "Move Around"
@export var detail := "Run with A/D or the left stick. Press jump to hop ledges."
@export var bind: Bind = Bind.PLAYER
@export var key_action := &"move_left"
@export var threshold := 2.0
@export var depends_on: Array[StringName] = []
@export var show_once := true

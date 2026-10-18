class_name MobDefinition
extends Resource

@export var id := &"test_slime"
@export var display_name := "Slime"
@export var max_hp := 30.0
@export var move_speed := 70.0
@export var contact_damage := 5.0
@export var contact_interval := 0.8
@export var xp := 5.0
@export var gravity := 900.0
@export var defense := 0.0
@export var mob_scene: PackedScene
@export var recommended_level := 1
@export var body_tint := Color(1, 1, 1, 1)
@export var visual_scale := 1.0
@export var sprite_frames: SpriteFrames
@export var hit_effect: SpriteFrames
@export var sprite_offset := Vector2.ZERO
@export var max_chain_depth := 0
@export var chain: ChainPayload
@export var loot_table: LootTable
@export var is_boss := false

class_name BossEncounter
extends Area2D

const BOSS_SCENE_PATH := "res://scenes/bosses/boss.tscn"

@export var definition: MobDefinition
@export var boss_scene: PackedScene

var _boss: Boss
var _armed := true

func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.WORLD
	monitoring = true
	add_to_group("boss_encounters")

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if not _overlaps(player):
		_armed = true
		return
	if not _armed:
		return
	if _boss != null and is_instance_valid(_boss) and not _boss.is_dead():
		return
	_armed = false
	_spawn()

func _spawn() -> void:
	if definition == null:
		return
	var packed: PackedScene = boss_scene if boss_scene != null else load(BOSS_SCENE_PATH)
	if packed == null:
		return
	var host := get_parent()
	if host == null:
		return
	var boss: Boss = packed.instantiate()
	boss.definition = definition
	host.add_child(boss)
	boss.global_position = global_position
	_boss = boss
	DebugManager.register_combat_event("boss_encounter", {"boss": definition.id})

func _overlaps(player: Node) -> bool:
	for body: Node in get_overlapping_bodies():
		if body == player:
			return true
	return false

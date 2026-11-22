extends RefCounted

const SLIME := "res://data/mobs/test_slime.tres"
const MOB_SCENE := "res://scenes/mobs/mob.tscn"
const ROOM := "res://scenes/maps/test_room.tscn"

func get_suite_name() -> String:
	return "combat_feel"

func run(t) -> void:
	var room: Node2D = (load(ROOM) as PackedScene).instantiate()
	t.root.add_child(room)
	t.register_world(room)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	var player: Player = room.get_node("Player")
	player.crit_chance = 0.0

	await _hit_stop(t, room, player)
	await _damage_numbers(t, room, player)
	await _camera_shake(t, player)

	player.crit_chance = 0.05
	DamageNumber.enabled = true
	HitStop.enabled = true
	CameraShake.kick_enabled = true
	room.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _hit_stop(t, room, player) -> void:
	HitStop.enabled = true
	DamageNumber.enabled = false
	var mob := _spawn_mob(room, Vector2(-120.0, -46.0))
	await t.physics_frame
	mob.take_damage(999999.0, player)
	t.assert_true(Engine.time_scale < 1.0, "a kill stops time briefly")
	await t.create_timer(0.3, true, false, true).timeout
	t.assert_almost_eq(Engine.time_scale, 1.0, 0.001, "the hit stop recovers to real time")
	HitStop.enabled = false
	var second := _spawn_mob(room, Vector2(80.0, -46.0))
	await t.physics_frame
	second.take_damage(999999.0, player)
	t.assert_almost_eq(Engine.time_scale, 1.0, 0.001, "a disabled hit stop leaves time alone")

func _damage_numbers(t, room, player) -> void:
	DamageNumber.enabled = true
	HitStop.enabled = false
	var mob := _spawn_mob(room, Vector2(-120.0, -46.0))
	await t.physics_frame
	var labels_before = t.get_nodes_in_group("damage_numbers").size()
	mob.take_damage(25.0, player)
	await t.physics_frame
	var labels = t.get_nodes_in_group("damage_numbers")
	t.assert_true(labels.size() > labels_before, "an applied hit spawns floating damage text")
	var crit_player_crit = player.crit_chance
	player.crit_chance = 1.0
	var crit_mob := _spawn_mob(room, Vector2(-120.0, -46.0))
	await t.physics_frame
	crit_mob.take_damage(30.0, player)
	await t.physics_frame
	player.crit_chance = crit_player_crit
	var crit_labels = t.get_nodes_in_group("damage_numbers")
	t.assert_true(crit_labels.size() > labels.size(), "a crit spawns its own text")
	DamageNumber.enabled = false
	for label: Object in crit_labels:
		if is_instance_valid(label):
			label.free()
	await t.physics_frame

func _camera_shake(t, player) -> void:
	CameraShake.kick_enabled = true
	var camera = player.get_node("Camera")
	camera.kick(4.0)
	await t.physics_frame
	await t.physics_frame
	t.assert_true(camera.offset != Vector2.ZERO, "a kick offsets the camera")
	await t.create_timer(0.7, true, false, true).timeout
	t.assert_eq(camera.offset, Vector2.ZERO, "the camera settles after a kick")
	CameraShake.kick_enabled = false
	camera.kick(8.0)
	t.assert_eq(camera.offset, Vector2.ZERO, "a disabled shake leaves the camera steady")

func _spawn_mob(room: Node2D, at: Vector2) -> Mob:
	var mob: Mob = (load(MOB_SCENE) as PackedScene).instantiate()
	mob.definition = load(SLIME) as MobDefinition
	room.add_child(mob)
	mob.global_position = at
	return mob

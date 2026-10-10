extends SceneTree

func _initialize() -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	root.add_child(world)
	var player: CharacterBody2D = world.get_node("Player")
	for _i in range(20):
		await physics_frame

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	var mob: CharacterBody2D = mob_scene.instantiate()
	mob.set("definition", definition)
	mob.global_position = Vector2(0.0, -46.0)
	world.add_child(mob)
	player.global_position = Vector2(300.0, -60.0)
	for _i in range(30):
		await physics_frame
		if _i % 6 == 0:
			print(
				"frame ", _i,
				" mob_x=", mob.global_position.x,
				" vel=", mob.velocity,
				" on_floor=", mob.is_on_floor(),
			)
	print("move_speed var on mob: ", mob.get("_move_speed"))
	world.queue_free()
	quit(0)

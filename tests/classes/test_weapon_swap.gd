extends RefCounted

func get_suite_name() -> String:
	return "weapon_swap"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var player: Player = world.get_node("Player")
	var archer: ClassDefinition = load("res://data/classes/archer.tres")
	player.apply_class(archer)
	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	t.assert_false(player.wield_alternate, "the bow is wielded first")
	t.assert_eq(player.ability_at(0).id, &"archer_quick_shot", "slot 1 is a bow ability")
	t.assert_false(player.can_swap_weapon() == false, "the archer can swap")

	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	player.apply_class(mage)
	t.assert_false(player.can_swap_weapon(), "classes without an alternate kit cannot swap")
	t.assert_false(player.swap_weapon(), "swapping without an alternate kit fails")
	player.apply_class(archer)

	var swaps: Array = []
	player.weapon_swapped.connect(func(alternate: bool): swaps.append(alternate))
	t.assert_true(player.swap_weapon(), "swapping succeeds")
	t.assert_true(player.wield_alternate, "the crossbow is wielded")
	t.assert_eq(swaps, [true], "the swap emits exactly once")
	t.assert_eq(player.ability_at(0).id, &"xbow_bolt", "slot 1 is a crossbow ability after the swap")
	t.assert_eq(player.ability_at(3).id, &"xbow_snipe", "slot 4 is the snipe after the swap")
	t.assert_true(player.swap_weapon(), "swapping back succeeds")
	t.assert_false(player.wield_alternate, "the bow is wielded again")
	t.assert_eq(player.ability_at(0).id, &"archer_quick_shot", "the bow kit returns intact")

	var marker := player.get_node_or_null("Visual/WeaponMarker") as ColorRect
	t.assert_true(marker != null, "the weapon marker exists")
	player.swap_weapon()
	t.assert_true(marker.color == Color(0.75, 0.78, 0.85), "the marker shows steel for the crossbow")
	player.swap_weapon()
	t.assert_true(marker.color == Color(0.55, 0.38, 0.2), "the marker shows wood for the bow")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var _clear_mobs = func() -> void:
		for mob: Object in t.get_nodes_in_group("enemies"):
			if is_instance_valid(mob):
				mob.queue_free()
		await t.physics_frame

	var _spawn_mob = func(position: Vector2) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = definition
		spawned.global_position = position
		world.add_child(spawned)
		return spawned

	var _press = func(action: String) -> void:
		Input.action_press(action)
		for _i in range(3):
			await t.physics_frame
		Input.action_release(action)

	var _finish = func(max_frames: int) -> void:
		for _i in range(max_frames):
			if not player.is_casting():
				return
			await t.physics_frame

	# swap mid-cast cancels the cast, then the new kit fires
	await _clear_mobs.call()
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	player.mana_regen_per_second = 0.0
	await t.physics_frame
	await t.physics_frame
	player.mana = player.max_mana
	var target: Mob = _spawn_mob.call(Vector2(420.0, -40.0))
	target.hp = 500.0
	await t.physics_frame
	await t.physics_frame
	Input.action_press("skill_4")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_4")
	t.assert_true(player.is_casting(), "the bomb starts casting")
	await _press.call("swap_weapon")
	t.assert_false(player.is_casting(), "swapping cancels the running cast")
	t.assert_true(player.wield_alternate, "the swap lands mid-combat")

	# compatibility: the crossbow kit casts immediately after the swap
	var hp_before: float = target.hp
	player.mana = player.max_mana
	await _press.call("skill_1")
	await _finish.call(100)
	t.assert_true(target.hp < hp_before, "the crossbow fires right after swapping")

	# no inventory interruption: gear survives every swap
	var bow_item: EquipmentDefinition = load("res://data/equipment/hunting_bow.tres")
	player.equip(bow_item)
	t.assert_eq(player.equipped_in(&"weapon").id, &"hunting_bow", "gear equips")
	player.swap_weapon()
	player.swap_weapon()
	t.assert_eq(player.equipped_in(&"weapon").id, &"hunting_bow", "gear survives double swaps")
	t.assert_eq(player.equipment_power(), 5.0, "gear bonuses survive swaps")

	# swap persists through save/load
	if not player.wield_alternate:
		player.swap_weapon()
	t.assert_true(player.wield_alternate, "crossbow wielded before saving")
	var payload := player.capture_state()
	t.assert_true(payload.wield_alternate, "the save captures the wielded weapon")
	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	reloaded.restore_state(payload)
	t.assert_true(reloaded.wield_alternate, "the wield survives reload")
	t.assert_eq(reloaded.ability_at(0).id, &"xbow_bolt", "the reloaded kit matches the wield")
	reloaded.queue_free()

	await _clear_mobs.call()
	for summon: Object in player.get("_summons").duplicate():
		if is_instance_valid(summon):
			summon.queue_free()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	Input.action_release("swap_weapon")
	t.complete_suite(get_suite_name())

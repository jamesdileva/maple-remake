extends RefCounted

func get_suite_name() -> String:
	return "assassin_party_buff"

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
	var assassin: ClassDefinition = load("res://data/classes/assassin.tres")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(assassin.party_attack_speed_bonus > 0.0, "the assassin carries an attack-speed aura")
	t.assert_true(assassin.party_move_speed_bonus > 0.0, "the assassin carries a move-speed aura")
	t.assert_true(assassin.party_jump_bonus > 0.0, "the assassin carries a jump aura")
	t.assert_eq(mage.party_attack_speed_bonus, 0.0, "the mage carries no attack-speed aura")
	t.assert_eq(mage.party_move_speed_bonus, 0.0, "the mage carries no move-speed aura")
	t.assert_eq(mage.party_jump_bonus, 0.0, "the mage carries no jump aura")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	var alacrity_events: Array = []
	player.party_alacrity_changed.connect(func(attack: float, move: float, jump: float): alacrity_events.append(Vector3(attack, move, jump)))

	player.apply_class(assassin)
	t.assert_eq(player.effective_alacrity_bonus(), Vector3(0.15, 0.1, 0.1), "the solo aura matches the data")
	t.assert_almost_eq(player.attack_speed_multiplier(), 1.15, 0.0001, "the solo assassin swings 15 percent faster")
	t.assert_almost_eq(player.run_speed, 280.0 * 1.25, 0.01, "the solo assassin runs with base plus aura (%.1f)" % player.run_speed)
	t.assert_almost_eq(player.jump_velocity, 640.0 * 1.1, 0.01, "the solo assassin jumps with the aura (%.1f)" % player.jump_velocity)
	var strike := load("res://data/abilities/assassin_strike.tres") as AbilityDefinition
	t.assert_almost_eq(player.effective_cast_time(strike), strike.cast_time / 1.15, 0.0001, "casts complete faster under the aura")
	t.assert_true(player.effective_attack_cooldown() < player.basic_attack_cooldown, "basic attacks recycle faster under the aura")
	t.assert_true(alacrity_events.size() >= 1, "applying the class emits the alacrity change")

	player.apply_class(mage)
	t.assert_eq(player.effective_alacrity_bonus(), Vector3.ZERO, "the mage has no aura")
	t.assert_almost_eq(player.attack_speed_multiplier(), 1.0, 0.0001, "the mage swings at base speed")
	t.assert_almost_eq(player.run_speed, 280.0, 0.01, "the mage runs at base speed")
	t.assert_almost_eq(player.jump_velocity, 640.0, 0.01, "the mage jumps at base height")

	player.apply_class(assassin)
	var allies: Array = []
	for index in range(3):
		var ally: Player = load("res://scenes/player/player.tscn").instantiate()
		world.add_child(ally)
		await t.physics_frame
		ally.apply_class(mage)
		ally.global_position = Vector2(100.0 + float(index) * 40.0, -60.0)
		allies.append(ally)
	var roster: Array = [player]
	roster.append_array(allies)
	player.set_party(roster)
	for ally in allies:
		ally.set_party(roster)
	for member in roster:
		t.assert_eq(member.effective_alacrity_bonus(), Vector3(0.15, 0.1, 0.1), "every party member feels the alacrity")
		t.assert_almost_eq(member.attack_speed_multiplier(), 1.15, 0.0001, "every member swings faster")
		t.assert_almost_eq(member.jump_velocity, 640.0 * 1.1, 0.01, "every member jumps higher")
	t.assert_almost_eq(player.run_speed, 280.0 * 1.25, 0.01, "the assassin keeps base plus aura in party")
	for ally in allies:
		t.assert_almost_eq(ally.run_speed, 280.0 * 1.1, 0.01, "allies gain the move aura without assassin legs")
	t.assert_true(alacrity_events.size() >= 1, "party changes emit alacrity")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	var dummy: Mob = mob_scene.instantiate()
	dummy.definition = definition
	dummy.global_position = Vector2(370.0, -30.0)
	world.add_child(dummy)
	player.global_position = Vector2(300.0, -60.0)
	player.crit_chance = 0.0
	await t.physics_frame
	await t.physics_frame
	dummy.hp = 300.0
	var hp_before: float = dummy.hp
	player.mana = player.max_mana
	Input.action_press("skill_1")
	for _i in range(3):
		await t.physics_frame
	Input.action_release("skill_1")
	for _i in range(80):
		if not player.is_casting():
			break
		await t.physics_frame
	t.assert_true(dummy.hp < hp_before, "hasted casts still land")
	dummy.queue_free()

	player.apply_class(mage)
	for member in roster:
		member.refresh_stats()
	t.assert_eq(player.effective_alacrity_bonus(), Vector3.ZERO, "no assassin present means no alacrity")
	for ally in allies:
		t.assert_eq(ally.effective_alacrity_bonus(), Vector3.ZERO, "allies lose the alacrity too")
		t.assert_almost_eq(ally.attack_speed_multiplier(), 1.0, 0.0001, "allies swing at base speed again")
		t.assert_almost_eq(ally.run_speed, 280.0, 0.01, "ally run speed returns to base")
		t.assert_almost_eq(ally.jump_velocity, 640.0, 0.01, "ally jump returns to base")

	player.apply_class(assassin)
	allies[0].apply_class(assassin)
	var duo: Array = [player, allies[0]]
	player.set_party(duo)
	allies[0].set_party(duo)
	t.assert_eq(player.effective_alacrity_bonus(), Vector3(0.15, 0.1, 0.1), "duplicate assassins do not stack")
	t.assert_almost_eq(player.attack_speed_multiplier(), 1.15, 0.0001, "one haste bonus only, even with two assassins")

	t.assert_true(player.effective_alacrity_bonus().x > 0.0, "the aura needs no cast to be active")

	for ally in allies:
		if is_instance_valid(ally):
			ally.queue_free()
	player.leave_party()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

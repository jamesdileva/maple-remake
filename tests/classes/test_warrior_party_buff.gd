extends RefCounted

func get_suite_name() -> String:
	return "warrior_party_buff"

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
	var warrior: ClassDefinition = load("res://data/classes/warrior.tres")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(warrior.party_hp_bonus > 0.0, "the warrior carries an HP party aura")
	t.assert_true(warrior.party_mp_bonus > 0.0, "the warrior carries an MP party aura")
	t.assert_eq(mage.party_hp_bonus, 0.0, "the mage carries no HP aura")

	DebugManager.god_mode = true
	DebugManager.disable_ai = true

	# solo warrior: the aura is on with no action taken
	player.apply_class(warrior)
	player.hp = player.max_hp
	t.assert_eq(player.effective_party_bonus(), Vector2(40.0, 15.0), "the solo aura matches the data")
	t.assert_eq(player.max_hp, 260.0 + 40.0, "the solo warrior walks around with +40 max HP")
	t.assert_eq(player.max_mana, 60.0 + 15.0, "the solo warrior walks around with +15 max MP")

	var aura_events: Array = []
	player.party_aura_changed.connect(func(hp_bonus: float, mp_bonus: float): aura_events.append(Vector2(hp_bonus, mp_bonus)))

	# solo mage: nothing
	player.apply_class(mage)
	t.assert_eq(player.effective_party_bonus(), Vector2.ZERO, "the mage has no aura")
	t.assert_eq(player.max_hp, 100.0, "the mage gains no bonus HP")

	# simulated party: warrior plus three mages all gain the aura
	player.apply_class(warrior)
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
		var bonus: Vector2 = member.effective_party_bonus()
		t.assert_eq(bonus, Vector2(40.0, 15.0), "every party member sees the aura")
		t.assert_eq(member.max_hp, member._class_starting_hp() + 40.0, "every member gains the HP bonus")
	player.hp = player.max_hp

	# warrior leaves: the aura drops for everyone, automatically
	player.apply_class(mage)
	for member in roster:
		member.refresh_stats()
	t.assert_eq(player.effective_party_bonus(), Vector2.ZERO, "no warrior present means no aura")
	for ally in allies:
		t.assert_eq(ally.effective_party_bonus(), Vector2.ZERO, "allies lose the aura too")
		t.assert_eq(ally.max_hp, 100.0, "ally max HP returns to base")

	# two warriors do not stack the aura
	player.apply_class(warrior)
	allies[0].apply_class(warrior)
	var duo: Array = [player, allies[0]]
	player.set_party(duo)
	allies[0].set_party(duo)
	t.assert_eq(player.effective_party_bonus(), Vector2(40.0, 15.0), "duplicate warriors do not double the aura")
	t.assert_eq(player.max_hp, 260.0 + 40.0, "one bonus only, even with two warriors")

	# no manual casting exists for the aura
	t.assert_true(player.max_hp > 260.0 - 40.0, "the aura needs no cast to be active")

	for ally in allies:
		if is_instance_valid(ally):
			ally.queue_free()
	player.leave_party()
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

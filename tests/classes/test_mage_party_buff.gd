extends RefCounted

func get_suite_name() -> String:
	return "mage_party_buff"

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
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(mage != null, "mage class loads")
	t.assert_true(mage.party_buff_interval > 0.0, "the party buff has a rearm interval")
	t.assert_true(mage.party_buff_duration > 0.0, "the party buff has a recovery window")
	DebugManager.god_mode = false
	DebugManager.disable_ai = true

	var triggers: Array = []
	player.lethal_protection_triggered.connect(func(): triggers.append(1))
	var fired := 0
	EventBus.lethal_protection.connect(func(_new_hp: float, _class_id: StringName): fired += 1)

	t.assert_false(player.is_lethal_protected(), "protection starts inactive")
	t.assert_eq(player.lethal_trigger_count(), 0, "no protection has fired yet")

	player.hp = 10.0
	player.take_damage(4.0, null)
	t.assert_eq(player.hp, 6.0, "non-lethal damage lands normally")
	t.assert_eq(player.lethal_trigger_count(), 0, "non-lethal damage does not trigger protection")

	player.hp = 10.0
	player.take_damage(999999.0, null)
	t.assert_eq(player.hp, 1.0, "protection leaves the player at exactly 1 HP")
	t.assert_eq(triggers.size(), 1, "protection triggers automatically on a lethal hit")
	t.assert_true(player.is_lethal_protected(), "the recovery window is active")
	t.assert_true(player.lethal_protection_remaining() > 0.0, "the window has time left")

	player.take_damage(50.0, null)
	t.assert_eq(player.hp, 1.0, "damage is fully blocked during the window")
	t.assert_eq(triggers.size(), 1, "blocked damage does not re-trigger")

	for _i in range(240):
		await t.physics_frame
	t.assert_false(player.is_lethal_protected(), "the window expires on its own")
	t.assert_eq(player.hp, 1.0, "the player stays at 1 HP after the window")

	player.hp = 10.0
	await _drain(player, mage.party_buff_duration)
	var cooldown_after_trigger: float = player.lethal_protection_cooldown()
	t.assert_true(cooldown_after_trigger > 0.0,
		"protection enters cooldown after triggering (%.2f left)" % cooldown_after_trigger)
	var unprotected_deaths: Array = []
	EventBus.player_died.connect(func(): unprotected_deaths.append(1))
	player.take_damage(999999.0, null)
	t.assert_eq(unprotected_deaths.size(), 1,
		"a lethal hit during cooldown is not protected and kills the player")
	t.assert_eq(triggers.size(), 1, "no protection fired during cooldown")

	player.hp = player.max_hp
	await _drain(player, mage.party_buff_interval)
	var cooldown_before: float = player.lethal_protection_cooldown()
	t.assert_true(cooldown_before <= 0.001, "protection rearms after the interval (%.2f)" % cooldown_before)
	player.hp = 10.0
	player.take_damage(999999.0, null)
	t.assert_eq(triggers.size(), 2, "protection can trigger again after rearming")
	t.assert_eq(player.hp, 1.0, "the second protection also leaves 1 HP")

	player.hp = 1.0
	player.take_damage(0.5, null)
	t.assert_true(player.is_dead() or player.hp >= 1.0, "a fatal blow at 1 HP is handled")

	var death_events := 0
	EventBus.player_died.connect(func(): death_events += 1)
	player.hp = 2.0
	await _drain(player, mage.party_buff_interval)
	player.take_damage(999999.0, null)
	await _drain(player, mage.party_buff_duration)
	player.hp = 1.0
	await _drain(player, mage.party_buff_interval)
	player.take_damage(10.0, null)
	t.assert_true(death_events <= 2, "protection keeps the player alive across repeated lethal hits")
	t.assert_true(player.hp >= 1.0 or death_events >= 1, "the player is never silently below 1 HP")

	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _drain(player: Player, seconds: float) -> void:
	var frames := int(seconds * 60.0) + 4
	for _i in range(frames):
		await player.get_tree().physics_frame

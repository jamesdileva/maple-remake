extends RefCounted

func get_suite_name() -> String:
	return "save_system"

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
	DebugManager.god_mode = true

	SaveSystem.delete_save()
	t.assert_false(SaveSystem.has_save(), "no save exists at the start")
	t.assert_true(SaveSystem.load_game().is_empty(), "loading without a save fails cleanly")
	t.assert_eq(SaveSystem.last_error, &"no_save", "missing save reports its reason")

	var blade: EquipmentDefinition = load("res://data/equipment/rusty_blade.tres")
	var cap: EquipmentDefinition = load("res://data/equipment/cloth_cap.tres")
	player.equip(blade)
	player.equip(cap)
	player.add_skill_points(7)
	player.spend_skill_point(player.ability_at(0))
	player.grant_xp(250.0)
	player.inventory.add_currency(93)
	var gel: ItemDefinition = load("res://data/items/slime_gel.tres")
	player.inventory.add_item(gel, 4)
	player.hp = 63.0
	player.mana = 41.0

	var payload: Dictionary = player.capture_state()
	t.assert_eq(payload.level, player.level, "capture records the level")
	t.assert_eq(payload.xp, player.xp, "capture records xp")
	t.assert_eq(payload.currency, player.inventory.currency, "capture records currency")
	t.assert_eq(payload.equipment.weapon, blade.resource_path, "capture records gear by path")
	t.assert_eq(payload.inventory_items.slime_gel, 4, "capture records inventory items")
	t.assert_true(payload.ability_levels.size() > 0, "capture records ability levels")

	var save_error: Error = SaveSystem.save_game(payload)
	t.assert_eq(save_error, OK, "saving succeeds")
	t.assert_true(SaveSystem.has_save(), "the save file exists")

	var loaded: Dictionary = SaveSystem.load_game()
	t.assert_false(loaded.is_empty(), "the save loads back")
	t.assert_eq(loaded.save_version, SaveSystem.version(), "the save records its version")
	t.assert_eq(loaded.level, player.level, "round-trip preserves the level")
	t.assert_eq(loaded.currency, 93, "round-trip preserves currency")

	var reloaded: Player = load("res://scenes/player/player.tscn").instantiate()
	t.root.add_child(reloaded)
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(reloaded.level, 1, "a fresh player starts at level 1")
	t.assert_eq(reloaded.capture_state().level, 1, "fresh player has no save state")

	reloaded.restore_state(loaded)
	t.assert_eq(reloaded.level, player.level, "restored level matches")
	t.assert_eq(reloaded.xp, player.xp, "restored xp matches exactly")
	t.assert_eq(reloaded.inventory.currency, player.inventory.currency, "restored currency matches")
	t.assert_eq(reloaded.equipped_in(&"weapon").id, blade.id, "restored weapon matches")
	t.assert_eq(reloaded.equipped_in(&"helmet").id, cap.id, "restored helmet matches")
	t.assert_eq(reloaded.equipment_power(), player.equipment_power(), "restored power matches")
	t.assert_eq(reloaded.get_defense(), player.get_defense(), "restored defense matches")
	t.assert_eq(reloaded.inventory.item_count(&"slime_gel"), 4, "restored inventory matches")
	t.assert_eq(reloaded.ability_level(player.ability_at(0)), player.ability_level(player.ability_at(0)),
		"restored ability level matches")
	t.assert_eq(reloaded.skill_points, player.skill_points, "restored skill points match")
	t.assert_eq(reloaded.max_hp, player.max_hp, "restored max hp match")
	t.assert_almost_eq(reloaded.hp, player.hp, 0.01, "restored hp matches")

	var second: Dictionary = reloaded.capture_state()
	t.assert_eq(second.level, loaded.level, "re-saved state is stable")
	t.assert_eq(second.xp, loaded.xp, "re-saved xp is stable")
	t.assert_eq(second.currency, loaded.currency, "re-saved currency is stable")
	SaveSystem.save_game(second)
	t.assert_true(SaveSystem.load_game().currency == 93, "a second save round-trips too")

	var foreign := FileAccess.open("user://saves/save.json", FileAccess.WRITE)
	foreign.store_string(JSON.stringify({"save_version": 0, "currency": 5, "level": 2}))
	foreign.close()
	var rejected := SaveSystem.load_game()
	t.assert_eq(SaveSystem.last_error, &"unsupported_version", "version mismatch reports its reason")
	t.assert_eq(rejected.get("loaded_version", -1), 0, "the rejected save preserves its version")
	t.assert_false(SaveSystem.can_load_version(0), "an old version is not loadable")
	t.assert_true(SaveSystem.can_load_version(SaveSystem.version()), "the current version is loadable")

	var corrupt_path := "user://saves/corrupt.json"
	var corrupt := FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt.store_string("{ not json ]")
	corrupt.close()
	var recheck := FileAccess.open(corrupt_path, FileAccess.READ)
	var corrupt_text: String = recheck.get_as_text()
	recheck.close()
	t.assert_true(corrupt_text.contains("not json"), "corrupt file written")
	SaveSystem.load_corrupt_for_test(corrupt_path)
	t.assert_eq(SaveSystem.last_error, &"corrupt_save", "corrupt json reports its reason")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))

	SaveSystem.save_game(payload)
	t.assert_true(SaveSystem.load_game().currency == 93, "a valid save still loads after a bad one")

	var baseline: Dictionary = reloaded.capture_state()
	t.assert_true(baseline.level > 1, "the reloaded player is leveled before the empty restore check")
	reloaded.restore_state({})
	t.assert_eq(reloaded.level, baseline.level, "restoring empty state is a no-op")
	t.assert_eq(reloaded.inventory.currency, baseline.currency, "empty restore leaves currency alone")

	SaveSystem.delete_save()
	t.assert_false(SaveSystem.has_save(), "the save is deleted")

	SaveSystem.delete_save()
	t.assert_false(SaveSystem.has_save(), "the save is deleted")

	reloaded.queue_free()
	DebugManager.god_mode = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

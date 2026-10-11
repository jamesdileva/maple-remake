extends RefCounted

func get_suite_name() -> String:
	return "auto_loot"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = true
	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame

	DebugManager.god_mode = true
	DebugManager.disable_ai = true
	DebugManager.reset_counters()

	var player: Player = world.get_node("Player")
	var inventory := player.get_inventory()
	t.assert_true(inventory != null, "player carries an inventory")
	t.assert_eq(inventory.currency, 0, "inventory starts empty")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")

	var gold: ItemDefinition = load("res://data/items/gold.tres")
	var gel: ItemDefinition = load("res://data/items/slime_gel.tres")
	t.assert_true(gold != null, "gold item definition loads")
	t.assert_true(gel != null, "material item definition loads")
	t.assert_true(gold.is_currency(), "gold is the primary currency")
	t.assert_false(gel.is_currency(), "gel is a material")

	var deterministic := LootTable.new()
	var gold_entry := LootEntry.new()
	gold_entry.item = gold
	gold_entry.weight = 1.0
	gold_entry.min_amount = 2
	gold_entry.max_amount = 2
	deterministic.rolls = 1
	deterministic.entries = [gold_entry]

	var _spawn_mob = func(mob_definition: MobDefinition, position: Vector2) -> Node:
		var spawned: Mob = mob_scene.instantiate()
		spawned.definition = mob_definition
		spawned.global_position = position
		world.add_child(spawned)
		return spawned

	var _drops_count = func() -> int:
		var loot: Node = t.root.get_node_or_null("LootManager")
		return loot.call("active_pickup_count") if loot != null else 0

	var _wait_for_loot = func(target_currency: int, max_frames: int) -> bool:
		for _i in range(max_frames):
			if inventory.currency >= target_currency:
				return true
			await t.physics_frame
		return inventory.currency >= target_currency

	var _wait_for_clear = func(max_frames: int) -> bool:
		for _i in range(max_frames):
			if _drops_count.call() == 0:
				return true
			await t.physics_frame
		return _drops_count.call() == 0

	definition.loot_table = deterministic
	var looted: Array = []
	EventBus.loot_collected.connect(func(item_id: StringName, amount: int):
		looted.append({"item": item_id, "amount": amount}))

	var single: Mob = _spawn_mob.call(definition, Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(inventory.currency, 0, "no loot before the mob dies")

	single.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame
	t.assert_true(_drops_count.call() >= 1, "killing a mob drops loot in the world")
	t.assert_eq(inventory.currency, 0, "loot is not collected before the vacuum starts")

	var collected: bool = await _wait_for_loot.call(2, 120)
	t.assert_true(collected, "loot is collected automatically (currency %d)" % inventory.currency)
	t.assert_eq(inventory.currency, 2, "currency updates by the drop amount")
	t.assert_eq(looted.size(), 1, "one loot event fired")
	if looted.size() == 1:
		t.assert_eq(looted[0].item, gold.id, "the collected item is gold")
	t.assert_true(await _wait_for_clear.call(120), "the pickup is gone after collection")

	definition.loot_table = null
	t.assert_true(definition.loot_table == null, "mobs can drop nothing")

	var no_loot: Mob = _spawn_mob.call(definition, Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	no_loot.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame
	t.assert_eq(_drops_count.call(), 0, "no drops spawn without a table")
	t.assert_eq(inventory.currency, 2, "currency is unchanged by an empty table")

	var multi := LootTable.new()
	var gel_only := LootEntry.new()
	gel_only.item = gel
	gel_only.weight = 1.0
	gel_only.min_amount = 1
	gel_only.max_amount = 1
	var gold_only := LootEntry.new()
	gold_only.item = gold
	gold_only.weight = 0.0
	gold_only.min_amount = 1
	gold_only.max_amount = 1
	multi.rolls = 1
	multi.entries = [gel_only, gold_only]
	definition.loot_table = multi
	var mixed_mob: Mob = _spawn_mob.call(definition, Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var gel_before: int = inventory.item_count(gel.id)
	mixed_mob.take_damage(999999.0, null)
	var gel_collected: bool = false
	for _i in range(60):
		gel_collected = inventory.item_count(gel.id) > gel_before
		if gel_collected:
			break
		await t.physics_frame
	t.assert_true(gel_collected, "a zero-weight entry never drops")
	t.assert_true(await _wait_for_clear.call(120), "weighted tables resolve their drops")

	var both := LootTable.new()
	var gel_entry_two := LootEntry.new()
	gel_entry_two.item = gel
	gel_entry_two.weight = 1.0
	gel_entry_two.min_amount = 3
	gel_entry_two.max_amount = 3
	var gold_entry_two := LootEntry.new()
	gold_entry_two.item = gold
	gold_entry_two.weight = 0.0
	gold_entry_two.min_amount = 1
	gold_entry_two.max_amount = 1
	both.rolls = 1
	both.entries = [gel_entry_two]
	definition.loot_table = both
	var amount_mob: Mob = _spawn_mob.call(definition, Vector2(300.0, -30.0))
	await t.physics_frame
	await t.physics_frame
	var gel_before_amount: int = inventory.item_count(gel.id)
	amount_mob.take_damage(999999.0, null)
	for _i in range(60):
		if inventory.item_count(gel.id) >= gel_before_amount + 3:
			break
		await t.physics_frame
	t.assert_eq(inventory.item_count(gel.id), gel_before_amount + 3, "stackable items collect their full amount")

	definition.loot_table = deterministic
	var currency_before_pack: int = inventory.currency
	var pack: Array = []
	for index in range(40):
		var mob: Mob = _spawn_mob.call(definition, Vector2(-150.0 + float(index) * 6.0, -30.0))
		pack.append(mob)
	await t.physics_frame
	await t.physics_frame
	for mob in pack:
		if is_instance_valid(mob):
			mob.take_damage(999999.0, null)
	var cleared: bool = await _wait_for_loot.call(currency_before_pack + 80, 400)
	t.assert_true(cleared, "a dense pack is fully auto-looted (currency %d of %d)" % [inventory.currency, currency_before_pack + 80])
	t.assert_true(await _wait_for_clear.call(400), "no pickups are left behind after a dense pack")
	var loot_stats: Dictionary = LootManager.stats()
	t.assert_eq(loot_stats.get("active"), 0, "the loot manager returns to idle")

	var loot: Node = t.root.get_node_or_null("LootManager")
	loot.set("max_active_pickups", 3)
	var over_pack: Array = []
	for index in range(12):
		var mob: Mob = _spawn_mob.call(definition, Vector2(-100.0 + float(index) * 4.0, -30.0))
		over_pack.append(mob)
	await t.physics_frame
	await t.physics_frame
	for mob in over_pack:
		if is_instance_valid(mob):
			mob.take_damage(999999.0, null)
	await t.physics_frame
	await t.physics_frame
	t.assert_true(loot.call("active_pickup_count") <= 3, "the pickup cap holds under a drop flood")
	loot.set("max_active_pickups", 240)

	await _wait_for_clear.call(400)
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	LootManager.reset()
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

extends RefCounted

func get_suite_name() -> String:
	return "equipment"

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

	var blade: EquipmentDefinition = load("res://data/equipment/rusty_blade.tres")
	var sword: EquipmentDefinition = load("res://data/equipment/iron_sword.tres")
	var cap: EquipmentDefinition = load("res://data/equipment/cloth_cap.tres")
	var tunic: EquipmentDefinition = load("res://data/equipment/cloth_tunic.tres")
	var pants: EquipmentDefinition = load("res://data/equipment/traveler_pants.tres")
	t.assert_true(blade != null and sword != null, "weapon definitions load from data")
	t.assert_eq(blade.slot_name(), &"weapon", "weapons declare their slot")
	t.assert_eq(cap.slot_name(), &"helmet", "armor declares its slot")
	t.assert_eq(tunic.slot_name(), &"top", "armor declares its slot")
	t.assert_eq(pants.slot_name(), &"bottom", "armor declares its slot")
	t.assert_true(sword.summary().contains("+12 Power"), "item text shows exact power")
	t.assert_true(cap.summary().contains("+10 Max HP"), "item text shows exact hp bonus")
	t.assert_true(sword.summary().contains("Requires Lv 3"), "level requirements are readable")

	var delta := sword.stat_delta(blade)
	t.assert_eq(delta.power, 8.0, "comparison shows the exact power difference")
	t.assert_eq(delta.defense, 0.0, "comparison shows zero deltas where equal")
	var empty_delta := sword.stat_delta(null)
	t.assert_eq(empty_delta.power, 12.0, "comparison against an empty slot shows the full bonus")

	t.assert_eq(player.equipped_in(&"weapon"), null, "fresh characters wear nothing")
	t.assert_eq(player.equipment_power(), 0.0, "power starts at zero")

	var base_hp: float = player.max_hp
	var base_defense: float = player.get_defense()
	var replaced: EquipmentDefinition = player.equip(cap)
	t.assert_eq(replaced, null, "equipping an empty slot replaces nothing")
	t.assert_eq(player.equipped_in(&"helmet"), cap, "equipped item is reported")
	t.assert_eq(player.max_hp, base_hp + 10.0, "max hp grows by exactly the stated bonus")
	t.assert_eq(player.get_defense(), base_defense + 2.0, "defense grows by exactly the stated bonus")

	player.equip(tunic)
	player.equip(pants)
	t.assert_eq(player.max_hp, base_hp + 10.0 + 15.0 + 12.0, "every slot stacks additively and visibly")
	t.assert_eq(player.get_defense(), base_defense + 2.0 + 3.0 + 2.0, "defense stacks additively and visibly")

	player.equip(blade)
	t.assert_eq(player.equipment_power(), 4.0, "weapon power applies")

	var mob_scene: PackedScene = load("res://scenes/mobs/mob.tscn")
	var definition: MobDefinition = load("res://data/mobs/test_slime.tres")
	var unarmed: Mob = mob_scene.instantiate()
	unarmed.definition = definition
	unarmed.global_position = Vector2(400.0, -30.0)
	world.add_child(unarmed)
	await t.physics_frame
	await t.physics_frame
	var unarmed_hp: float = unarmed.hp
	unarmed.take_damage(12.0 + player.equipment_power(), null)
	t.assert_eq(unarmed_hp - unarmed.hp, 16.0, "power adds exactly its stated value to damage")
	unarmed.queue_free()
	await t.physics_frame

	var replaced_blade: EquipmentDefinition = player.equip(sword)
	if player.level >= sword.level_requirement:
		t.assert_eq(replaced_blade, blade, "replacing returns the old item")
		t.assert_eq(player.equipment_power(), 12.0, "power updates to the new weapon")
		t.assert_eq(player.equipped_in(&"weapon"), sword, "the new weapon is worn")
	else:
		t.assert_eq(player.equipment_power(), 4.0, "locked weapons do not equip")

	var high: EquipmentDefinition = sword.duplicate()
	high.level_requirement = 99
	t.assert_eq(player.equip(high), high, "under-leveled equips are refused")
	t.assert_eq(player.equipment_power(), 4.0 if player.level < sword.level_requirement else 12.0,
		"refused equips change nothing")

	var removed: EquipmentDefinition = player.unequip(&"weapon")
	t.assert_true(removed != null, "unequip returns the item")
	t.assert_eq(player.equipped_in(&"weapon"), null, "the slot is empty after unequip")
	t.assert_eq(player.equipment_power(), 0.0, "power drops when the weapon leaves")
	t.assert_eq(player.unequip(&"weapon"), null, "unequipping an empty slot returns null")

	player.equip(removed)
	t.assert_eq(player.equipped_in(&"weapon"), removed, "the same item can be worn again")

	DebugManager.god_mode = true
	player.hp = 50.0
	player.take_damage(999999.0, null)
	await t.physics_frame
	t.assert_true(player.equipped_in(&"helmet") != null, "equipment survives death and respawn")
	t.assert_eq(player.equipment_power(), player.equipment_power(), "power is intact after respawn")
	DebugManager.god_mode = false

	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

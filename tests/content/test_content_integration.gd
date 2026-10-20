extends RefCounted

const GEAR := [
	&"rusty_blade", &"cloth_cap", &"cloth_tunic", &"traveler_pants",
	&"iron_sword", &"leather_vest", &"oaken_shield", &"hunting_bow",
	&"bastard_sword", &"apprentice_staff", &"shadow_dagger", &"ashwood_longbow",
	&"warden_plate", &"blight_helm", &"sanctum_blade", &"sanctum_staff",
]
const BOSSES := [&"briarback_boar", &"mawroot", &"forge_warden", &"blightheart"]
const LOOT_TABLES := [
	&"slime_loot", &"forest_loot", &"elite_loot", &"deep_loot",
	&"boss_hoard", &"boss_hoard_forest", &"boss_hoard_forge", &"boss_hoard_blight",
]

func get_suite_name() -> String:
	return "content_integration"

func run(t) -> void:
	_loot(t)
	_equipment(t)
	_progression(t)
	_tutorial(t)
	await _auto_equip(t)

	t.complete_suite(get_suite_name())

func _loot(t) -> void:
	var gear_sources := {}
	var total_entries := 0
	for table_id: StringName in LOOT_TABLES:
		var table: LootTable = load("res://data/loot/%s.tres" % table_id)
		t.assert_true(table != null, "%s loads" % table_id)
		if table == null:
			continue
		t.assert_true(table.rolls >= 1, "%s rolls at least once" % table_id)
		t.assert_true(not table.entries.is_empty(), "%s has entries" % table_id)
		for entry in table.entries:
			total_entries += 1
			t.assert_true(entry != null and entry.item != null,
				"%s entries point at items" % table_id)
			if entry == null or entry.item == null:
				continue
			t.assert_true(entry.weight > 0.0,
				"%s entry %s can drop" % [table_id, entry.item.id])
			if entry.item is EquipmentDefinition:
				gear_sources[entry.item.id] = true

	t.assert_true(total_entries >= 40, "the loot catalog is broad (%d entries)" % total_entries)
	for gear_id: StringName in GEAR:
		t.assert_true(gear_sources.has(gear_id),
			"%s can drop somewhere in the continent" % gear_id)

func _equipment(t) -> void:
	for gear_id: StringName in GEAR:
		var gear: EquipmentDefinition = load("res://data/equipment/%s.tres" % gear_id)
		t.assert_true(gear != null, "%s loads" % gear_id)
		if gear == null:
			continue
		t.assert_true(gear is ItemDefinition, "%s is lootable" % gear_id)
		t.assert_true(not gear.is_currency(), "%s is not currency" % gear_id)
		t.assert_eq(gear.kind, ItemDefinition.Kind.EQUIPMENT, "%s is equipment" % gear_id)
		t.assert_eq(gear.max_stack, 1, "%s does not stack" % gear_id)
		t.assert_true(gear.display_name.strip_edges() != "", "%s is named" % gear_id)
		t.assert_true(gear.level_requirement >= 1, "%s has a level gate" % gear_id)
		t.assert_true(gear.gear_score() > 0.0, "%s is worth wearing" % gear_id)

	t.assert_eq(load("res://data/equipment/iron_sword.tres").slot_name(), &"weapon",
		"weapons name their slot")
	t.assert_eq(load("res://data/equipment/warden_plate.tres").slot_name(), &"top",
		"armor names its slot")

func _progression(t) -> void:
	var xp_table: XpTable = load("res://data/progression/default_xp.tres")
	t.assert_true(xp_table != null, "the xp curve loads")
	var highest_xp := 0.0
	for level_number in range(1, xp_table.max_level + 1):
		var required := xp_table.xp_for_level(level_number)
		t.assert_true(required >= highest_xp, "level %d costs at least the last" % level_number)
		highest_xp = required

	var mobs_with_loot := 0
	var directory := DirAccess.open("res://data/mobs")
	t.assert_true(directory != null, "mob data is reachable")
	if directory != null:
		for file_name: String in directory.get_files():
			if not file_name.ends_with(".tres"):
				continue
			var loaded := load("res://data/mobs/" + file_name)
			if not (loaded is MobDefinition):
				continue
			var mob := loaded as MobDefinition
			if mob.xp <= 0.0:
				continue
			if mob.loot_table != null:
				mobs_with_loot += 1
	t.assert_true(mobs_with_loot >= 15,
		"most hunting mobs carry loot (%d)" % mobs_with_loot)

	for boss_id: StringName in BOSSES:
		var boss: MobDefinition = load("res://data/bosses/%s.tres" % boss_id)
		t.assert_true(boss != null, "%s loads" % boss_id)
		if boss == null:
			continue
		t.assert_true(boss.loot_table != null, "%s guards a hoard" % boss_id)
		if boss.loot_table != null:
			var has_gear := false
			for entry in boss.loot_table.entries:
				if entry != null and entry.item is EquipmentDefinition:
					has_gear = true
			t.assert_true(has_gear, "%s hoard contains gear" % boss_id)
		t.assert_true(boss.xp >= 200.0, "%s pays xp" % boss_id)

func _tutorial(t) -> void:
	var directory := DirAccess.open("res://data/tutorial")
	t.assert_true(directory != null, "tutorial data is reachable")
	if directory == null:
		return
	var ids := {}
	var count := 0
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var lesson: LessonDefinition = load("res://data/tutorial/" + file_name)
		t.assert_true(lesson != null, "%s loads" % file_name)
		if lesson == null:
			continue
		count += 1
		t.assert_true(not ids.has(lesson.id), "lesson %s is unique" % lesson.id)
		ids[lesson.id] = true
		t.assert_true(lesson.title.strip_edges() != "", "%s has a title" % lesson.id)
		t.assert_true(lesson.detail.strip_edges() != "", "%s explains itself" % lesson.id)
	t.assert_eq(count, 10, "the tutorial teaches ten lessons")

func _auto_equip(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var player: Player = world.get_node("Player")
	var rusty: EquipmentDefinition = load("res://data/equipment/rusty_blade.tres")
	var iron: EquipmentDefinition = load("res://data/equipment/iron_sword.tres")
	var cap: EquipmentDefinition = load("res://data/equipment/cloth_cap.tres")

	t.assert_eq(player.receive_loot(rusty, 1), 1, "picked up gear is consumed")
	t.assert_eq(player.equipped_in(&"weapon"), rusty, "the first weapon is worn immediately")
	t.assert_eq(player.inventory.item_count(rusty.id), 0, "worn gear leaves the inventory")

	t.assert_eq(player.receive_loot(cap, 1), 1, "armor is picked up")
	t.assert_eq(player.equipped_in(&"helmet"), cap, "empty slots fill automatically")

	t.assert_eq(player.receive_loot(iron, 1), 1, "under-leveled gear is still picked up")
	t.assert_eq(player.equipped_in(&"weapon"), rusty, "under-leveled gear does not replace")
	t.assert_true(player.stashed_gear.has(iron), "under-leveled gear waits in the stash")

	var captured := player.capture_state()
	var stash: Array = captured.get("stashed_gear", [])
	t.assert_eq(stash.size(), 1, "the stash is part of the save")
	t.assert_eq(stash[0], iron.resource_path, "the save records the stashed item")

	player.set_level(iron.level_requirement)
	player._apply_level_stats()
	t.assert_eq(player.equipped_in(&"weapon"), iron, "leveling up wears the better weapon")
	t.assert_true(not player.stashed_gear.has(iron), "the stash empties when gear is worn")
	t.assert_true(player.stashed_gear.has(rusty), "the old weapon is kept in the stash")

	var power_before := player.equipment_power()
	player.receive_loot(rusty, 1)
	t.assert_eq(player.equipment_power(), power_before, "a worse duplicate changes nothing")
	t.assert_eq(player.equipped_in(&"weapon"), iron, "the better weapon stays worn")

	world.queue_free()
	await t.physics_frame

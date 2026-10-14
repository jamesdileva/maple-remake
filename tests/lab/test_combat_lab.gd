extends RefCounted

func get_suite_name() -> String:
	return "combat_lab"

func run(t) -> void:
	var scene: PackedScene = load("res://scenes/lab/combat_lab.tscn")
	t.assert_true(scene != null, "combat lab scene loads")
	var lab_root: Node2D = scene.instantiate()
	t.root.add_child(lab_root)
	t.register_world(lab_root)
	await t.physics_frame
	await t.physics_frame

	var lab: CombatLab = lab_root.get_node("Lab")
	t.assert_true(lab != null, "lab controller exists")
	var player: Player = lab_root.get_node("Player")
	t.assert_true(player != null, "lab ships a player")

	for control_name in ["ClassOption", "LevelOption", "GearOption", "MobOption", "CountOption",
			"SpawnButton", "KillButton", "ResetButton", "ManaButton", "GodButton"]:
		var control: Control = lab.get_node("LabUI/Panel/VBox/%s" % control_name)
		t.assert_true(control != null and control.focus_mode == Control.FOCUS_ALL,
			"%s is joypad-focusable" % control_name)
	var boss_option: OptionButton = lab.get_node("LabUI/Panel/VBox/BossOption")
	t.assert_false(boss_option.disabled, "boss selector is live now a benchmark exists")
	t.assert_true(boss_option.item_count == 2, "boss selector lists none plus the benchmark")
	t.assert_eq(boss_option.get_item_text(1), "Benchmark Construct", "the benchmark construct is selectable")
	t.assert_true(lab.lab_mob_count() == 0, "no boss is alive yet")
	boss_option.select(1)
	DebugManager.god_mode = true
	var bossed: int = lab.spawn()
	t.assert_eq(bossed, 1, "spawn with a boss selected places the construct")
	t.assert_true(lab.lab_mob_count() == 1, "the construct is tracked")
	var benchmark: Mob = null
	for mob: Object in t.get_nodes_in_group("enemies"):
		if is_instance_valid(mob) and mob.mob_id() == &"benchmark_construct":
			benchmark = mob
	t.assert_true(benchmark != null, "the tracked construct is a real enemy")
	t.assert_true(benchmark.definition.is_boss, "the construct is boss-flagged")
	await t.physics_frame
	await t.physics_frame
	t.assert_true(lab.meter.is_boss_running(), "boss timing starts while the construct lives")
	var killed_boss: int = lab.kill()
	t.assert_true(killed_boss >= 1, "kill removes the construct (%d)" % killed_boss)
	lab.reset_encounter()
	t.assert_eq(lab.lab_mob_count(), 0, "reset clears the construct")
	await t.physics_frame
	await t.physics_frame
	t.assert_false(lab.meter.is_boss_running(), "boss timing stops once the construct is gone")
	boss_option.select(0)

	var player_before: Player = player
	t.assert_true(lab.set_level(10), "lab sets the level")
	t.assert_eq(player.level, 10, "the player reaches the lab level")
	t.assert_eq(player.hp, player.max_hp, "leveling in the lab heals")
	t.assert_true(lab.set_gear("res://data/equipment/iron_sword.tres"), "lab equips gear")
	t.assert_eq(player.equipped_in(&"weapon").id, &"iron_sword", "the weapon is worn")
	t.assert_true(lab.set_gear(""), "lab clears gear")
	t.assert_eq(player.equipped_in(&"weapon"), null, "the slot empties")

	var switched := ClassDefinition.new()
	switched.id = &"squire"
	switched.display_name = "Squire"
	var fire: AbilityDefinition = load("res://data/abilities/mage_fire.tres")
	switched.ability_slots = [fire]
	t.assert_true(lab.set_class(switched), "lab switches class")
	t.assert_true(player == player_before and is_instance_valid(player), "no scene reload on class switch")
	t.assert_eq(player.ability_at(0).id, &"mage_fire", "the new kit is live immediately")
	var mage: ClassDefinition = load("res://data/classes/mage.tres")
	t.assert_true(lab.set_class(mage), "lab switches back to mage")
	t.assert_eq(player.ability_at(0).id, &"mage_fire", "the mage kit is restored")

	DebugManager.god_mode = true
	var spawned: int = lab.spawn()
	t.assert_true(spawned >= 1, "spawn creates mobs (%d)" % spawned)
	t.assert_true(lab.lab_mob_count() >= 1, "spawned mobs are tracked")
	var killed: int = lab.kill()
	t.assert_true(killed >= 1, "kill removes enemies (%d)" % killed)
	lab.reset_encounter()
	t.assert_eq(lab.lab_mob_count(), 0, "reset clears tracked mobs")
	t.assert_eq(player.hp, player.max_hp, "reset heals the player")

	var spawn_button: Button = lab.get_node("LabUI/Panel/VBox/SpawnButton")
	spawn_button.pressed.emit()
	await t.physics_frame
	t.assert_true(lab.lab_mob_count() >= 1, "the spawn button is wired to spawning")
	lab.reset_encounter()

	DebugManager.god_mode = false
	lab_root.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

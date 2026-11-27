extends RefCounted

## Sprint 18.4 MVP freeze guard. Pins the frozen content inventories and
## core values from docs/mvp-freeze.md. Any addition or removal fails
## here, making a freeze break deliberate.

const FREEZE_VERSION := 1

const FROZEN_CLASSES := ["archer", "assassin", "mage", "warrior"]
const FROZEN_BOSSES := ["blightheart", "briarback_boar", "forge_warden", "mawroot"]
const FROZEN_CONTINENT := [
	"blightheart_sanctum", "brightwood_outskirts", "forgotten_mine",
	"haunted_fortress", "hollow_forest", "ruined_settlement",
	"sunlit_meadow", "test_a", "test_b", "thornhollow_ring",
	"whispering_forest",
]
const FROZEN_LOOT := [
	"boss_hoard", "boss_hoard_blight", "boss_hoard_forest", "boss_hoard_forge",
	"deep_loot", "elite_loot", "forest_loot", "slime_loot",
]
const FROZEN_ITEMS := ["gold", "slime_gel"]

func get_suite_name() -> String:
	return "mvp_freeze"

func run(t) -> void:
	t.assert_eq(FREEZE_VERSION, 1, "the freeze version is current (bump to break consciously)")

	var class_files := _file_names("res://data/classes/")
	t.assert_eq(class_files, FROZEN_CLASSES, "classes are frozen (Mage/Warrior/Archer/Assassin)")
	var boss_files := _file_names("res://data/bosses/")
	for boss_id: String in FROZEN_BOSSES:
		t.assert_true(boss_files.has(boss_id), "the frozen boss %s exists" % boss_id)
	var map_files := _file_names("res://data/maps/")
	t.assert_eq(map_files, FROZEN_CONTINENT, "the continent is frozen")
	var loot_files := _file_names("res://data/loot/")
	var loot_stems: Array = []
	for file_name: String in loot_files:
		loot_stems.append(file_name.trim_suffix(".tres"))
	t.assert_eq(loot_stems, FROZEN_LOOT, "the loot tables are frozen")
	var item_files := _file_names("res://data/items/")
	t.assert_eq(item_files, FROZEN_ITEMS, "the items are frozen")

	var ability_count := _count_tres("res://data/abilities/")
	var mob_count := _count_tres("res://data/mobs/")
	var gear_count := _count_tres("res://data/equipment/")
	t.assert_true(ability_count > 0 and mob_count > 0 and gear_count == 16,
		"abilities (%d) and mobs (%d) exist; equipment stays at 16 pieces" % [ability_count, mob_count])

	var xp_table := load("res://data/progression/default_xp.tres")
	t.assert_eq(int(xp_table.get("max_level")), 50, "the level cap is frozen at 50")
	t.assert_almost_eq(float(xp_table.get("growth")), 1.3, 0.001, "the xp growth is frozen at 1.30")
	t.assert_almost_eq(float(xp_table.get("base_xp")), 250.0, 0.001, "the xp base is frozen at 250")
	t.assert_eq(SaveSystem.version(), 1, "the save format is frozen at version 1")

	var blightheart := load("res://data/bosses/blightheart.tres")
	t.assert_true(bool(blightheart.get("is_final")), "blightheart remains the final boss")
	var mage := load("res://data/classes/mage.tres")
	t.assert_eq(int(mage.get("advancement_level")), 20, "advancement stays at level 20")

	var roadmap := _read("res://docs/sprint-roadmap.md")
	t.assert_true(roadmap.contains("# Deferred Post-MVP"), "the deferred list ships with the freeze")
	t.assert_true(roadmap.contains("multiplayer"), "multiplayer stays deferred")
	t.assert_true(roadmap.contains("boss checkpoints"), "boss checkpoints stay deferred")

	t.complete_suite(get_suite_name())

func _file_names(directory_path: String) -> Array:
	var names: Array = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return names
	for file_name: String in directory.get_files():
		if file_name.ends_with(".tres"):
			names.append(file_name.trim_suffix(".tres"))
	names.sort()
	return names

func _count_tres(directory_path: String) -> int:
	return _file_names(directory_path).size()

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text

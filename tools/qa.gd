extends SceneTree

## Sprint 16.1 automated-QA gate: runs the canonical suite once and reports
## the roadmap QA categories (combat, progression, save, loot, boss) plus
## content and infrastructure. Exits 0 only when every suite passes.
##   godot --headless --script tools/qa.gd

const CATEGORIES := {
	"combat": [
		"damage_system", "fma", "player_ability", "weapon_swap", "mob",
		"chain_mobs", "mob_density", "party_simulation", "power_budget",
		"stress", "combat_lab", "damage_meter",
	],
	"progression": [
		"xp_leveling", "skill_points", "equipment", "tutorial", "fresh_player",
		"mage_class", "mage_advancement", "mage_party_buff", "warrior_class",
		"warrior_advancement", "warrior_party_buff", "archer_class",
		"archer_advancement_buff", "assassin_class", "assassin_advancement",
		"assassin_party_buff", "crossbow",
	],
	"save": ["save_system"],
	"loot": ["auto_loot", "boss_hoards"],
	"boss": [
		"boss_framework", "first_boss", "final_boss", "boss_roster",
		"boss_benchmark", "boss_balance",
	],
	"content": [
		"content_integration", "mob_roster", "map_framework", "first_map",
		"continent", "map_integration", "floor_integrity",
	],
	"infrastructure": [
		"debug_manager", "input_bindings", "player_movement", "art_pipeline",
		"environment_kits", "class_vfx", "pacing_machinery",
	],
}

func _initialize() -> void:
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(),
		["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/run_tests.gd"],
		output, true)
	var results := {}
	var current := ""
	var blob := "\n".join(PackedStringArray(output))
	for line: String in blob.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.begins_with("--- suite: "):
			current = trimmed.trim_prefix("--- suite: ")
			continue
		if trimmed.begins_with("--- ") and (trimmed.ends_with(" PASS") or trimmed.ends_with(" FAIL")):
			var parts := trimmed.trim_prefix("--- ").rsplit(" ", true, 1)
			if parts.size() == 2 and current != "":
				results[parts[0].trim_suffix(":")] = parts[1]
	var matrix := {}
	var unmapped: Array[String] = []
	for suite_name: String in results:
		var bucket := ""
		for category: String in CATEGORIES:
			if suite_name in CATEGORIES[category]:
				bucket = category
				break
		if bucket == "":
			unmapped.append(suite_name)
			bucket = "uncategorized"
		if not matrix.has(bucket):
			matrix[bucket] = {"pass": 0, "fail": 0, "failed": []}
		if results[suite_name] == "PASS":
			matrix[bucket]["pass"] += 1
		else:
			matrix[bucket]["fail"] += 1
			matrix[bucket]["failed"].append(suite_name)
	print("qa: automated QA gate")
	for category: String in CATEGORIES:
		if not matrix.has(category):
			print("qa: %-15s MISSING SUITES (mapping is stale)" % category)
			continue
		var entry: Dictionary = matrix[category]
		var verdict := "PASS" if int(entry["fail"]) == 0 else "FAIL"
		print("qa: %-15s %s (%d pass, %d fail%s)" % [category, verdict,
			int(entry["pass"]), int(entry["fail"]),
			": " + ", ".join(PackedStringArray(entry["failed"])) if int(entry["fail"]) > 0 else ""])
	if not unmapped.is_empty():
		print("qa: uncategorized suites: " + ", ".join(PackedStringArray(unmapped)))
	var failures := int(exit_code != 0)
	for category: String in matrix:
		if int(matrix[category]["fail"]) > 0:
			failures += 1
	print("qa: GATE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

extends SceneTree

const TEST_SUITES := [
	"res://tests/debug/test_debug_manager.gd",
	"res://tests/input/test_input_bindings.gd",
	"res://tests/player/test_player_movement.gd",
	"res://tests/abilities/test_player_ability.gd",
	"res://tests/abilities/test_fma.gd",
	"res://tests/combat/test_damage_system.gd",
	"res://tests/density/test_spawn_manager.gd",
	"res://tests/density/test_chain_mobs.gd",
	"res://tests/loot/test_auto_loot.gd",
	"res://tests/progression/test_xp_leveling.gd",
	"res://tests/progression/test_skill_points.gd",
	"res://tests/progression/test_equipment.gd",
	"res://tests/progression/test_save_system.gd",
	"res://tests/classes/test_mage.gd",
	"res://tests/classes/test_mage_advancement.gd",
	"res://tests/classes/test_mage_party_buff.gd",
	"res://tests/classes/test_warrior_class.gd",
	"res://tests/classes/test_warrior_advancement.gd",
	"res://tests/lab/test_combat_lab.gd",
	"res://tests/lab/test_damage_meter.gd",
	"res://tests/lab/test_stress.gd",
	"res://tests/entities/test_mob.gd",
]

var _checks := 0
var _failures := 0
var _completed_suites: Array = []
var _worlds: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	for suite_path: String in TEST_SUITES:
		var script: GDScript = load(suite_path)
		if script == null:
			printerr("FAIL: cannot load test suite ", suite_path)
			_failures += 1
			continue
		var suite: RefCounted = script.new()
		print("--- suite: %s" % suite.get_suite_name())
		var failures_before := _failures
		var completed_before := _completed_suites.size()
		await suite.run(self)
		if _completed_suites.size() == completed_before:
			_failures += 1
			printerr("FAIL: suite aborted before completion: ", suite_path)
		_reset_input_state()
		_reset_debug_flags()
		await _cleanup_worlds()
		_reset_spawner()
		print("--- %s: %s" % [suite.get_suite_name(), "PASS" if _failures == failures_before else "FAIL"])
	print("")
	print("TOTAL: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	var manager: Node = root.get_node_or_null("DebugManager")
	if manager != null and manager._log != null:
		manager._log.close()
	quit(1 if _failures > 0 else 0)

func _reset_input_state() -> void:
	for action_name: String in [
		"move_left", "move_right", "move_up", "move_down",
		"jump", "attack", "interact",
		"skill_1", "skill_2", "skill_3", "skill_4",
	]:
		if InputMap.has_action(action_name):
			Input.action_release(action_name)

func _reset_debug_flags() -> void:
	var manager: Node = root.get_node_or_null("DebugManager")
	if manager == null:
		return
	for flag: String in ["god_mode", "force_crit", "infinite_mana", "disable_ai"]:
		manager.set(flag, false)

func _reset_spawner() -> void:
	var spawner: Node = root.get_node_or_null("SpawnManager")
	if spawner != null and spawner.has_method("reset"):
		spawner.reset()

func complete_suite(suite_name: String) -> void:
	_completed_suites.append(suite_name)

func register_world(world: Node) -> void:
	_worlds.append(world)

func _cleanup_worlds() -> void:
	var had_worlds := not _worlds.is_empty()
	for world in _worlds:
		if is_instance_valid(world):
			world.queue_free()
	_worlds.clear()
	if had_worlds:
		await physics_frame

func assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		printerr("FAIL: %s (expected %s, got %s)" % [message, str(expected), str(actual)])

func assert_almost_eq(actual: float, expected: float, tolerance: float, message: String) -> void:
	_checks += 1
	if abs(actual - expected) > tolerance:
		_failures += 1
		printerr("FAIL: %s (expected ~%s, got %s)" % [message, expected, actual])

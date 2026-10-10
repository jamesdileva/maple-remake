extends SceneTree

const TEST_SUITES := [
	"res://tests/debug/test_debug_manager.gd",
	"res://tests/input/test_input_bindings.gd",
]

var _checks := 0
var _failures := 0

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
		await suite.run(self)
		print("--- %s: %s" % [suite.get_suite_name(), "PASS" if _failures == failures_before else "FAIL"])
	print("")
	print("TOTAL: %d checks, %d failures" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	var manager: Node = root.get_node_or_null("DebugManager")
	if manager != null and manager._log != null:
		manager._log.close()
	quit(1 if _failures > 0 else 0)

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

extends SceneTree

## Sprint 15.2 on-demand full playthrough. Runs every class through the
## real game scene and writes the pacing report:
##   godot --headless --script tools/pacing_report.gd
##   godot --headless --script tools/pacing_report.gd -- --class=mage --out=user://debug/pacing

const DEFAULT_CLASSES: Array[StringName] = [&"mage", &"warrior", &"archer", &"assassin"]
const BOT_SCRIPT := "res://tests/pacing/pacing_bot.gd"
const WRITER_SCRIPT := "res://tests/pacing/pacing_report_writer.gd"

func _initialize() -> void:
	Engine.time_scale = 10.0
	Engine.max_physics_steps_per_frame = 64
	var requested: Array[StringName] = []
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			requested.append(StringName(arg.trim_prefix("--class=")))
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var wanted := requested if requested.size() > 0 else DEFAULT_CLASSES
	var bot_script: GDScript = load(BOT_SCRIPT)
	var writer_script: GDScript = load(WRITER_SCRIPT)
	var results := []
	var all_completed := true
	for class_id: StringName in wanted:
		print("pacing_report: booting a fresh %s playthrough" % String(class_id))
		var bot = bot_script.new()
		var summary: Dictionary = await bot.run_playthrough(self, class_id)
		results.append(summary)
		print("pacing_report: %s finished=%s game_hours=%.2f final_level=%d" % [
			String(class_id), str(summary.get("completed", false)),
			float(summary.get("game_seconds", 0.0)) / 3600.0,
			int(summary.get("final_level", 0))])
		if not bool(summary.get("completed", false)):
			all_completed = false
	var writer = writer_script.new()
	var report: Dictionary = writer.write(results, out_dir)
	print("pacing_report: json -> %s" % report["json_path"])
	print("pacing_report: md   -> %s" % report["md_path"])
	print("pacing_report: findings:")
	for finding: String in report["findings"]:
		print("  - %s" % finding)
	quit(0 if all_completed else 1)

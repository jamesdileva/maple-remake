class_name PacingReportWriter
extends RefCounted

## Turns PacingBot run summaries into the sprint 15.2 pacing report:
## time, friction, boring sections, overpowered sections, plus a verdict
## against the 10-20 hour first-continent goal. Grind minutes on `levels`
## entries are extrapolated from sampled xp/sec, not ticked through.

const EQUIPMENT_DIR := "res://data/equipment/"
const TARGET_HOURS_LOW := 10.0
const TARGET_HOURS_HIGH := 20.0
const OP_TTK_SECONDS := 0.4
const OP_BOSS_SECONDS := 10.0
const BORING_MINUTES_PER_LEVEL := 6.0
const FRICTION_DEATHS := 2
const FRICTION_BOSS_DEATHS := 2
const FRICTION_MANA_SHARE := 0.3
const FRICTION_NAVIGATION := 3
const WALL_MINUTES_PER_LEVEL := 20.0
const ADVANCEMENT_LEVEL := 20

func write(results: Array, out_dir := "") -> Dictionary:
	var gear := _gear_unlock_levels()
	var analysis := _analyze(results, gear)
	var dir := out_dir if out_dir != "" else "user://debug"
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := _stamp()
	var json_path := "%s/pacing_report_%s.json" % [dir, stamp]
	var md_path := "%s/pacing_report_%s.md" % [dir, stamp]
	var document := {
		"generated": Time.get_datetime_string_from_system(),
		"target_hours": [TARGET_HOURS_LOW, TARGET_HOURS_HIGH],
		"grain": "combat/travel/boss timings are sampled from real play; level-up minutes are extrapolated from sampled xp/sec",
		"classes": analysis["classes"],
		"findings": analysis["findings"],
	}
	_write_file(json_path, JSON.stringify(document, "  "))
	_write_file(md_path, _render_markdown(document))
	analysis["json_path"] = json_path
	analysis["md_path"] = md_path
	return analysis

func _analyze(results: Array, gear: Dictionary) -> Dictionary:
	var classes := []
	var findings := []
	for result: Dictionary in results:
		classes.append(_analyze_class(result, gear, findings))
	for result: Dictionary in results:
		for note: String in result.get("notes", []):
			findings.append("%s: %s" % [result.get("class", "?"), note])
	_findings_from_flags(classes, findings)
	_findings_from_walls(classes, findings)
	return {"classes": classes, "findings": findings}

func _analyze_class(result: Dictionary, gear: Dictionary, findings: Array) -> Dictionary:
	var hours: float = float(result.get("game_seconds", 0.0)) / 3600.0
	var segments := []
	var curve := []
	var cumulative := 0.0
	for segment: Dictionary in result.get("segments", []):
		var enriched := segment.duplicate(true)
		enriched["flags"] = _segment_flags(segment, gear)
		enriched["ttk"] = _ttk(segment)
		segments.append(enriched)
		for entry: Dictionary in segment.get("levels", []):
			cumulative += float(entry.get("minutes", 0.0))
			curve.append({
				"map": segment.get("map", ""),
				"level": int(entry.get("level", 0)),
				"minutes": float(entry.get("minutes", 0.0)),
				"cumulative_minutes": cumulative,
			})
	var verdict := _verdict(hours, bool(result.get("completed", false)))
	findings.append("%s: %.1f estimated game hours, %s" % [result.get("class", "?"), hours, verdict])
	return {
		"class": result.get("class", "?"),
		"completed": bool(result.get("completed", false)),
		"game_hours": hours,
		"verdict": verdict,
		"final_level": int(result.get("final_level", 0)),
		"advancement": result.get("advancement", {}),
		"segments": segments,
		"level_curve": curve,
		"total_farm_minutes": cumulative,
	}

func _segment_flags(segment: Dictionary, gear: Dictionary) -> Array:
	var flags := []
	var sample: Dictionary = segment.get("sample", {})
	if not bool(sample.get("skipped", false)):
		var ttk := _ttk(segment)
		if ttk > 0.0 and ttk < OP_TTK_SECONDS:
			flags.append("overpowered ttk %.2fs" % ttk)
		if float(sample.get("mana_downtime_seconds", 0.0)) / maxf(float(sample.get("game_seconds", 0.0)), 0.1) > FRICTION_MANA_SHARE:
			flags.append("friction mana downtime")
		if float(sample.get("xp_per_sec", 0.0)) <= 0.0:
			flags.append("friction no farmable progress")
	for entry: Dictionary in segment.get("levels", []):
		var minutes := float(entry.get("minutes", 0.0))
		if minutes > WALL_MINUTES_PER_LEVEL:
			flags.append("wall lv %d at %.0f min/level" % [int(entry.get("level", 0)), minutes])
		elif minutes > BORING_MINUTES_PER_LEVEL and _unlocks_for_level(segment, int(entry.get("level", 0)), gear).is_empty():
			flags.append("boring lv %d at %.1f min/level" % [int(entry.get("level", 0)), minutes])
	var boss: Dictionary = segment.get("boss", {}) if segment.get("boss") != null else {}
	if not boss.is_empty():
		if bool(boss.get("killed", false)) and float(boss.get("kill_seconds", 0.0)) < OP_BOSS_SECONDS:
			flags.append("overpowered boss %.1fs" % float(boss.get("kill_seconds", 0.0)))
		if int(boss.get("deaths", 0)) >= FRICTION_BOSS_DEATHS:
			flags.append("friction boss deaths %d" % int(boss.get("deaths", 0)))
	if int(segment.get("deaths", 0)) >= FRICTION_DEATHS:
		flags.append("friction deaths %d" % int(segment.get("deaths", 0)))
	if int(segment.get("stuck", 0)) + int(segment.get("assists", 0)) >= FRICTION_NAVIGATION:
		flags.append("friction navigation %d" % (int(segment.get("stuck", 0)) + int(segment.get("assists", 0))))
	if int(segment.get("accidental_travels", 0)) > 0:
		flags.append("friction accidental travels %d" % int(segment.get("accidental_travels", 0)))
	return flags

func _ttk(segment: Dictionary) -> float:
	var sample: Dictionary = segment.get("sample", {})
	var dps := float(sample.get("dps", 0.0))
	if dps <= 0.0:
		return 0.0
	return float(segment.get("avg_mob_hp", 0.0)) / dps

func _unlocks_for_level(segment: Dictionary, level: int, gear: Dictionary) -> Array:
	var unlocks: Array = gear.get(level, [])
	if level == ADVANCEMENT_LEVEL:
		unlocks.append("advancement")
	if segment.get("boss") != null:
		unlocks.append("boss")
	return unlocks

func _verdict(hours: float, completed: bool) -> String:
	if not completed:
		return "run did not reach the final boss"
	if hours < TARGET_HOURS_LOW:
		return "below the 10-20h target"
	if hours > TARGET_HOURS_HIGH:
		return "above the 10-20h target"
	return "within the 10-20h target"

func _findings_from_flags(classes: Array, findings: Array) -> void:
	for entry: Dictionary in classes:
		for segment: Dictionary in entry.get("segments", []):
			for flag: String in segment.get("flags", []):
				findings.append("%s %s: %s" % [entry.get("class", "?"), segment.get("map", "?"), flag])

func _findings_from_walls(classes: Array, findings: Array) -> void:
	var walls := []
	for entry: Dictionary in classes:
		for segment: Dictionary in entry.get("segments", []):
			for flag: String in segment.get("flags", []):
				if flag.begins_with("wall"):
					walls.append("%s %s: %s" % [entry.get("class", "?"), segment.get("map", "?"), flag])
	walls.sort()
	walls.reverse()
	for index in range(mini(5, walls.size())):
		findings.insert(index, walls[index])

func _gear_unlock_levels() -> Dictionary:
	var by_level := {}
	var directory := DirAccess.open(EQUIPMENT_DIR)
	if directory == null:
		return by_level
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var item := load(EQUIPMENT_DIR + file_name) as EquipmentDefinition
		if item == null:
			continue
		if not by_level.has(item.level_requirement):
			by_level[item.level_requirement] = []
		by_level[item.level_requirement].append(String(item.id))
	return by_level

func _stamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace(" ", "_")

func _write_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()

func _render_markdown(document: Dictionary) -> String:
	var lines := []
	lines.append("# Sprint 15.2 - Automated Pacing Report")
	lines.append("")
	lines.append("Generated %s. %s." % [document["generated"], document["grain"]])
	lines.append("")
	lines.append("## Verdict vs the 10-20h first-continent target")
	lines.append("")
	lines.append("| class | estimated hours | final level | completed | verdict |")
	lines.append("|---|---|---|---|---|")
	for entry: Dictionary in document["classes"]:
		lines.append("| %s | %.1f | %d | %s | %s |" % [entry["class"], float(entry["game_hours"]),
			int(entry["final_level"]), str(entry["completed"]), str(entry["verdict"])])
	lines.append("")
	for entry: Dictionary in document["classes"]:
		lines.append("## %s" % str(entry["class"]))
		lines.append("")
		lines.append("| map | rec lv | arrival | target | transit s | travel | xp/s | dps | ttk s | kills | deaths | boss | loot | flags |")
		lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for segment: Dictionary in entry["segments"]:
			var sample: Dictionary = segment.get("sample", {})
			var boss_text := "-"
			if segment.get("boss") != null:
				var boss: Dictionary = segment["boss"]
				if bool(boss.get("killed", false)):
					boss_text = "%s kill %.1fs/%d attempts/%d deaths" % [boss.get("id", "?"),
						float(boss.get("kill_seconds", 0.0)), int(boss.get("attempts", 0)), int(boss.get("deaths", 0))]
				else:
					boss_text = "%s WALL %d attempts/%d deaths" % [boss.get("id", "?"),
						int(boss.get("attempts", 0)), int(boss.get("deaths", 0))]
			var flags := segment.get("flags", []) as Array
			var flags_text := ", ".join(PackedStringArray(flags)) if flags.size() > 0 else "-"
			lines.append("| %s | %d | %d | %d | %.1f | %s | %.1f | %.0f | %.2f | %d | %d | %s | %d | %s |" % [
				str(segment.get("map", "?")), int(segment.get("recommended_level", 0)),
				int(segment.get("arrival_level", 0)), int(segment.get("target_level", 0)),
				float(segment.get("transit_seconds", 0.0)), str(segment.get("travel_method", "?")),
				float(sample.get("xp_per_sec", 0.0)), float(sample.get("dps", 0.0)), float(segment.get("ttk", 0.0)),
				int(sample.get("kills", 0)), int(segment.get("deaths", 0)), boss_text,
				(segment.get("loot", []) as Array).size(), flags_text])
		lines.append("")
		lines.append("### Extrapolated level curve")
		lines.append("")
		lines.append("| map | level | minutes this level | cumulative minutes |")
		lines.append("|---|---|---|---|")
		for row: Dictionary in entry["level_curve"]:
			lines.append("| %s | %d | %.1f | %.0f |" % [str(row["map"]), int(row["level"]),
				float(row["minutes"]), float(row["cumulative_minutes"])])
		lines.append("")
	lines.append("## Findings")
	lines.append("")
	for index in range(document["findings"].size()):
		lines.append("%d. %s" % [index + 1, str(document["findings"][index])])
	lines.append("")
	lines.append("## Thresholds")
	lines.append("")
	lines.append("- overpowered: mob ttk < %.1fs, boss kill < %.0fs" % [OP_TTK_SECONDS, OP_BOSS_SECONDS])
	lines.append("- boring: > %.0f min/level with no gear/advancement/boss unlock" % BORING_MINUTES_PER_LEVEL)
	lines.append("- friction: >= %d deaths, >= %d boss deaths, mana downtime > %d%%, navigation events >= %d" % [
		FRICTION_DEATHS, FRICTION_BOSS_DEATHS, int(FRICTION_MANA_SHARE * 100.0), FRICTION_NAVIGATION])
	lines.append("- wall: > %.0f min for a single level" % WALL_MINUTES_PER_LEVEL)
	lines.append("")
	return "\n".join(lines)

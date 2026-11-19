class_name PacingBot
extends RefCounted

## Plays a full continent run headlessly for the sprint 15.2 pacing report.
## Travel, combat sampling, bosses and advancement are real; the repetitive
## grind between level milestones is extrapolated from measured xp/sec and
## labeled as simulated in the report.

const GAME_SCENE := "res://scenes/game/game.tscn"
const BOSS_SCENE := "res://scenes/bosses/boss.tscn"
const ARENA_BOSS := "res://data/bosses/briarback_boar.tres"
const CHAIN: Array[StringName] = [
	&"brightwood_outskirts", &"sunlit_meadow", &"whispering_forest",
	&"hollow_forest", &"forgotten_mine", &"ruined_settlement",
	&"haunted_fortress", &"blightheart_sanctum",
]
const ARENA_MAP := &"thornhollow_ring"
const ARENA_INSERT_AFTER := &"hollow_forest"

const SAMPLE_KILLS := 25
const SAMPLE_GAME_SECONDS := 30.0
const WALK_GAME_SECONDS := 60.0
const BOSS_GAME_SECONDS := 120.0
const BOSS_ATTEMPTS_CAP := 3
const GRANT_CHUNK_SECONDS := 4.0
const MIN_XP_PER_SEC := 1.0
const ARRIVE_SLACK_PX := 24.0
const TARGET_DY := 120.0
const STUCK_CHECK_FRAMES := 45
const STUCK_PROGRESS_PX := 16.0
const STUCK_JUMPS_CAP := 3
const JUMP_HOLD_FRAMES := 12
const FALL_ABORT_Y := 400.0
const SETTLE_FRAMES := 40
const THREAT_RANGE_PX := 130.0
const PORTAL_GUARD_PX := 170.0

static func cap_frames(game_seconds: float) -> int:
	return int(game_seconds * 60.0 / maxf(Engine.time_scale, 0.1))

var tree: SceneTree
var player: Player
var world: Node2D
var game: Node2D

var _game_seconds := 0.0
var _run_class := ""
var _segment: Dictionary = {}
var _seen_mobs := {}
var _ledger := {}
var _portal_links := {}
var _advancement := {"advanced": false, "level": 0}
var _fight_map: StringName = &""
var _portal_x_values: Array = []

static func minutes_for_xp(need: float, rate: float) -> float:
	return need / maxf(rate, MIN_XP_PER_SEC) / 60.0

func run_playthrough(scene_tree: SceneTree, class_id: StringName) -> Dictionary:
	tree = scene_tree
	_game_seconds = 0.0
	_run_class = String(class_id)
	_seen_mobs = {}
	_portal_links = {}
	_ledger = {"kills": 0, "xp": 0.0, "boss_kills": [], "completed": false}
	var summary := {
		"class": String(class_id),
		"completed": false,
		"game_seconds": 0.0,
		"segments": [],
		"advancement": _advancement,
		"notes": [],
		"final_level": 0,
	}
	if not await _boot(class_id):
		summary["notes"].append("boot failed: class picker or player missing")
		summary["game_seconds"] = _game_seconds
		await _teardown()
		return summary
	for map_id: StringName in CHAIN:
		summary["segments"].append(await _run_segment(map_id, _farm_target(map_id)))
		_check_advance()
		if map_id == ARENA_INSERT_AFTER:
			summary["segments"].append(await _run_arena())
	if bool(_advancement["advanced"]):
		summary["notes"].append("advancement triggered programmatically; no world gate exists")
	summary["completed"] = _ledger["completed"]
	summary["game_seconds"] = _game_seconds
	summary["final_level"] = player.level if player != null else 0
	await _teardown()
	return summary

func _farm_target(map_id: StringName) -> int:
	var index := CHAIN.find(map_id)
	if index < 0 or index + 1 >= CHAIN.size():
		var own := WorldManager.get_definition(map_id)
		return own.recommended_level if own != null else 1
	var next_map := WorldManager.get_definition(CHAIN[index + 1])
	return next_map.recommended_level if next_map != null else 1

func _boot(class_id: StringName) -> bool:
	TutorialSystem.reset()
	SpawnManager.enabled = true
	LootManager.enabled = true
	DebugManager.reset_counters()
	DebugManager.set_file_logging(false)
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	tree.root.add_child(game)
	await tree.physics_frame
	await tree.physics_frame
	var picker := game.get_node_or_null("ClassSelect") as ClassSelectOverlay
	player = game.get_node("Player") as Player
	if picker == null or player == null:
		return false
	if picker.visible:
		picker.choose_class(class_id)
	world = _map_root()
	_connect_ledger()
	return true

func _teardown() -> void:
	_disconnect_ledger()
	for action in ["move_left", "move_right", "jump", "attack"]:
		Input.action_release(action)
	DebugManager.disable_ai = false
	DebugManager.god_mode = false
	DebugManager.set_file_logging(true)
	if game != null and is_instance_valid(game):
		game.queue_free()
		await tree.physics_frame
	game = null
	player = null
	world = null
	_segment = {}

func _connect_ledger() -> void:
	EventBus.mob_died.connect(_on_mob_died)
	EventBus.loot_collected.connect(_on_loot)
	EventBus.final_boss_defeated.connect(_on_final_boss)

func _disconnect_ledger() -> void:
	EventBus.mob_died.disconnect(_on_mob_died)
	EventBus.loot_collected.disconnect(_on_loot)
	EventBus.final_boss_defeated.disconnect(_on_final_boss)

func _on_mob_died(mob_id: StringName, xp: float, definition: Resource) -> void:
	_ledger["kills"] += 1
	_ledger["xp"] += xp
	if definition != null and definition.get("is_boss") == true:
		_ledger["boss_kills"].append(String(mob_id))
	if not _seen_mobs.has(mob_id):
		_seen_mobs[mob_id] = true
	if not _segment.is_empty() and not _segment["mobs"].has(String(mob_id)):
		_segment["mobs"].append(String(mob_id))

func _on_loot(item_id: StringName, _amount: int) -> void:
	if not _segment.is_empty():
		_segment["loot"].append(String(item_id))

func _on_final_boss(_boss_id: StringName) -> void:
	_ledger["completed"] = true

func _run_segment(map_id: StringName, target_level: int) -> Dictionary:
	var definition := WorldManager.get_definition(map_id)
	var segment := {
		"map": String(map_id),
		"recommended_level": definition.recommended_level if definition != null else 0,
		"target_level": target_level,
		"arrival_level": 0,
		"transit_seconds": 0.0,
		"travel_method": "portal",
		"mobs": [],
		"avg_mob_hp": 0.0,
		"sample": {},
		"levels": [],
		"boss": null,
		"deaths": 0,
		"stuck": 0,
		"assists": 0,
		"accidental_travels": 0,
		"loot": [],
		"notes": [],
	}
	var counters_start := _counter_snapshot()
	var travel := await _travel_to(map_id, segment)
	world = _map_root()
	segment["arrival_level"] = player.level
	segment["transit_seconds"] = travel["seconds"]
	segment["travel_method"] = travel["method"]
	segment["stuck"] += travel["stuck"]
	segment["assists"] += travel["assists"]
	var discovered := _discover()
	segment["avg_mob_hp"] = discovered["avg_mob_hp"]
	if discovered["zone_count"] == 0:
		segment["sample"] = {"skipped": true}
	else:
		segment["sample"] = await _sample()
	await _extrapolate_to(target_level, float(segment["sample"].get("xp_per_sec", 0.0)), segment)
	if discovered["boss_encounter"] != null and discovered["boss_encounter"].definition != null:
		var encounter: BossEncounter = discovered["boss_encounter"]
		_fight_map = StringName(segment["map"])
		var walk := await _walk_to_x(encounter.global_position.x, cap_frames(WALK_GAME_SECONDS))
		segment["transit_seconds"] += _seconds(walk["frames"])
		segment["stuck"] += walk["stuck"]
		segment["assists"] += 1 if walk["assisted"] else 0
		segment["boss"] = await _fight_boss(encounter.definition, segment, false,
			encounter.global_position.x)
	var deltas := _counters_delta(counters_start)
	segment["deaths"] = int(deltas["deaths"])
	segment["damage_taken"] = deltas["damage_taken"]
	print("pacing_bot: %s %s arrived lv %d -> target %d, %s" % [_run_class, String(map_id),
		int(segment["arrival_level"]), target_level, _segment_brief(segment)])
	return segment

func _run_arena() -> Dictionary:
	var definition := WorldManager.get_definition(ARENA_MAP)
	var segment := {
		"map": String(ARENA_MAP),
		"recommended_level": definition.recommended_level if definition != null else 0,
		"target_level": 0,
		"arrival_level": 0,
		"transit_seconds": 0.0,
		"travel_method": "portal",
		"mobs": [],
		"avg_mob_hp": 0.0,
		"sample": {},
		"levels": [],
		"boss": null,
		"deaths": 0,
		"stuck": 0,
		"assists": 0,
		"accidental_travels": 0,
		"loot": [],
		"notes": [],
	}
	var counters_start := _counter_snapshot()
	var travel := await _travel_to(ARENA_MAP, segment)
	world = _map_root()
	segment["arrival_level"] = player.level
	segment["transit_seconds"] = travel["seconds"]
	segment["travel_method"] = travel["method"]
	segment["stuck"] += travel["stuck"]
	segment["assists"] += travel["assists"]
	var discovered := _discover()
	if discovered["zone_count"] == 0:
		segment["notes"].append("arena has no spawn zones, NPCs or wired boss encounter")
		segment["sample"] = {"skipped": true}
	var boss_definition := load(ARENA_BOSS) as MobDefinition
	if boss_definition == null:
		segment["notes"].append("arena boss definition missing")
		return segment
	segment["notes"].append("briarback_boar is not wired into any map; spawned synthetically")
	_fight_map = ARENA_MAP
	segment["boss"] = await _fight_boss(boss_definition, segment, true)
	var deltas := _counters_delta(counters_start)
	segment["deaths"] = int(deltas["deaths"])
	segment["damage_taken"] = deltas["damage_taken"]
	print("pacing_bot: arena %s at lv %d, boss killed=%s attempts=%d" % [String(ARENA_MAP),
		int(segment["arrival_level"]), str(segment["boss"]["killed"]), int(segment["boss"]["attempts"])])
	return segment

func _segment_brief(segment: Dictionary) -> String:
	var sample: Dictionary = segment["sample"]
	return "kills %d rate %.1f xp/s dps %.0f deaths %d" % [
		int(sample.get("kills", 0)), float(sample.get("xp_per_sec", 0.0)),
		float(sample.get("dps", 0.0)), int(segment["deaths"])]

func _sample() -> Dictionary:
	var start := _counter_snapshot()
	var xp_start: float = _ledger["xp"]
	var engage := await _engage(cap_frames(SAMPLE_GAME_SECONDS), Callable(), &"")
	var deltas := _counters_delta(start)
	var seconds := _seconds(engage["frames"])
	var sampled_xp: float = _ledger["xp"] - xp_start
	return {
		"kills": int(deltas["kills"]),
		"game_seconds": seconds,
		"xp_per_sec": sampled_xp / seconds if seconds > 0.0 else 0.0,
		"dps": float(deltas["damage_dealt"]) / seconds if seconds > 0.0 else 0.0,
		"casts": int(deltas["casts"]),
		"mana_downtime_seconds": _seconds(engage["downtime_frames"]),
		"damage_taken": deltas["damage_taken"],
		"deaths": int(deltas["deaths"]),
	}

func _extrapolate_to(target_level: int, rate: float, segment: Dictionary) -> void:
	if player == null or not is_instance_valid(player) or player.level >= target_level:
		return
	var safe_rate := maxf(rate, MIN_XP_PER_SEC)
	if not segment.has("levels"):
		segment["levels"] = []
	if not segment.has("notes"):
		segment["notes"] = []
	if rate < MIN_XP_PER_SEC:
		segment["notes"].append("sampled xp rate ~0; grind minutes extrapolated at %d xp/s floor" % int(MIN_XP_PER_SEC))
	DebugManager.disable_ai = true
	DebugManager.god_mode = true
	while player.level < target_level:
		var need := player.xp_to_next_level()
		if need <= 0.0:
			break
		var minutes := minutes_for_xp(need, safe_rate)
		segment["levels"].append({"level": player.level, "minutes": minutes})
		var remaining := minutes * 60.0
		while remaining > 0.0 and player.level < target_level:
			player.grant_xp(safe_rate * GRANT_CHUNK_SECONDS)
			_spend_points()
			_check_advance()
			remaining -= GRANT_CHUNK_SECONDS
			_game_seconds += GRANT_CHUNK_SECONDS
			await tree.physics_frame
	DebugManager.disable_ai = false
	DebugManager.god_mode = false

func _fight_boss(definition: MobDefinition, segment: Dictionary, synthetic: bool,
		encounter_x := 0.0) -> Dictionary:
	var fight := {
		"id": String(definition.id),
		"recommended_level": definition.recommended_level,
		"attempts": 0,
		"deaths": 0,
		"kill_seconds": 0.0,
		"killed": false,
		"synthetic": synthetic,
		"dps": 0.0,
		"damage_taken": 0.0,
		"game_seconds": 0.0,
	}
	if synthetic:
		await _spawn_synthetic_boss(definition)
	for _attempt in range(BOSS_ATTEMPTS_CAP):
		if fight["killed"]:
			break
		if WorldManager.current_map_id != _fight_map:
			segment["accidental_travels"] += 1
			WorldManager.travel_to(_fight_map, &"")
			world = _map_root()
			_refresh_portal_cache()
			await tree.physics_frame
			await tree.physics_frame
			await _settle(SETTLE_FRAMES)
		if not _boss_present(definition.id):
			if synthetic:
				await _spawn_synthetic_boss(definition)
			else:
				var walk := await _walk_to_x(encounter_x, cap_frames(WALK_GAME_SECONDS))
				segment["stuck"] += walk["stuck"]
				await _settle(SETTLE_FRAMES)
		var start := _counter_snapshot()
		var stop := Callable()
		var engage := await _engage(cap_frames(BOSS_GAME_SECONDS), stop, definition.id)
		fight["attempts"] += 1
		fight["game_seconds"] += _seconds(engage["frames"])
		var deltas := _counters_delta(start)
		fight["deaths"] += int(deltas["deaths"])
		segment["deaths"] += int(deltas["deaths"])
		var boss_live := false
		for node in tree.get_nodes_in_group("enemies"):
			var mob := node as Mob
			if mob != null and is_instance_valid(mob) and mob.definition != null \
					and mob.definition.id == definition.id:
				boss_live = true
		print("pacing_bot:   attempt %d/%d: frames %d casts %d dealt %.0f taken %.0f deaths %d downtime %.1fs mana %.0f boss_live=%s killed=%s map_changed=%s pos=%s" % [
			int(fight["attempts"]), BOSS_ATTEMPTS_CAP, int(engage["frames"]),
			int(deltas["casts"]), float(deltas["damage_dealt"]), float(deltas["damage_taken"]),
			int(deltas["deaths"]), _seconds(int(engage["downtime_frames"])),
			float(player.mana) if player != null else -1.0, str(boss_live), str(bool(engage["killed_focus"])),
			str(bool(engage["map_changed"])),
			str(player.global_position) if player != null else "-"])
		if bool(engage["killed_focus"]):
			fight["killed"] = true
			fight["kill_seconds"] = _seconds(engage["frames"])
			fight["dps"] = float(deltas["damage_dealt"]) / maxf(fight["kill_seconds"], 0.1)
			fight["damage_taken"] = deltas["damage_taken"]
	if synthetic:
		for node in tree.get_nodes_in_group("enemies"):
			var mob := node as Mob
			if mob != null and is_instance_valid(mob) and mob.definition != null \
					and mob.definition.id == definition.id and not mob.is_dead():
				mob.queue_free()
		await tree.physics_frame
	print("pacing_bot: boss %s killed=%s attempts=%d deaths=%d kill %.1fs dps %.0f" % [
		fight["id"], str(fight["killed"]), int(fight["attempts"]), int(fight["deaths"]),
		float(fight["kill_seconds"]), float(fight["dps"])])
	return fight

func _boss_present(boss_id: StringName) -> bool:
	for node in tree.get_nodes_in_group("enemies"):
		var mob := node as Mob
		if mob != null and is_instance_valid(mob) and mob.definition != null \
				and mob.definition.id == boss_id and not mob.is_dead():
			return true
	return false

func _portal_blocks(direction: String) -> bool:
	var sign_dir := 1.0 if direction == "move_right" else -1.0
	for portal_x: float in _portal_x_values:
		var offset: float = (portal_x - player.global_position.x) * sign_dir
		if offset > 0.0 and offset < PORTAL_GUARD_PX:
			return true
	return false

func _spawn_synthetic_boss(definition: MobDefinition) -> void:
	var boss: Boss = (load(BOSS_SCENE) as PackedScene).instantiate()
	boss.definition = definition
	world.add_child(boss)
	boss.global_position = player.global_position + Vector2(240.0, 0.0)
	await tree.physics_frame
	await tree.physics_frame

func _refresh_portal_cache() -> void:
	_portal_x_values.clear()
	var root := _map_root()
	if root == null:
		return
	for node in root.find_children("*", "Portal", true, false):
		var portal := node as Portal
		if portal != null:
			_portal_x_values.append(portal.global_position.x)

func _travel_to(map_id: StringName, segment: Dictionary) -> Dictionary:
	var out := {"seconds": 0.0, "method": "portal", "stuck": 0, "assists": 0}
	if WorldManager.current_map_id == map_id:
		_refresh_portal_cache()
		return out
	var path := _portal_path(WorldManager.current_map_id, map_id)
	if path.is_empty():
		WorldManager.travel_to(map_id, &"")
		await tree.physics_frame
		await tree.physics_frame
		_refresh_portal_cache()
		out["method"] = "direct"
		out["seconds"] = WorldManager.TRAVEL_GRACE
		return out
	for step: StringName in path:
		var hop := await _hop_to(step, segment)
		out["seconds"] += hop["seconds"]
		out["stuck"] += hop["stuck"]
		out["assists"] += hop["assists"]
		if hop["method"] == "direct":
			out["method"] = "direct"
	_refresh_portal_cache()
	return out

func _hop_to(step: StringName, segment: Dictionary) -> Dictionary:
	var out := {"seconds": 0.0, "method": "portal", "stuck": 0, "assists": 0}
	var portal := _portal_in_current(step)
	if portal == null:
		WorldManager.travel_to(step, &"")
		await tree.physics_frame
		await tree.physics_frame
		out["method"] = "direct"
		out["seconds"] = WorldManager.TRAVEL_GRACE
		return out
	var before := WorldManager.current_map_id
	var walk := await _walk_to_x(portal.global_position.x, cap_frames(WALK_GAME_SECONDS))
	out["seconds"] += _seconds(walk["frames"])
	out["stuck"] += int(walk["stuck"])
	out["assists"] += 1 if bool(walk["assisted"]) else 0
	await _settle(SETTLE_FRAMES)
	if WorldManager.current_map_id == step:
		return out
	if WorldManager.current_map_id != before:
		segment["accidental_travels"] += 1
	WorldManager.travel_to(step, &"")
	await tree.physics_frame
	await tree.physics_frame
	out["seconds"] += WorldManager.TRAVEL_GRACE
	out["method"] = "direct"
	return out

func _portal_in_current(target: StringName) -> Portal:
	var root := _map_root()
	if root == null:
		return null
	var best: Portal = null
	var best_distance := INF
	for node in root.find_children("*", "Portal", true, false):
		var portal := node as Portal
		if portal == null or portal.target_map_id != target:
			continue
		var distance := absf(portal.global_position.x - player.global_position.x)
		if distance < best_distance:
			best_distance = distance
			best = portal
	return best

func _portal_path(from_id: StringName, to_id: StringName) -> Array:
	var came := {from_id: &""}
	var queue := [from_id]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		if current == to_id:
			break
		for next_map: StringName in _portal_links_for(current):
			if not came.has(next_map):
				came[next_map] = current
				queue.append(next_map)
	if not came.has(to_id):
		return []
	var path := []
	var cursor := to_id
	while cursor != from_id:
		path.push_front(cursor)
		cursor = came[cursor]
	return path

func _portal_links_for(map_id: StringName) -> Array:
	if _portal_links.has(map_id):
		return _portal_links[map_id]
	var links := []
	var definition := WorldManager.get_definition(map_id)
	if definition != null and definition.scene != null:
		var probe: Node2D = definition.scene.instantiate()
		for node in probe.find_children("*", "Portal", true, false):
			var portal := node as Portal
			if portal != null:
				links.append(portal.target_map_id)
		probe.free()
	_portal_links[map_id] = links
	return links

func _discover() -> Dictionary:
	var root := _map_root()
	var zone_count := 0
	var hp_sum := 0.0
	var hp_count := 0
	var boss_encounter: BossEncounter = null
	if root != null:
		for node in root.find_children("*", "SpawnZone", true, false):
			var zone := node as SpawnZone
			if zone == null:
				continue
			zone_count += 1
			if zone.definition != null:
				hp_sum += zone.definition.max_hp
				hp_count += 1
		var encounters := root.find_children("*", "BossEncounter", true, false)
		if encounters.size() > 0:
			boss_encounter = encounters[0] as BossEncounter
	return {
		"zone_count": zone_count,
		"avg_mob_hp": hp_sum / float(hp_count) if hp_count > 0 else 0.0,
		"boss_encounter": boss_encounter,
	}

func _pick_target(focus_id: StringName) -> Mob:
	if player == null or not is_instance_valid(player):
		return null
	var best: Mob = null
	var best_distance := INF
	for node in tree.get_nodes_in_group("enemies"):
		var mob := node as Mob
		if mob == null or not is_instance_valid(mob) or mob.is_dead():
			continue
		if focus_id != &"" and (mob.definition == null or mob.definition.id != focus_id):
			continue
		if absf(mob.global_position.y - player.global_position.y) > TARGET_DY:
			continue
		var distance := absf(mob.global_position.x - player.global_position.x)
		if distance < best_distance:
			best_distance = distance
			best = mob
	return best

func _engage(cap_frames: int, stop: Callable, focus_id: StringName = &"") -> Dictionary:
	var out := {"frames": 0, "casts": 0, "downtime_frames": 0, "stuck": 0, "assisted": false, "killed_focus": false, "map_changed": false}
	var focus_dead := {"dead": false}
	var on_focus := func(mob_id: StringName, _xp: float, definition: Resource) -> void:
		if focus_id != &"" and definition != null and definition.get("id") == focus_id:
			focus_dead["dead"] = true
	EventBus.mob_died.connect(on_focus)
	var held := ""
	var attack_held := false
	var jump_hold := 0
	var last_x := player.global_position.x if player != null else 0.0
	var stuck_cycles := 0
	var start_map: StringName = WorldManager.current_map_id
	while out["frames"] < cap_frames:
		out["frames"] += 1
		_game_seconds += Engine.time_scale / 60.0
		await tree.physics_frame
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0:
				Input.action_release("jump")
		if stop.is_valid() and bool(stop.call()):
			break
		if bool(focus_dead["dead"]):
			out["killed_focus"] = true
			break
		if WorldManager.current_map_id != start_map:
			out["map_changed"] = true
			break
		if player == null or not is_instance_valid(player) or world == null or not is_instance_valid(world):
			break
		if player.is_casting():
			continue
		var target := _pick_target(focus_id)
		if target == null:
			if attack_held:
				Input.action_release("attack")
				attack_held = false
			continue
		var dx := target.global_position.x - player.global_position.x
		var dy := absf(target.global_position.y - player.global_position.y)
		var slot := _best_affordable_slot()
		var reach := player.basic_attack_range + 24.0
		if slot >= 0:
			reach = player.ability_at(slot).range * 0.85
		var affordable := player.ability_at(slot) if slot >= 0 else null
		var best_unlocked := _best_unlocked_damage()
		var starved := best_unlocked > 0.0 and \
			(affordable == null or affordable.damage_at(player.ability_level(affordable)) < best_unlocked * 0.5)
		if starved:
			if attack_held:
				Input.action_release("attack")
				attack_held = false
			var retreat_dir := ""
			var nearest := _pick_target(&"")
			if nearest != null:
				var threat_dx := nearest.global_position.x - player.global_position.x
				var threat_dy := absf(nearest.global_position.y - player.global_position.y)
				if absf(threat_dx) < THREAT_RANGE_PX and threat_dy < 60.0:
					retreat_dir = "move_left" if threat_dx >= 0.0 else "move_right"
					if _portal_blocks(retreat_dir):
						retreat_dir = ""
			var want_dir := retreat_dir if retreat_dir != "" else ("move_right" if dx > 0.0 else "move_left")
			if held != want_dir:
				if held != "":
					Input.action_release(held)
				Input.action_press(want_dir)
				held = want_dir
			continue
		if absf(dx) > reach or dy > 60.0:
			var want := "move_right" if dx > 0.0 else "move_left"
			if want != held:
				if held != "":
					Input.action_release(held)
				Input.action_press(want)
				held = want
			if out["frames"] % STUCK_CHECK_FRAMES == 0:
				var moved := absf(player.global_position.x - last_x)
				last_x = player.global_position.x
				if moved < STUCK_PROGRESS_PX:
					stuck_cycles += 1
					out["stuck"] += 1
					jump_hold = JUMP_HOLD_FRAMES
					Input.action_press("jump")
					if stuck_cycles > STUCK_JUMPS_CAP:
						out["assisted"] = true
						await _assist_teleport(target.global_position.x)
						stuck_cycles = 0
				else:
					stuck_cycles = 0
			continue
		if held != "":
			Input.action_release(held)
			held = ""
		player.facing = 1 if dx >= 0.0 else -1
		if slot >= 0:
			out["casts"] += 1
			await _press_skill(slot)
		else:
			out["downtime_frames"] += 1
			if not attack_held:
				Input.action_press("attack")
				attack_held = true
	if attack_held:
		Input.action_release("attack")
	if held != "":
		Input.action_release(held)
	if jump_hold > 0:
		Input.action_release("jump")
	EventBus.mob_died.disconnect(on_focus)
	return out

func _walk_to_x(target_x: float, cap_frames: int) -> Dictionary:
	var out := {"frames": 0, "stuck": 0, "assisted": false}
	if player == null or not is_instance_valid(player):
		return out
	var held := ""
	var jump_hold := 0
	var last_x := player.global_position.x
	var stuck_cycles := 0
	while out["frames"] < cap_frames:
		if player == null or not is_instance_valid(player):
			break
		var dx := target_x - player.global_position.x
		if absf(dx) <= ARRIVE_SLACK_PX:
			break
		out["frames"] += 1
		_game_seconds += Engine.time_scale / 60.0
		await tree.physics_frame
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0:
				Input.action_release("jump")
		var want := "move_right" if dx > 0.0 else "move_left"
		if want != held:
			if held != "":
				Input.action_release(held)
			Input.action_press(want)
			held = want
		if out["frames"] % STUCK_CHECK_FRAMES == 0:
			var moved := absf(player.global_position.x - last_x)
			last_x = player.global_position.x
			if moved < STUCK_PROGRESS_PX:
				stuck_cycles += 1
				out["stuck"] += 1
				jump_hold = JUMP_HOLD_FRAMES
				Input.action_press("jump")
				if stuck_cycles > STUCK_JUMPS_CAP:
					out["assisted"] = true
					await _assist_teleport(target_x)
					break
			else:
				stuck_cycles = 0
	if held != "":
		Input.action_release(held)
	if jump_hold > 0:
		Input.action_release("jump")
	return out

func _assist_teleport(target_x: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(target_x, player.global_position.y - 120.0)
	DebugManager.register_combat_event("pacing_assist", {"to_x": target_x})
	for _i in range(SETTLE_FRAMES):
		_game_seconds += Engine.time_scale / 60.0
		await tree.physics_frame
		if player == null or not is_instance_valid(player):
			return
		if player.global_position.y > FALL_ABORT_Y:
			_respawn_at_default_spawn()
			return

func _respawn_at_default_spawn() -> void:
	var root := _map_root()
	if root == null or player == null or not is_instance_valid(player):
		return
	for node in root.find_children("*", "MapSpawn", true, false):
		var spawn := node as MapSpawn
		if spawn != null:
			player.global_position = spawn.global_position
			player.velocity = Vector2.ZERO
			return
	player.global_position = Vector2(0.0, -60.0)

func _press_skill(slot: int) -> void:
	var action := "skill_%d" % (slot + 1)
	Input.action_press(action)
	for _i in range(3):
		_game_seconds += Engine.time_scale / 60.0
		await tree.physics_frame
	Input.action_release(action)

func _best_affordable_slot() -> int:
	if player == null or not is_instance_valid(player):
		return -1
	var best := -1
	var best_damage := 0.0
	for slot in player.ABILITY_SLOT_COUNT:
		var ability := player.ability_at(slot)
		if ability == null or ability.is_shield() or ability.is_summon():
			continue
		var level := player.ability_level(ability)
		if player.level < ability.unlock_level:
			continue
		var damage := ability.damage_at(level)
		if damage <= 0.0 or ability.mana_cost_at(level) > player.mana:
			continue
		if damage > best_damage:
			best_damage = damage
			best = slot
	return best

func _best_unlocked_damage() -> float:
	if player == null or not is_instance_valid(player):
		return 0.0
	var best := 0.0
	for slot in player.ABILITY_SLOT_COUNT:
		var ability := player.ability_at(slot)
		if ability == null or ability.is_shield() or ability.is_summon():
			continue
		if player.level < ability.unlock_level:
			continue
		best = maxf(best, ability.damage_at(player.ability_level(ability)))
	return best

func _spend_points() -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var spent := 0
	while player.skill_points > 0:
		var best: AbilityDefinition = null
		var best_gain := -1.0
		for slot in player.ABILITY_SLOT_COUNT:
			var ability := player.ability_at(slot)
			if ability == null or ability.is_shield() or ability.is_summon():
				continue
			if ability.damage_at(player.ability_level(ability)) <= 0.0:
				continue
			if not player.can_spend_skill_point(ability):
				continue
			if ability.damage_per_level > best_gain:
				best_gain = ability.damage_per_level
				best = ability
		if best == null:
			break
		player.spend_skill_point(best)
		spent += 1
	return spent

func _check_advance() -> void:
	if bool(_advancement["advanced"]):
		return
	if player != null and is_instance_valid(player) and player.can_advance():
		player.advance()
		_advancement["advanced"] = true
		_advancement["level"] = player.level

func _settle(frames: int) -> void:
	for _i in range(frames):
		_game_seconds += Engine.time_scale / 60.0
		await tree.physics_frame

func _seconds(frames: int) -> float:
	return float(frames) * Engine.time_scale / 60.0

func _counter_snapshot() -> Dictionary:
	return {
		"kills": DebugManager.counters.get("kills", 0),
		"damage_dealt": DebugManager.counters.get("damage_dealt", 0.0),
		"damage_taken": DebugManager.counters.get("damage_taken", 0.0),
		"deaths": DebugManager.counters.get("deaths", 0),
		"casts": DebugManager.counters.get("casts", 0),
	}

func _counters_delta(start: Dictionary) -> Dictionary:
	var delta := {}
	for key in start:
		delta[key] = DebugManager.counters.get(key, 0) - start[key]
	return delta

func _map_root() -> Node2D:
	var host := tree.root.get_node_or_null("Game/World")
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(0) as Node2D

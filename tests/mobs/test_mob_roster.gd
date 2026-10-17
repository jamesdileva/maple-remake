extends RefCounted

const NORMALS := [
	&"meadow_slime", &"bloom_bud", &"bloom_seed", &"shade_moth", &"thorn_crawler",
	&"hollow_rat", &"hollow_rabbit", &"shadow_rabbit", &"miner_golem", &"vein_bat",
	&"corrupted_slime", &"sanctum_adept",
]
const ELITES := [&"grub_matron", &"ruin_sentinel", &"night_stalker"]
const CONTINENT_MAPS := [
	&"sunlit_meadow", &"whispering_forest", &"hollow_forest", &"forgotten_mine",
	&"ruined_settlement", &"haunted_fortress", &"blightheart_sanctum",
]

func get_suite_name() -> String:
	return "mob_roster"

func run(t) -> void:
	var defs := {}
	for id: StringName in NORMALS + ELITES:
		var def := load("res://data/mobs/%s.tres" % id) as MobDefinition
		t.assert_true(def != null, "%s loads" % id)
		if def == null:
			continue
		defs[id] = def
		t.assert_eq(def.id, id, "%s keeps its id" % id)
		t.assert_true(def.max_hp > 0.0, "%s has hp" % id)
		t.assert_true(def.move_speed > 0.0, "%s moves" % id)
		t.assert_true(def.contact_damage > 0.0, "%s threatens contact" % id)
		t.assert_true(def.xp > 0.0, "%s pays xp" % id)
		t.assert_true(def.recommended_level >= 1, "%s recommends a level" % id)
		t.assert_true(def.mob_scene != null, "%s has a scene" % id)
		t.assert_true(def.loot_table != null, "%s has loot" % id)

	t.assert_true(NORMALS.size() >= 10, "the roster holds at least ten normals (%d)" % NORMALS.size())
	t.assert_true(ELITES.size() >= 2 and ELITES.size() <= 4, "the roster holds a few elites (%d)" % ELITES.size())

	_assert_chain(t, defs, &"bloom_bud", &"bloom_seed")
	_assert_chain(t, defs, &"hollow_rabbit", &"shadow_rabbit")
	_assert_chain(t, defs, &"grub_matron", &"shadow_rabbit")

	var tints := {}
	var scales := {}
	var min_level := 99
	var max_level := 0
	for id: StringName in defs:
		var def: MobDefinition = defs[id]
		tints[def.body_tint] = true
		scales[def.visual_scale] = true
		min_level = mini(min_level, def.recommended_level)
		max_level = maxi(max_level, def.recommended_level)
	t.assert_true(tints.size() >= 8, "roster mobs read distinctly by tint (%d)" % tints.size())
	t.assert_true(scales.size() >= 4, "roster mobs vary in size (%d)" % scales.size())
	t.assert_true(max_level - min_level >= 15, "the roster spans the continent (%d-%d levels)" % [min_level, max_level])

	for id: StringName in defs:
		var def: MobDefinition = defs[id]
		if def.chain != null and def.chain.child_definition == null:
			t.assert_true(def.chain.child_count == 0, "%s detonates without stray children" % id)
		elif def.max_chain_depth > 0:
			t.assert_true(def.chain != null and def.chain.child_definition != null,
				"%s chain depth matches a real child" % id)

	await _check_visual(t, defs[&"meadow_slime"])
	await _check_visual(t, defs[&"night_stalker"])

	_check_map_roster(t, defs)
	await _check_snapshot(t, defs)

	t.complete_suite(get_suite_name())

func _assert_chain(t, defs: Dictionary, parent_id: StringName, child_id: StringName) -> void:
	var parent: MobDefinition = defs.get(parent_id)
	if parent == null:
		t.assert_true(false, "%s missing for chain check" % parent_id)
		return
	t.assert_true(parent.chain != null, "%s splits on death" % parent_id)
	if parent.chain == null:
		return
	t.assert_true(parent.chain.child_definition != null, "%s names its offspring" % parent_id)
	if parent.chain.child_definition != null:
		t.assert_eq(parent.chain.child_definition.id, child_id, "%s spawns %s" % [parent_id, child_id])
	t.assert_true(parent.max_chain_depth >= 1, "%s chains one deep" % parent_id)

func _check_visual(t, def: MobDefinition) -> void:
	var mob: Mob = def.mob_scene.instantiate()
	mob.definition = def
	t.root.add_child(mob)
	await t.physics_frame
	var visual := mob.get_node_or_null("Visual") as Node2D
	t.assert_true(visual != null, "%s has a visual" % def.id)
	if visual != null:
		var body := visual.get_node_or_null("Body") as ColorRect
		t.assert_true(body != null, "%s has a body" % def.id)
		if body != null:
			t.assert_eq(body.color, def.body_tint, "%s wears its tint" % def.id)
		t.assert_almost_eq(visual.scale.x, def.visual_scale, 0.001, "%s keeps its scale" % def.id)
	mob.queue_free()
	await t.physics_frame

func _check_map_roster(t, defs: Dictionary) -> void:
	for map_id: StringName in CONTINENT_MAPS:
		var definition := load("res://data/maps/%s.tres" % map_id) as MapDefinition
		if definition == null or definition.scene == null:
			t.assert_true(false, "%s missing for roster check" % map_id)
			continue
		var root: Node2D = definition.scene.instantiate()
		var zones := root.find_children("*", "SpawnZone", true, false)
		for node in zones:
			var zone := node as SpawnZone
			if zone == null:
				continue
			t.assert_true(zone.definition != null, "%s zone has a definition" % map_id)
			if zone.definition != null:
				t.assert_true(defs.has(zone.definition.id),
					"%s fields a roster mob (%s)" % [map_id, zone.definition.id])
		root.free()

func _check_snapshot(t, defs: Dictionary) -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	for id: StringName in [&"meadow_slime", &"night_stalker"]:
		var mob: Mob = defs[id].mob_scene.instantiate()
		mob.definition = defs[id]
		container.add_child(mob)
	await t.physics_frame
	var path: String = DebugManager.export_debug_data()
	var snapshot := FileAccess.get_file_as_string(path)
	t.assert_true(snapshot.contains("\"roster\""), "the snapshot exposes the live roster")
	t.assert_true(snapshot.contains("meadow_slime"), "the snapshot counts meadow slimes")
	t.assert_true(snapshot.contains("night_stalker"), "the snapshot counts night stalkers")
	container.queue_free()
	await t.physics_frame

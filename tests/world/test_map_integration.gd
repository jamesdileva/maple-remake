extends RefCounted

const CHAIN := [
	&"brightwood_outskirts",
	&"sunlit_meadow",
	&"whispering_forest",
	&"hollow_forest",
	&"forgotten_mine",
	&"ruined_settlement",
	&"haunted_fortress",
	&"blightheart_sanctum",
]
const ARENAS := [&"thornhollow_ring"]

func get_suite_name() -> String:
	return "map_integration"

func run(t) -> void:
	var definitions := {}
	var portals_by_map := {}
	var npc_ids := {}
	var npc_count := 0
	var maps_with_npcs := 0

	for map_id: StringName in CHAIN:
		var definition := _load(t, map_id)
		if definition == null:
			continue
		definitions[map_id] = definition
		t.assert_true(definition.display_name.strip_edges() != "",
			"%s is named" % map_id)
		t.assert_true(definition.recommended_level > 0,
			"%s has a recommended level" % map_id)

	for arena_id: StringName in ARENAS:
		var arena := _load(t, arena_id)
		if arena == null:
			continue
		definitions[arena_id] = arena
		t.assert_true(arena.recommended_level > 0,
			"%s has a recommended level" % arena_id)

	for index in range(1, CHAIN.size()):
		var previous := definitions.get(CHAIN[index - 1]) as MapDefinition
		var current := definitions.get(CHAIN[index]) as MapDefinition
		if previous == null or current == null:
			continue
		t.assert_true(current.recommended_level >= previous.recommended_level,
			"%s does not lower the bar from %s (%d >= %d)" % [
				CHAIN[index], CHAIN[index - 1],
				current.recommended_level, previous.recommended_level])

	for map_id: StringName in definitions:
		var definition: MapDefinition = definitions[map_id]
		var root: Node2D = definition.scene.instantiate()

		var portals: Array = []
		for node in root.find_children("*", "Portal", true, false):
			var portal := node as Portal
			if portal != null:
				portals.append({
					"target": portal.target_map_id,
					"hint": portal.hint_text(),
				})
		portals_by_map[map_id] = portals
		t.assert_true(not portals.is_empty(),
			"%s has at least one portal" % map_id)

		var npcs := root.find_children("*", "NPC", true, false)
		if not npcs.is_empty():
			maps_with_npcs += 1
		for node in npcs:
			var npc := node as NPC
			npc_count += 1
			t.assert_true(npc.dialogue_line.strip_edges() != "",
				"%s has something to say" % npc.display_name)
			t.assert_true(not npc_ids.has(npc.npc_id),
				"npc id %s is unique" % npc.npc_id)
			npc_ids[npc.npc_id] = true

		root.free()

	for map_id: StringName in portals_by_map:
		for link: Dictionary in portals_by_map[map_id]:
			var target_id: StringName = link["target"]
			t.assert_true(definitions.has(target_id),
				"%s portal targets a registered map (%s)" % [map_id, target_id])
			var target := definitions.get(target_id) as MapDefinition
			if target == null:
				continue
			t.assert_eq(link["hint"],
				"-> %s  Lv %d" % [target.display_name, target.recommended_level],
				"%s portal advertises %s" % [map_id, target.display_name])

			var returns_home := false
			for back: Dictionary in portals_by_map.get(target_id, []):
				if back["target"] == map_id:
					returns_home = true
			t.assert_true(returns_home,
				"%s and %s are directly connected both ways" % [map_id, target_id])

	t.assert_eq(maps_with_npcs, 5, "five regions have residents")
	t.assert_true(npc_count >= 5, "the route is staffed (%d npcs)" % npc_count)
	t.assert_true(npc_ids.has(&"maren"), "the hub keeps its villager")

	var manager = Engine.get_main_loop().root.get_node_or_null("WorldManager")
	if manager != null:
		if manager.get_definition(&"brightwood_outskirts") == null:
			manager.scan_maps()
		for map_id: StringName in definitions:
			var definition: MapDefinition = definitions[map_id]
			var registered: MapDefinition = manager.get_definition(map_id)
			t.assert_true(registered != null and registered.scene == definition.scene,
				"WorldManager resolves %s" % map_id)

	t.complete_suite(get_suite_name())

func _load(t, map_id: StringName) -> MapDefinition:
	var definition := load("res://data/maps/%s.tres" % map_id) as MapDefinition
	t.assert_true(definition != null, "%s definition loads" % map_id)
	if definition != null:
		t.assert_true(definition.scene != null, "%s has a scene" % map_id)
	return definition if definition != null and definition.scene != null else null

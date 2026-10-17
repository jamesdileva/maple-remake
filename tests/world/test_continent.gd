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
const ARENAS := [
	&"thornhollow_ring",
]

func get_suite_name() -> String:
	return "continent"

func run(t) -> void:
	var definitions := {}
	var tags_by_map := {}
	var portals_by_map := {}
	var zone_count := 0

	for map_id: StringName in CHAIN:
		zone_count += _collect(t, map_id, definitions, tags_by_map, portals_by_map, 2, 1)
	for map_id: StringName in ARENAS:
		_collect(t, map_id, definitions, tags_by_map, portals_by_map, 1, 0)

	t.assert_eq(definitions.size(), CHAIN.size() + ARENAS.size(),
		"every continent region exists")

	var registered := {}
	for map_id: StringName in definitions:
		registered[map_id] = true

	for map_id: StringName in portals_by_map:
		for link: Array in portals_by_map[map_id]:
			var target: StringName = link[0]
			var tag: StringName = link[1]
			t.assert_true(registered.has(target),
				"%s portal targets a known map (%s)" % [map_id, target])
			var tags: Dictionary = tags_by_map.get(target, {})
			t.assert_true(tags.has(tag),
				"%s portal lands on a real spawn (%s)" % [map_id, tag])

	var reachable: Dictionary = _reach(portals_by_map, &"brightwood_outskirts")
	t.assert_eq(reachable.size(), definitions.size(),
		"the hub reaches every region (%d/%d)" % [reachable.size(), definitions.size()])
	t.assert_true(reachable.has(&"blightheart_sanctum"), "the continent reaches the final sanctum")

	for map_id: StringName in definitions:
		var homeward: Dictionary = _reach(portals_by_map, map_id)
		t.assert_true(homeward.has(&"brightwood_outskirts"),
			"%s can walk home to the hub" % map_id)

	t.assert_true(zone_count >= 15, "the continent is densely populated (%d zones)" % zone_count)

	t.complete_suite(get_suite_name())

func _collect(t, map_id: StringName, definitions: Dictionary, tags_by_map: Dictionary,
	portals_by_map: Dictionary, min_spawns: int, min_zones: int) -> int:
	var definition := load("res://data/maps/%s.tres" % map_id) as MapDefinition
	t.assert_true(definition != null, "%s definition loads" % map_id)
	if definition == null:
		return 0
	t.assert_true(definition.scene != null, "%s has a scene" % map_id)
	if definition.scene == null:
		return 0
	definitions[map_id] = definition
	var root: Node2D = definition.scene.instantiate()

	var spawns := root.find_children("*", "MapSpawn", true, false)
	t.assert_true(spawns.size() >= min_spawns,
		"%s offers its entries (%d/%d)" % [map_id, spawns.size(), min_spawns])
	var tags := {}
	for node in spawns:
		var spawn := node as MapSpawn
		if spawn != null:
			tags[spawn.spawn_tag] = true
	tags_by_map[map_id] = tags
	if min_spawns >= 2:
		t.assert_true(tags.has(&"default"), "%s has a default spawn" % map_id)

	var floors := root.find_children("*", "StaticBody2D", true, false)
	t.assert_true(floors.size() >= 1, "%s stands on solid ground" % map_id)

	var zones := root.find_children("*", "SpawnZone", true, false)
	t.assert_true(zones.size() >= min_zones,
		"%s fields its hunting grounds (%d/%d)" % [map_id, zones.size(), min_zones])

	var portals: Array = []
	for node in root.find_children("*", "Portal", true, false):
		var portal := node as Portal
		if portal != null:
			portals.append([portal.target_map_id, portal.target_spawn_tag])
	portals_by_map[map_id] = portals
	root.free()
	return zones.size()

func _reach(portals_by_map: Dictionary, origin: StringName) -> Dictionary:
	var visited := {origin: true}
	var queue := [origin]
	while not queue.is_empty():
		var current: StringName = queue.pop_front()
		for link: Array in portals_by_map.get(current, []):
			var target: StringName = link[0]
			if not visited.has(target):
				visited[target] = true
				queue.append(target)
	return visited

extends RefCounted

const CHAIN := [
	&"brightwood_outskirts", &"sunlit_meadow", &"whispering_forest",
	&"hollow_forest", &"forgotten_mine", &"ruined_settlement",
	&"haunted_fortress", &"blightheart_sanctum",
]
const ARENAS := [&"thornhollow_ring"]
const MIN_THICKNESS := 200.0
const BOSS_SPAWN_OFFSET := 220.0

func get_suite_name() -> String:
	return "floor_integrity"

func run(t) -> void:
	for map_id: StringName in CHAIN + ARENAS:
		var definition := load("res://data/maps/%s.tres" % map_id) as MapDefinition
		t.assert_true(definition != null and definition.scene != null, "%s loads" % map_id)
		if definition == null or definition.scene == null:
			continue
		var root: Node2D = definition.scene.instantiate()
		var floor_body: StaticBody2D = null
		for node in root.find_children("*", "StaticBody2D", true, false):
			if node.name == "Floor":
				floor_body = node
				break
		t.assert_true(floor_body != null, "%s grounds on a Floor body" % map_id)
		if floor_body != null:
			var collision := floor_body.get_node_or_null("Collision") as CollisionShape2D
			t.assert_true(collision != null, "%s Floor has a collision" % map_id)
			if collision != null and collision.shape is RectangleShape2D:
				var shape: RectangleShape2D = collision.shape
				t.assert_true(shape.size.y >= MIN_THICKNESS,
					"%s floor resists tunneling (%.0f thick)" % [map_id, shape.size.y])
				var span_low: float = floor_body.position.x + collision.position.x - shape.size.x * 0.5
				var span_high: float = floor_body.position.x + collision.position.x + shape.size.x * 0.5
				for node in root.find_children("*", "BossEncounter", true, false):
					var encounter := node as BossEncounter
					if encounter == null:
						continue
					var spawn_x: float = encounter.position.x + BOSS_SPAWN_OFFSET
					t.assert_true(spawn_x + 80.0 <= span_high and encounter.position.x - 100.0 >= span_low,
						"%s boss spawn lands on solid floor (%.0f in %.0f..%.0f)" % [
							map_id, spawn_x, span_low, span_high])
				for node in root.find_children("*", "MapSpawn", true, false):
					var spawn := node as MapSpawn
					if spawn != null:
						t.assert_true(spawn.position.x >= span_low and spawn.position.x <= span_high,
							"%s spawn %s rests on the floor" % [map_id, spawn.spawn_tag])
		root.free()
	t.complete_suite(get_suite_name())

extends RefCounted

const KITS := {
	"brightwood_outskirts": 10,
	"sunlit_meadow": 6,
	"whispering_forest": 6,
	"hollow_forest": 8,
	"forgotten_mine": 6,
	"ruined_settlement": 7,
	"haunted_fortress": 7,
}
const PLAN_MAPS := [
	"brightwood_outskirts",
	"sunlit_meadow",
	"whispering_forest",
	"hollow_forest",
	"forgotten_mine",
	"ruined_settlement",
	"haunted_fortress",
	"blightheart_sanctum",
	"thornhollow_ring",
]

func get_suite_name() -> String:
	return "environment_kits"

func run(t) -> void:
	_assert_specs(t)
	_assert_atlases(t)
	_assert_kits(t)
	_assert_reuse(t)
	_assert_plans(t)
	_assert_missing_prop(t)
	await _assert_runtime(t)
	t.complete_suite(get_suite_name())

func _assert_specs(t) -> void:
	for kit_id: String in KITS:
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/env_specs/%s.json" % kit_id))
		t.assert_true(spec is Dictionary, "%s spec is authored" % kit_id)
		if not spec is Dictionary:
			continue
		t.assert_true(spec.get("palette", {}).size() >= 8, "%s declares a full palette" % kit_id)
		var props: Array = spec.get("props", [])
		t.assert_eq(props.size(), KITS[kit_id], "%s declares %d props" % [kit_id, KITS[kit_id]])
		t.assert_true(FileAccess.file_exists("res://tools/art/env_specs/%s.approved" % kit_id), "%s passed the approval gate" % kit_id)

func _assert_atlases(t) -> void:
	for kit_id: String in KITS:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/env/%s.json" % kit_id))
		t.assert_true(data is Dictionary, "%s atlas json parses" % kit_id)
		if not data is Dictionary:
			continue
		var texture: Texture2D = load(String(data.get("image", "")))
		t.assert_true(texture != null, "%s atlas image is imported" % kit_id)
		var cell: Array = data.get("cell", [])
		t.assert_eq(cell.size(), 2, "%s atlas declares a cell" % kit_id)
		if cell.size() == 2:
			t.assert_eq(cell[0], cell[1], "%s atlas cell is square" % kit_id)
		var props: Dictionary = data.get("props", {})
		t.assert_eq(props.size(), KITS[kit_id], "%s atlas packs every prop" % kit_id)
		if texture == null:
			continue
		for prop_name: String in props:
			var region: Array = props[prop_name].get("region", [])
			t.assert_eq(region.size(), 4, "%s.%s has a region" % [kit_id, prop_name])
			if region.size() != 4:
				continue
			t.assert_true(region[0] >= 0 and region[1] >= 0, "%s.%s region is inside the atlas" % [kit_id, prop_name])
			t.assert_true(region[0] + region[2] <= texture.get_width(), "%s.%s fits the atlas width" % [kit_id, prop_name])
			t.assert_true(region[1] + region[3] <= texture.get_height(), "%s.%s fits the atlas height" % [kit_id, prop_name])
			var pivot: Array = props[prop_name].get("pivot", [0.0, 0.0])
			t.assert_true(pivot[1] >= 0.0 and pivot[1] <= float(region[3]), "%s.%s pivot sits in the cell" % [kit_id, prop_name])
			t.assert_true(float(props[prop_name].get("default_scale", 0.0)) > 0.0, "%s.%s has a default scale" % [kit_id, prop_name])

func _assert_kits(t) -> void:
	for kit_id: String in KITS:
		var kit: EnvironmentKit = load("res://data/env/%s_kit.tres" % kit_id)
		t.assert_true(kit != null, "%s kit resource loads" % kit_id)
		if kit == null:
			continue
		t.assert_true(String(kit.id) == kit_id, "%s kit carries its id" % kit_id)
		t.assert_eq(kit.props.size(), KITS[kit_id], "%s kit has %d props" % [kit_id, KITS[kit_id]])
		t.assert_eq(kit.prop_names().size(), kit.props.size(), "%s kit enumerates its props" % kit_id)
		for prop_name: String in kit.props:
			var sprite: PropSprite = kit.get_prop(StringName(prop_name))
			t.assert_true(sprite != null, "%s.%s is a PropSprite" % [kit_id, prop_name])
			if sprite == null:
				continue
			t.assert_true(sprite.texture is AtlasTexture, "%s.%s uses an atlas slice" % [kit_id, prop_name])
			t.assert_true(sprite.archetype != &"", "%s.%s records its archetype" % [kit_id, prop_name])
			t.assert_true(sprite.default_scale > 0.0, "%s.%s has a positive scale" % [kit_id, prop_name])

func _assert_reuse(t) -> void:
	var archetype_kits := {}
	var total_props := 0
	for kit_id: String in KITS:
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/env_specs/%s.json" % kit_id))
		if not spec is Dictionary:
			continue
		for prop: Dictionary in spec.get("props", []):
			total_props += 1
			var archetype := String(prop.get("archetype", prop.get("name", "")))
			if not archetype_kits.has(archetype):
				archetype_kits[archetype] = []
			archetype_kits[archetype].append(kit_id)
	t.assert_true(archetype_kits.size() < total_props, "kits reuse archetypes instead of forking (%d archetypes / %d props)" % [archetype_kits.size(), total_props])
	var shared := 0
	for archetype: String in archetype_kits:
		if archetype_kits[archetype].size() >= 2:
			shared += 1
	t.assert_true(shared >= 5, "at least five archetypes are shared across kits (%d)" % shared)

func _assert_plans(t) -> void:
	for map_id: String in PLAN_MAPS:
		var plan: DecorPlan = load("res://data/decor/%s.tres" % map_id)
		t.assert_true(plan != null, "%s decor plan loads" % map_id)
		if plan == null:
			continue
		t.assert_true(plan.kit != null, "%s decor plan binds a kit" % map_id)
		t.assert_eq(plan.props.size(), plan.positions.size(), "%s decor plan props and positions line up" % map_id)
		t.assert_true(plan.count() >= 3, "%s decor plan places several props" % map_id)
		for index in range(plan.count()):
			t.assert_true(plan.kit.has_prop(plan.props[index]), "%s places known prop %s" % [map_id, plan.props[index]])
			t.assert_true(absf(plan.positions[index].x) <= 1500.0, "%s prop %d stays near the map" % [map_id, index])

func _assert_missing_prop(t) -> void:
	var kit: EnvironmentKit = load("res://data/env/hollow_forest_kit.tres")
	var plan := DecorPlan.new()
	plan.id = &"synthetic"
	plan.kit = kit
	plan.props = PackedStringArray(["dead_tree", "does_not_exist"])
	plan.positions = PackedVector2Array([Vector2.ZERO, Vector2(10, 0)])
	var holder := Node2D.new()
	t.root.add_child(holder)
	var layer := PropLayer.new()
	layer.plan = plan
	holder.add_child(layer)
	layer.rebuild()
	t.assert_eq(layer.placed_count, 1, "unknown props are skipped")
	t.assert_true(layer.missing_props.has("does_not_exist"), "missing props are recorded")
	t.assert_eq(holder.get_child_count(), 1, "only known props become sprites")
	holder.queue_free()

func _assert_runtime(t) -> void:
	SpawnManager.enabled = false
	LootManager.enabled = false
	for map_id: String in PLAN_MAPS:
		var scene: PackedScene = load("res://scenes/maps/%s.tscn" % map_id)
		t.assert_true(scene != null, "%s scene loads" % map_id)
		if scene == null:
			continue
		var world: Node2D = scene.instantiate()
		t.root.add_child(world)
		await t.physics_frame
		var layers := world.find_children("*", "PropLayer", true, false)
		t.assert_eq(layers.size(), 1, "%s has exactly one prop layer" % map_id)
		if layers.is_empty():
			world.queue_free()
			await t.physics_frame
			continue
		var layer: PropLayer = layers[0]
		var plan: DecorPlan = layer.plan
		t.assert_true(plan != null, "%s prop layer is wired to its plan" % map_id)
		if plan != null:
			t.assert_eq(layer.placed_count, plan.count(), "%s places every planned prop" % map_id)
			t.assert_eq(layer.get_child_count(), plan.count(), "%s builds %d sprites" % [map_id, plan.count()])
			for child: Node in layer.get_children():
				t.assert_true(child is Sprite2D, "%s decor child is a sprite" % map_id)
				if child is Sprite2D:
					var sprite: Sprite2D = child
					t.assert_true(sprite.texture != null, "%s decor sprite has a texture" % map_id)
					t.assert_true(sprite.offset.y <= 0.0, "%s decor anchors at the prop feet" % map_id)
		var leftovers := 0
		for child: Node in world.get_children():
			if String(child.name).begins_with("Decor"):
				leftovers += 1
		t.assert_eq(leftovers, 0, "%s blockout decor is fully replaced" % map_id)
		world.queue_free()
		await t.physics_frame
	SpawnManager.enabled = true
	LootManager.enabled = true

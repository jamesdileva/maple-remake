extends RefCounted

const SPEC_PATH := "res://tools/art/specs/meadow_slime.json"
const MOB_ATLAS := "res://assets/art/mobs/meadow_slime.json"
const MOB_FRAMES := "res://data/visuals/meadow_slime_frames.tres"
const EFFECT_ATLAS := "res://assets/art/effects/slime_splash.json"
const EFFECT_FRAMES := "res://data/visuals/slime_splash_frames.tres"

func get_suite_name() -> String:
	return "art_pipeline"

func run(t) -> void:
	_assert_spec(t)
	_assert_atlas(t, MOB_ATLAS, 4)
	_assert_atlas(t, EFFECT_ATLAS, 1)
	_assert_frames(t, MOB_FRAMES, {"idle": 6, "hop": 8, "attack": 6, "hit": 3})
	_assert_frames(t, EFFECT_FRAMES, {"slime_splash": 6})
	_assert_wiring(t)
	await _assert_runtime(t)
	t.complete_suite(get_suite_name())

func _assert_spec(t) -> void:
	var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	t.assert_true(spec is Dictionary, "the mob spec is authored")
	if not spec is Dictionary:
		return
	for key: String in ["concept", "palette", "shape", "curves", "animations"]:
		t.assert_true(spec.has(key), "the spec declares %s" % key)
	t.assert_true(spec.get("effect", {}).has("id"), "the spec declares an attack effect")
	var animations: Array = spec.get("animations", [])
	t.assert_eq(animations.size(), 4, "the spec drives every animation")
	for animation: Dictionary in animations:
		t.assert_true(spec.get("curves", {}).has(animation.get("name", "")), "curve matches animation %s" % animation.get("name", "?"))

func _assert_atlas(t, atlas_path: String, animation_count: int) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(atlas_path))
	t.assert_true(data is Dictionary, "%s parses" % atlas_path.get_file())
	if not data is Dictionary:
		return
	var texture: Texture2D = load(String(data.get("image", "")))
	t.assert_true(texture != null, "the atlas image is imported for %s" % atlas_path.get_file())
	var cell: Array = data.get("cell", [])
	t.assert_eq(cell.size(), 2, "the atlas declares a cell size")
	t.assert_eq(cell[0], cell[1], "the atlas cell is square")
	var animations: Dictionary = data.get("animations", {})
	t.assert_eq(animations.size(), animation_count, "%s packs %d animations" % [atlas_path.get_file(), animation_count])
	if texture == null:
		return
	for name: String in animations:
		var frames: Array = animations[name].get("frames", [])
		t.assert_true(frames.size() >= 1, "animation %s has frames" % name)
		for region: Array in frames:
			t.assert_true(region[0] >= 0 and region[1] >= 0, "frame %s stays inside the atlas" % name)
			t.assert_true(region[0] + region[2] <= texture.get_width(), "frame %s fits the atlas width" % name)
			t.assert_true(region[1] + region[3] <= texture.get_height(), "frame %s fits the atlas height" % name)

func _assert_frames(t, frames_path: String, expected: Dictionary) -> void:
	var frames: SpriteFrames = load(frames_path)
	t.assert_true(frames != null, "%s loads" % frames_path.get_file())
	if frames == null:
		return
	t.assert_false(frames.has_animation("default"), "the default placeholder animation is stripped")
	for name: String in expected:
		t.assert_true(frames.has_animation(name), "animation %s exists" % name)
		if frames.has_animation(name):
			t.assert_eq(frames.get_frame_count(name), expected[name], "animation %s has %d frames" % [name, expected[name]])
			t.assert_true(frames.get_animation_speed(name) > 0.0, "animation %s carries a playback speed" % name)
			var texture := frames.get_frame_texture(name, 0)
			t.assert_true(texture is AtlasTexture, "animation %s uses atlas slices" % name)

func _assert_wiring(t) -> void:
	var definition: MobDefinition = load("res://data/mobs/meadow_slime.tres")
	t.assert_true(definition != null, "the meadow slime definition loads")
	if definition == null:
		return
	t.assert_true(definition.sprite_frames != null, "the slime is wired to generated sprites")
	t.assert_true(definition.hit_effect != null, "the slime is wired to its attack effect")
	t.assert_true(definition.sprite_frames == load(MOB_FRAMES), "the slime uses the pipeline frames")
	t.assert_true(definition.hit_effect == load(EFFECT_FRAMES), "the slime uses the pipeline effect")

func _assert_runtime(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame
	var player: Player = world.get_node("Player")
	player.hp = player.max_hp
	for child: Node in world.get_children():
		if child.is_in_group("enemies"):
			child.queue_free()
	await t.physics_frame
	await t.physics_frame
	DebugManager.god_mode = false
	DebugManager.disable_ai = false

	var definition: MobDefinition = load("res://data/mobs/meadow_slime.tres")
	var mob: Mob = load("res://scenes/mobs/mob.tscn").instantiate()
	mob.definition = definition
	player.global_position = Vector2(600.0, -60.0)
	await t.physics_frame
	await t.physics_frame
	mob.global_position = Vector2(0.0, -46.0)
	world.add_child(mob)
	await t.physics_frame
	await t.physics_frame

	var sprite := mob.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
	t.assert_true(sprite != null, "the mob builds an animated sprite")
	var body := mob.get_node_or_null("Visual/Body") as ColorRect
	t.assert_true(body != null and not body.visible, "the placeholder body hides when art is present")
	DebugManager.disable_ai = true
	await t.physics_frame
	await t.physics_frame
	if sprite != null:
		t.assert_eq(sprite.animation, &"idle", "the mob idles when standing still")
	DebugManager.disable_ai = false

	player.global_position = Vector2(400.0, -60.0)
	var hopped := await _wait_until(t, func() -> bool:
		return sprite != null and sprite.animation == &"hop", 240)
	t.assert_true(hopped, "the mob hops while moving")

	player.global_position = mob.global_position + Vector2(24.0, 0.0)
	var struck := await _wait_until(t, func() -> bool:
		return player.hp < player.max_hp, 180)
	t.assert_true(struck, "the slime lands a contact hit")
	if sprite != null:
		t.assert_eq(sprite.animation, &"attack", "the slime plays its attack animation on the hit")
	t.assert_true(_splash_present(t), "the attack spawns the generated splash effect")

	mob.take_damage(1.0, null)
	if sprite != null:
		t.assert_eq(sprite.animation, &"hit", "the slime reacts to damage")

	var plain_definition: MobDefinition = load("res://data/mobs/lesser_slime.tres")
	var plain: Mob = load("res://scenes/mobs/mob.tscn").instantiate()
	plain.definition = plain_definition
	plain.global_position = Vector2(-200.0, -46.0)
	world.add_child(plain)
	await t.physics_frame
	var plain_body := plain.get_node_or_null("Visual/Body") as ColorRect
	t.assert_true(plain_body != null and plain_body.visible, "mobs without art keep the placeholder")
	var plain_sprite := plain.get_node_or_null("Visual/Sprite") as AnimatedSprite2D
	t.assert_true(plain_sprite == null or not plain_sprite.visible, "mobs without art hide the sprite layer")

	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _splash_present(t) -> bool:
	for node: Node in t.get_nodes_in_group("effects"):
		if is_instance_valid(node) and node is AnimatedSprite2D:
			var frames := (node as AnimatedSprite2D).sprite_frames
			if frames != null and frames.has_animation("slime_splash"):
				return true
	return false

func _wait_until(t, condition: Callable, max_frames: int) -> bool:
	for _i in range(max_frames):
		if condition.call():
			return true
		await t.physics_frame
	return condition.call()

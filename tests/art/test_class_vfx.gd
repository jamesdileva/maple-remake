extends RefCounted

const CLASSES := {
	"mage": {
		"effects": {"mage_sigil": {"frames": 8, "loop": true}, "mage_arcane_burst": {"frames": 6, "loop": false}},
		"abilities": {"mage_fire": "mage_sigil", "mage_ice": "mage_sigil"},
		"impacts": {"mage_fire": "mage_arcane_burst", "mage_ice": "mage_arcane_burst"},
	},
	"warrior": {
		"effects": {"warrior_charge": {"frames": 8, "loop": true}, "warrior_quake": {"frames": 6, "loop": false}},
		"abilities": {"warrior_heavy_slash": "warrior_charge", "warrior_shield_bash": "warrior_charge"},
		"impacts": {"warrior_heavy_slash": "warrior_quake", "warrior_shield_bash": "warrior_quake"},
	},
	"archer": {
		"effects": {"archer_reticle": {"frames": 8, "loop": true}, "archer_bolt": {"frames": 5, "loop": false}},
		"abilities": {"archer_quick_shot": "archer_reticle", "archer_scatter": "archer_reticle"},
		"impacts": {"archer_quick_shot": "archer_bolt", "archer_scatter": "archer_bolt"},
	},
	"assassin": {
		"effects": {"assassin_shroud": {"frames": 8, "loop": true}, "assassin_edge": {"frames": 6, "loop": false}},
		"abilities": {"assassin_strike": "assassin_shroud", "assassin_dash": "assassin_shroud"},
		"impacts": {"assassin_strike": "assassin_edge", "assassin_dash": "assassin_edge"},
	},
}

func get_suite_name() -> String:
	return "class_vfx"

func run(t) -> void:
	_assert_specs(t)
	_assert_atlases(t)
	_assert_frames(t)
	_assert_scenes(t)
	_assert_wiring(t)
	await _assert_runtime(t)
	t.complete_suite(get_suite_name())

func _assert_specs(t) -> void:
	for class_id: String in CLASSES:
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/vfx_specs/%s.json" % class_id))
		t.assert_true(spec is Dictionary, "%s vfx spec is authored" % class_id)
		if not spec is Dictionary:
			continue
		t.assert_true(spec.get("palette", {}).size() >= 4, "%s declares a vfx palette" % class_id)
		var effects: Array = spec.get("effects", [])
		t.assert_eq(effects.size(), 2, "%s declares a cast and an impact effect" % class_id)
		t.assert_true(FileAccess.file_exists("res://tools/art/vfx_specs/%s.approved" % class_id), "%s passed the approval gate" % class_id)

func _assert_atlases(t) -> void:
	for class_id: String in CLASSES:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/effects/%s_vfx.json" % class_id))
		t.assert_true(data is Dictionary, "%s vfx atlas json parses" % class_id)
		if not data is Dictionary:
			continue
		var texture: Texture2D = load(String(data.get("image", "")))
		t.assert_true(texture != null, "%s vfx atlas image is imported" % class_id)
		var animations: Dictionary = data.get("animations", {})
		t.assert_eq(animations.size(), 2, "%s vfx atlas packs two effects" % class_id)
		if texture == null:
			continue
		for effect_id: String in CLASSES[class_id]["effects"]:
			t.assert_true(animations.has(effect_id), "%s vfx atlas contains %s" % [class_id, effect_id])
			if not animations.has(effect_id):
				continue
			var entry: Dictionary = animations[effect_id]
			t.assert_eq(entry.get("loop", false), CLASSES[class_id]["effects"][effect_id]["loop"], "%s declares the %s loop flag" % [class_id, effect_id])
			for region: Array in entry.get("frames", []):
				t.assert_true(region[0] + region[2] <= texture.get_width(), "%s.%s frame fits the atlas width" % [class_id, effect_id])
				t.assert_true(region[1] + region[3] <= texture.get_height(), "%s.%s frame fits the atlas height" % [class_id, effect_id])

func _assert_frames(t) -> void:
	for class_id: String in CLASSES:
		var frames: SpriteFrames = load("res://data/visuals/%s_vfx_frames.tres" % class_id)
		t.assert_true(frames != null, "%s vfx frames load" % class_id)
		if frames == null:
			continue
		for effect_id: String in CLASSES[class_id]["effects"]:
			var expected: Dictionary = CLASSES[class_id]["effects"][effect_id]
			t.assert_true(frames.has_animation(effect_id), "%s frames has %s" % [class_id, effect_id])
			if not frames.has_animation(effect_id):
				continue
			t.assert_eq(frames.get_frame_count(effect_id), expected["frames"], "%s has %d frames" % [effect_id, expected["frames"]])
			t.assert_eq(frames.get_animation_loop(effect_id), expected["loop"], "%s loop flag matches the spec" % effect_id)
			t.assert_true(frames.get_animation_speed(effect_id) > 0.0, "%s carries a playback speed" % effect_id)
			t.assert_true(frames.get_frame_texture(effect_id, 0) is AtlasTexture, "%s uses atlas slices" % effect_id)

func _assert_scenes(t) -> void:
	for class_id: String in CLASSES:
		var frames: SpriteFrames = load("res://data/visuals/%s_vfx_frames.tres" % class_id)
		for effect_id: String in CLASSES[class_id]["effects"]:
			var scene: PackedScene = load("res://scenes/effects/%s.tscn" % effect_id)
			t.assert_true(scene != null, "%s effect scene loads" % effect_id)
			if scene == null:
				continue
			var instance: Node = scene.instantiate()
			t.assert_true(instance is SpriteEffect, "%s effect scene uses the sprite effect" % effect_id)
			if instance is SpriteEffect:
				t.assert_true((instance as SpriteEffect).frames == frames, "%s effect uses the %s frames" % [effect_id, class_id])
				t.assert_eq((instance as SpriteEffect).autoplay_animation, StringName(effect_id), "%s effect autoplays its own animation" % effect_id)
			instance.free()

func _assert_wiring(t) -> void:
	for class_id: String in CLASSES:
		for ability_id: String in CLASSES[class_id]["abilities"]:
			var ability: AbilityDefinition = load("res://data/abilities/%s.tres" % ability_id)
			t.assert_true(ability != null, "%s ability loads" % ability_id)
			if ability == null:
				continue
			t.assert_true(ability.cast_effect != null, "%s has a cast effect" % ability_id)
			if ability.cast_effect != null:
				t.assert_eq(ability.cast_effect.resource_path, "res://scenes/effects/%s.tscn" % CLASSES[class_id]["abilities"][ability_id], "%s uses the %s cast VFX" % [ability_id, class_id])
			t.assert_true(ability.impact_effect != null, "%s has an impact effect" % ability_id)
			if ability.impact_effect != null:
				t.assert_eq(ability.impact_effect.resource_path, "res://scenes/effects/%s.tscn" % CLASSES[class_id]["impacts"][ability_id], "%s uses the %s impact VFX" % [ability_id, class_id])

func _assert_runtime(t) -> void:
	for class_id: String in CLASSES:
		for effect_id: String in CLASSES[class_id]["effects"]:
			var expected: Dictionary = CLASSES[class_id]["effects"][effect_id]
			var scene: PackedScene = load("res://scenes/effects/%s.tscn" % effect_id)
			var effect: SpriteEffect = scene.instantiate()
			t.root.add_child(effect)
			await t.physics_frame
			t.assert_eq(effect.animation, StringName(effect_id), "%s plays on spawn" % effect_id)
			if expected["loop"]:
				for _i in range(40):
					await t.physics_frame
				t.assert_true(is_instance_valid(effect), "%s loops while its cast is active" % effect_id)
				if is_instance_valid(effect):
					effect.queue_free()
			else:
				var freed := false
				for _i in range(90):
					await t.physics_frame
					if not is_instance_valid(effect):
						freed = true
						break
				t.assert_true(freed, "%s frees itself after one play" % effect_id)
			await t.physics_frame

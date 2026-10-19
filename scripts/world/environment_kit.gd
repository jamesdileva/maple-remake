class_name EnvironmentKit
extends Resource

@export var id := &""
@export var cell := Vector2(128, 128)
@export var props: Dictionary = {}

func has_prop(prop_name: StringName) -> bool:
	return props.has(String(prop_name))

func get_prop(prop_name: StringName) -> PropSprite:
	return props.get(String(prop_name), null) as PropSprite

func prop_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key: String in props.keys():
		names.append(key)
	names.sort()
	return names

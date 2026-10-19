class_name PropLayer
extends Node2D

const GROUP := &"prop_layer"

@export var plan: DecorPlan
@export var decorate_on_ready := true

var placed_count := 0
var missing_props := PackedStringArray()

func _ready() -> void:
	add_to_group(GROUP)
	if decorate_on_ready:
		rebuild()

func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	placed_count = 0
	missing_props = PackedStringArray()
	if plan == null or plan.kit == null:
		return
	for index in range(plan.count()):
		var prop_name := plan.props[index]
		var prop := plan.kit.get_prop(prop_name)
		if prop == null or prop.texture == null:
			missing_props.append(prop_name)
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Prop%s%02d" % [prop_name.capitalize(), index]
		sprite.texture = prop.texture
		sprite.offset = -prop.pivot
		sprite.scale = Vector2.ONE * (prop.default_scale * plan.scale_at(index))
		sprite.flip_h = plan.flip_at(index)
		sprite.position = plan.positions[index]
		sprite.z_index = plan.z_index
		sprite.add_to_group(&"decor")
		add_child(sprite)
		placed_count += 1
	_report()

func _report() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var debug: Node = tree.root.get_node_or_null("DebugManager")
	if debug != null and debug.has_method("register_combat_event"):
		debug.register_combat_event("env_decor", {
			"kit": String(plan.kit.id) if plan != null and plan.kit != null else "",
			"plan": String(plan.id) if plan != null else String(name),
			"placed": placed_count,
			"requested": plan.count() if plan != null else 0,
			"missing": missing_props,
		})

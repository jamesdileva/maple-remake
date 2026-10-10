class_name TargetQuery
extends RefCounted

const TARGET_MASK := 1
const MAX_QUERY_HITS := 64

static func enemies_in_area(origin: Node2D, facing: int, range: float, width: float, max_targets: int = 0, exclude = null) -> Array:
	var space := origin.get_world_2d().direct_space_state
	if space == null:
		return []
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(range, width)
	query.shape = shape
	query.transform = Transform2D(0.0, origin.global_position + Vector2(float(facing) * range * 0.5, 0.0))
	query.collision_mask = TARGET_MASK
	var hits := space.intersect_shape(query, MAX_QUERY_HITS)
	var found: Array = []
	for hit: Dictionary in hits:
		var candidate: Object = hit.get("collider")
		if candidate == null or found.has(candidate):
			continue
		if is_instance_valid(exclude) and candidate == exclude:
			continue
		if not _is_live_target(candidate):
			continue
		found.append(candidate)
	found.sort_custom(_by_distance_to.bind(origin.global_position))
	if max_targets > 0 and found.size() > max_targets:
		found = found.slice(0, max_targets)
	return found

static func _is_live_target(candidate: Object) -> bool:
	return candidate.has_method("take_damage") and candidate.has_method("is_dead") \
		and not candidate.is_dead()

static func _by_distance_to(a: Object, b: Object, origin: Vector2) -> bool:
	return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin)

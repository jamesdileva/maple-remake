class_name TargetQuery
extends RefCounted

const TARGET_MASK := CollisionLayers.MOBS
const MAX_QUERY_HITS := 1024

static func enemies_in_area(origin: Node2D, facing: int, range: float, width: float, max_targets: int = 0, exclude = null) -> Array:
	return _query(origin, origin.global_position + Vector2(float(facing) * range * 0.5, 0.0), range, width, max_targets, exclude)

static func enemies_in_blast(origin: Node2D, range: float, width: float, max_targets: int = 0, exclude = null) -> Array:
	return _query(origin, origin.global_position, range, width, max_targets, exclude)

static func enemies_in_chain(origin: Node2D, facing: int, range: float, width: float, jumps: int, radius: float, exclude = null) -> Array:
	var first := enemies_in_area(origin, facing, range, width, 1, exclude)
	if first.is_empty():
		return []
	var sequence: Array = [first[0]]
	var hit: Array = [first[0]]
	if exclude != null and is_instance_valid(exclude) and not hit.has(exclude):
		hit.append(exclude)
	for _jump in range(maxi(0, jumps)):
		var anchor: Object = sequence.back()
		var next := _nearest_live(origin, anchor.global_position, radius, hit)
		if next == null:
			break
		sequence.append(next)
		hit.append(next)
	return sequence

static func _nearest_live(origin: Node2D, point: Vector2, radius: float, skip: Array) -> Object:
	var best: Object = null
	var best_distance := INF
	for candidate: Object in origin.get_tree().get_nodes_in_group("enemies"):
		if skip.has(candidate):
			continue
		if not _is_live_target(candidate):
			continue
		var distance: float = candidate.global_position.distance_to(point)
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best = candidate
	return best

static func _query(origin: Node2D, center: Vector2, range: float, width: float, max_targets: int, exclude) -> Array:
	var space := origin.get_world_2d().direct_space_state
	if space == null:
		return []
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(range, width)
	query.shape = shape
	query.transform = Transform2D(0.0, center)
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

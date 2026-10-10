class_name DamageSystem
extends RefCounted

const DEFAULT_CRIT_CHANCE := 0.0
const DEFAULT_CRIT_MULTIPLIER := 2.0

static var _rng: RandomNumberGenerator

static func apply(event: DamageEvent) -> DamageResult:
	var result := DamageResult.new()
	result.event = event
	if event == null:
		_invalidate(result, &"no_event")
		return result
	if not _check_target(event, result):
		return result
	_roll_crit(event, result)
	_apply_defense(event, result)
	var remaining: float = event.target.apply_damage(result.applied)
	result.overkill = maxf(0.0, -remaining)
	result.killed = remaining <= 0.0
	_publish(event, result)
	if result.killed:
		event.target.die(event)
	return result

static func roll_crit(chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return _get_rng().randf() < chance

static func _check_target(event: DamageEvent, result: DamageResult) -> bool:
	if not is_instance_valid(event.target):
		_invalidate(result, &"no_target")
		return false
	for method: StringName in [&"is_dead", &"apply_damage", &"die"]:
		if not event.target.has_method(method):
			_invalidate(result, &"bad_interface")
			return false
	if event.target.is_dead():
		_invalidate(result, &"already_dead")
		return false
	return true

static func _invalidate(result: DamageResult, reason: StringName) -> void:
	result.valid = false
	result.invalid_reason = reason

static func _roll_crit(event: DamageEvent, result: DamageResult) -> void:
	result.crit_multiplier = _crit_multiplier(event.source)
	if not event.can_crit:
		result.amount_after_crit = maxf(0.0, event.base_amount)
		return
	if DebugManager.force_crit:
		result.is_crit = true
	else:
		result.is_crit = roll_crit(_crit_chance(event.source, event.crit_chance_override))
	result.amount_after_crit = maxf(0.0, event.base_amount * result.crit_multiplier if result.is_crit else event.base_amount)

static func _apply_defense(event: DamageEvent, result: DamageResult) -> void:
	result.defense = _defense(event.target)
	result.applied = maxf(0.0, result.amount_after_crit - result.defense)

static func _publish(event: DamageEvent, result: DamageResult) -> void:
	DebugManager.register_combat_event("damage_dealt", {
		"amount": result.applied,
		"is_crit": result.is_crit,
		"source": _describe(event.source),
		"target": _describe(event.target),
	})
	DebugManager.register_combat_event("damage_taken", {
		"amount": result.applied,
		"is_crit": result.is_crit,
		"source": _describe(event.source),
		"target": _describe(event.target),
	})
	EventBus.damage_applied.emit(result)

static func _describe(node) -> String:
	if not is_instance_valid(node):
		return "freed"
	return str(node)

static func _crit_chance(source, override: float) -> float:
	if override >= 0.0:
		return override
	if is_instance_valid(source) and source.has_method("get_crit_chance"):
		return maxf(0.0, float(source.get_crit_chance()))
	return DEFAULT_CRIT_CHANCE

static func _crit_multiplier(source) -> float:
	if is_instance_valid(source) and source.has_method("get_crit_multiplier"):
		return maxf(1.0, float(source.get_crit_multiplier()))
	return DEFAULT_CRIT_MULTIPLIER

static func _defense(target) -> float:
	if target.has_method("get_defense"):
		return maxf(0.0, float(target.get_defense()))
	return 0.0

static func _get_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	return _rng

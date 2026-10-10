extends RefCounted

class FakeTarget:
	extends RefCounted
	var hp := 30.0
	var defense_value := 0.0
	var deaths := 0

	func is_dead() -> bool:
		return hp <= 0.0

	func apply_damage(amount: float) -> float:
		hp -= amount
		return hp

	func die(_event: DamageEvent) -> void:
		deaths += 1

	func get_defense() -> float:
		return defense_value

class FakeSource:
	extends RefCounted
	var chance := 0.0
	var multiplier := 2.0

	func get_crit_chance() -> float:
		return chance

	func get_crit_multiplier() -> float:
		return multiplier

func get_suite_name() -> String:
	return "damage_system"

func run(t) -> void:
	DebugManager.reset_counters()
	DebugManager.force_crit = false
	var emitted: Array = []
	EventBus.damage_applied.connect(func(result: DamageResult): emitted.append(result))

	t.assert_false(DamageSystem.roll_crit(0.0), "zero crit chance never crits")
	t.assert_true(DamageSystem.roll_crit(1.0), "guaranteed crit chance always crits")

	var target := FakeTarget.new()
	var result := DamageSystem.apply(_hit(target, 12.0, 0.0))
	t.assert_true(result.valid, "normal hit is valid")
	t.assert_false(result.is_crit, "normal hit does not crit")
	t.assert_eq(result.applied, 12.0, "normal hit applies base damage")
	t.assert_eq(target.hp, 18.0, "normal hit reduces hp")
	t.assert_false(result.killed, "normal hit does not kill")
	t.assert_eq(result.overkill, 0.0, "normal hit has no overkill")
	t.assert_eq(emitted.size(), 1, "normal hit emits one damage event")
	t.assert_eq(DebugManager.counters.damage_dealt, 12.0, "damage dealt telemetry matches")
	t.assert_eq(DebugManager.counters.damage_taken, 12.0, "damage taken telemetry matches")

	target = FakeTarget.new()
	result = DamageSystem.apply(_hit(target, 12.0, 1.0))
	t.assert_true(result.is_crit, "guaranteed chance crits")
	t.assert_eq(result.applied, 24.0, "crit doubles base damage")
	t.assert_eq(target.hp, 6.0, "crit reduces hp accordingly")
	t.assert_eq(DebugManager.counters.crits, 1, "crit telemetry counted")

	var source := FakeSource.new()
	source.chance = 1.0
	source.multiplier = 3.0
	target = FakeTarget.new()
	var event := DamageEvent.create(target, 12.0, source)
	result = DamageSystem.apply(event)
	t.assert_true(result.is_crit, "source crit stats drive the roll")
	t.assert_eq(result.applied, 36.0, "source crit multiplier applies")

	target = FakeTarget.new()
	event = DamageEvent.create(target, 12.0, source)
	event.can_crit = false
	result = DamageSystem.apply(event)
	t.assert_false(result.is_crit, "can_crit false blocks crits")
	t.assert_eq(result.applied, 12.0, "blocked crit deals base damage")

	DebugManager.force_crit = true
	target = FakeTarget.new()
	result = DamageSystem.apply(_hit(target, 12.0, 0.0))
	t.assert_true(result.is_crit, "force crit flag forces a crit")
	DebugManager.force_crit = false

	target = FakeTarget.new()
	target.defense_value = 10.0
	result = DamageSystem.apply(_hit(target, 12.0, 0.0))
	t.assert_eq(result.applied, 2.0, "defense subtracts from the hit")
	t.assert_eq(result.defense, 10.0, "result reports mitigated defense")
	t.assert_eq(target.hp, 28.0, "mitigated hit reduces hp accordingly")

	target = FakeTarget.new()
	target.defense_value = 50.0
	result = DamageSystem.apply(_hit(target, 12.0, 0.0))
	t.assert_eq(result.applied, 0.0, "defense can fully absorb a hit")
	t.assert_false(result.killed, "absorbed hit does not kill")
	t.assert_eq(target.deaths, 0, "absorbed hit triggers no death")

	target = FakeTarget.new()
	result = DamageSystem.apply(_hit(target, 30.0, 0.0))
	t.assert_true(result.killed, "lethal hit kills")
	t.assert_eq(result.applied, 30.0, "lethal hit applies full damage")
	t.assert_eq(result.overkill, 0.0, "exact lethal hit has no overkill")
	t.assert_eq(target.deaths, 1, "lethal hit triggers exactly one death")
	t.assert_eq(DebugManager.counters.kills, 0, "fake deaths do not touch the kill counter")

	target = FakeTarget.new()
	result = DamageSystem.apply(_hit(target, 9999.0, 0.0))
	t.assert_true(result.killed, "overkill kills")
	t.assert_eq(result.applied, 9999.0, "overkill reports the full amount")
	t.assert_eq(result.overkill, 9969.0, "overkill reports damage beyond remaining hp")
	t.assert_eq(target.deaths, 1, "overkill triggers exactly one death")

	var before := emitted.size()
	result = DamageSystem.apply(DamageEvent.create(null, 12.0, null))
	t.assert_false(result.valid, "null target is invalid")
	t.assert_eq(result.invalid_reason, &"no_target", "null target reports its reason")
	t.assert_eq(result.applied, 0.0, "invalid hit applies nothing")
	t.assert_eq(emitted.size(), before, "invalid hit emits no damage event")

	var doomed := Object.new()
	doomed.free()
	result = DamageSystem.apply(DamageEvent.create(doomed, 12.0, null))
	t.assert_false(result.valid, "freed target is invalid")
	t.assert_eq(emitted.size(), before, "freed target emits no damage event")

	target = FakeTarget.new()
	target.hp = 0.0
	result = DamageSystem.apply(_hit(target, 12.0, 0.0))
	t.assert_false(result.valid, "already-dead target is invalid")
	t.assert_eq(result.invalid_reason, &"already_dead", "dead target reports its reason")
	t.assert_eq(target.deaths, 0, "dead target dies no further")
	t.assert_eq(emitted.size(), before, "dead target emits no damage event")

	result = DamageSystem.apply(DamageEvent.create(Object.new(), 12.0, null))
	t.assert_false(result.valid, "target without the combat interface is invalid")
	t.assert_eq(result.invalid_reason, &"bad_interface", "bad interface reports its reason")
	t.assert_eq(emitted.size(), before, "bad interface emits no damage event")

	t.complete_suite(get_suite_name())

func _hit(target: Object, base_amount: float, crit_chance: float) -> DamageEvent:
	var event := DamageEvent.create(target, base_amount, null)
	event.crit_chance_override = crit_chance
	return event

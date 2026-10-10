class_name DamageEvent
extends RefCounted

var source
var target
var base_amount := 0.0
var can_crit := true
var crit_chance_override := -1.0

static func create(target, base_amount: float, source = null) -> DamageEvent:
	var event := DamageEvent.new()
	event.target = target
	event.base_amount = base_amount
	event.source = source
	return event

class_name DamageResult
extends RefCounted

var event: DamageEvent
var valid := true
var invalid_reason := &""
var is_crit := false
var crit_multiplier := 1.0
var amount_after_crit := 0.0
var defense := 0.0
var applied := 0.0
var overkill := 0.0
var killed := false

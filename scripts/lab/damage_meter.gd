class_name DamageMeter
extends RefCounted

var running := false

var total_damage := 0.0
var hits := 0
var crits := 0
var kills := 0
var skill_uses: Dictionary = {}
var targets_hit_total := 0
var distinct_targets := 0

var _target_ids: Dictionary = {}
var _start_msec := 0
var _elapsed_msec := 0
var _boss_start_msec := 0
var _boss_elapsed_msec := 0
var _boss_running := false

func start() -> void:
	reset()
	running = true
	_start_msec = Time.get_ticks_msec()

func stop() -> void:
	if running:
		_elapsed_msec = Time.get_ticks_msec() - _start_msec
		running = false

func reset() -> void:
	running = false
	total_damage = 0.0
	hits = 0
	crits = 0
	kills = 0
	skill_uses.clear()
	targets_hit_total = 0
	distinct_targets = 0
	_target_ids.clear()
	_elapsed_msec = 0
	_boss_elapsed_msec = 0
	_boss_running = false

func start_boss() -> void:
	_boss_running = true
	_boss_start_msec = Time.get_ticks_msec()

func stop_boss() -> void:
	if _boss_running:
		_boss_elapsed_msec = Time.get_ticks_msec() - _boss_start_msec
		_boss_running = false

func elapsed_sec() -> float:
	if running:
		return float(Time.get_ticks_msec() - _start_msec) / 1000.0
	return float(_elapsed_msec) / 1000.0

func boss_time_sec() -> float:
	if _boss_running:
		return float(Time.get_ticks_msec() - _boss_start_msec) / 1000.0
	return float(_boss_elapsed_msec) / 1000.0

func dps() -> float:
	var elapsed := elapsed_sec()
	if elapsed <= 0.0:
		return 0.0
	return total_damage / elapsed

func summary() -> Dictionary:
	return {
		"total_damage": total_damage,
		"dps": dps(),
		"hits": hits,
		"crits": crits,
		"kills": kills,
		"skill_uses": skill_uses.duplicate(),
		"targets_hit": targets_hit_total,
		"distinct_targets": distinct_targets,
		"elapsed_sec": elapsed_sec(),
		"boss_time_sec": boss_time_sec(),
	}

func record_damage(result: DamageResult) -> void:
	if not running or result == null or not result.valid:
		return
	total_damage += result.applied
	hits += 1
	if result.is_crit:
		crits += 1
	var target = result.event.target
	if target != null and is_instance_valid(target):
		var target_id: int = target.get_instance_id()
		if not _target_ids.has(target_id):
			_target_ids[target_id] = true
			distinct_targets += 1

func record_kill(_mob_id: StringName, _xp: float, _definition: Resource) -> void:
	if running:
		kills += 1

func record_cast(ability: AbilityDefinition, targets_hit: int) -> void:
	if not running or ability == null:
		return
	skill_uses[ability.id] = int(skill_uses.get(ability.id, 0)) + 1
	targets_hit_total += targets_hit

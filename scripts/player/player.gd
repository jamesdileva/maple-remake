class_name Player
extends CharacterBody2D

signal state_changed(new_state: StringName)

enum State { IDLE, RUN, JUMP, FALL }

@export var run_speed := 280.0
@export var ground_acceleration := 2400.0
@export var ground_deceleration := 2600.0
@export var air_acceleration := 1800.0
@export var air_deceleration := 400.0
@export var jump_velocity := 640.0
@export var gravity := 1900.0
@export var rise_gravity_multiplier := 0.55
@export var fall_gravity_multiplier := 1.35
@export var jump_cut_multiplier := 2.2
@export var coyote_time := 0.09
@export var jump_buffer_time := 0.1
@export var visual_path: NodePath = NodePath("Visual")
@export var attack_hitbox_path: NodePath = NodePath("AttackHitbox")

@export var max_hp := 100.0
@export var hp := 100.0
@export var max_mana := 100.0
@export var mana := 100.0
@export var mana_regen_per_second := 8.0
@export var defense := 0.0
@export var crit_chance := 0.05
@export var crit_multiplier := 2.0
@export var basic_attack_damage := 12.0
@export var basic_attack_cooldown := 0.35
@export var basic_attack_duration := 0.12
@export var basic_attack_range := 52.0
@export var ability_slots: Array[AbilityDefinition] = []
@export var class_definition: ClassDefinition
@export var max_summons := 3
@export var xp_table: XpTable
@export var hp_per_level := 8.0
@export var mana_per_level := 4.0

var inventory := Inventory.new()
var level := 1
var xp := 0.0
var skill_points := 0
var skill_points_spent := 0
var ability_levels: Dictionary = {}
var equipment: Dictionary = {}
var _base_run_speed := -1.0
var advanced := false
var party: Array = []
var _last_aura_hp := 0.0
var _last_aura_mp := 0.0
var _shield_hp := 0.0
var _shield_lifetime := 0.0
var _absorbed_total := 0.0
var _summons: Array = []
var _lethal_cooldown := 0.0
var _lethal_window := 0.0
var _lethal_triggers := 0

signal died
signal attack_started
signal cast_started(ability: AbilityDefinition)
signal cast_completed(ability: AbilityDefinition, targets_hit: int)
signal leveled_up(new_level: int)
signal xp_gained(amount: float)
signal skill_points_changed(total: int)
signal skill_reset
signal shield_broken
signal shield_applied(amount: float)
signal summon_spawned(summon: Summon)
signal class_advanced
signal lethal_protection_triggered
signal party_aura_changed(hp_bonus: float, mp_bonus: float)

const ABILITY_SLOT_COUNT := 6

var state: State = State.IDLE:
	set(value):
		if value == state:
			return
		state = value
		state_changed.emit(_state_name(value))

var move_direction := 0.0
var facing := 1

var _coyote := 0.0
var _jump_buffer := 0.0
var _attack_timer := 0.0
var _attack_active := 0.0
var _attack_hit_targets: Array = []
var _visual: Node2D
var _attack_hitbox: Area2D
var _cast_timer := 0.0
var _cast_ability: AbilityDefinition
var _cast_telegraph: Node2D

func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Node2D
	_attack_hitbox = get_node_or_null(attack_hitbox_path) as Area2D
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false
	_base_run_speed = run_speed
	_apply_level_stats()
	hp = max_hp
	mana = max_mana
	if class_definition != null:
		apply_class(class_definition)
	add_to_group("player")
	EventBus.mob_died.connect(_on_mob_died)

func _on_mob_died(_mob_id: StringName, mob_xp: float, _definition: Resource) -> void:
	grant_xp(mob_xp)

func is_casting() -> bool:
	return _cast_timer > 0.0

func cast_progress() -> float:
	if _cast_ability == null or _cast_ability.cast_time <= 0.0:
		return 0.0
	return 1.0 - (_cast_timer / _cast_ability.cast_time)

func current_ability() -> AbilityDefinition:
	return _cast_ability

func ability_at(slot: int) -> AbilityDefinition:
	var slots := _effective_slots()
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]

func _effective_slots() -> Array:
	if class_definition != null:
		if advanced and class_definition.advanced_ability_slots.size() > 0:
			return class_definition.advanced_ability_slots
		if class_definition.ability_slots.size() > 0:
			return class_definition.ability_slots
	return ability_slots

func apply_class(character_class: ClassDefinition) -> void:
	if character_class == null:
		return
	class_definition = character_class
	advanced = false
	defense = character_class.defense
	crit_chance = character_class.crit_chance
	crit_multiplier = character_class.crit_multiplier
	mana_regen_per_second = character_class.mana_regen_per_second
	run_speed = _base_run_speed if _base_run_speed > 0.0 else run_speed
	max_hp = character_class.starting_hp
	max_mana = character_class.starting_mana
	_recalculate_stats()
	hp = max_hp
	mana = max_mana
	_apply_class_visual()
	DebugManager.register_combat_event("class_applied", {"class": character_class.id})

func can_advance() -> bool:
	if advanced:
		return false
	if class_definition == null:
		return false
	if class_definition.advanced_ability_slots.is_empty():
		return false
	return level >= class_definition.advancement_level

func advance() -> bool:
	if not can_advance():
		return false
	advanced = true
	defense += class_definition.advanced_defense_bonus
	crit_chance += class_definition.advanced_crit_bonus
	run_speed = _base_run_speed * (1.0 + class_definition.advanced_speed_bonus)
	_recalculate_stats()
	hp = max_hp
	mana = max_mana
	_apply_class_visual()
	class_advanced.emit()
	DebugManager.register_combat_event("advanced", {
		"class": class_definition.id,
		"level": level,
	})
	return true

func _apply_class_visual() -> void:
	var aura := get_node_or_null("AdvancedAura") as ColorRect
	if aura != null:
		aura.visible = advanced
	var body := get_node_or_null("Visual/Body") as ColorRect
	if body != null:
		if advanced:
			if not body.has_meta("base_color"):
				body.set_meta("base_color", body.color)
			body.color = Color(0.75, 0.6, 1.0)
		elif body.has_meta("base_color"):
			body.color = body.get_meta("base_color")

func shield_hp() -> float:
	return _shield_hp

func is_shielded() -> bool:
	return _shield_hp > 0.0

func active_summons() -> int:
	var count := 0
	for summon in _summons:
		if is_instance_valid(summon):
			count += 1
	return count

func release_summon(summon: Summon) -> void:
	if is_instance_valid(summon):
		summon.queue_free()
	_summons.erase(summon)

func take_damage(amount: float, source: Node = null) -> float:
	if DebugManager.is_invulnerable():
		return 0.0
	var incoming := amount
	if _lethal_window > 0.0:
		return 0.0
	if _shield_hp > 0.0:
		var absorbed := minf(_shield_hp, incoming)
		_shield_hp -= absorbed
		_absorbed_total += absorbed
		incoming -= absorbed
		DebugManager.register_combat_event("shield_absorb", {
			"absorbed": absorbed,
			"remaining": _shield_hp,
		})
		if _shield_hp <= 0.0:
			shield_broken.emit()
		if incoming <= 0.0:
			return 0.0
	if incoming >= hp and _consume_lethal_protection():
		return 0.0
	var event := DamageEvent.create(self, incoming, source)
	return DamageSystem.apply(event).applied

func is_lethal_protected() -> bool:
	return _lethal_window > 0.0

func lethal_protection_remaining() -> float:
	return _lethal_window

func lethal_protection_cooldown() -> float:
	return _lethal_cooldown

func lethal_trigger_count() -> int:
	return _lethal_triggers

func _consume_lethal_protection() -> bool:
	if class_definition == null:
		return false
	if _lethal_cooldown > 0.0:
		return false
	_lethal_cooldown = class_definition.party_buff_interval
	_lethal_window = class_definition.party_buff_duration
	_lethal_triggers += 1
	hp = 1.0
	lethal_protection_triggered.emit()
	EventBus.lethal_protection.emit(1.0, class_definition.id)
	DebugManager.register_combat_event("lethal_protection", {
		"duration": class_definition.party_buff_duration,
		"interval": class_definition.party_buff_interval,
	})
	return true

func _tick_lethal_protection(delta: float) -> void:
	_lethal_cooldown = maxf(0.0, _lethal_cooldown - delta)
	_lethal_window = maxf(0.0, _lethal_window - delta)

func apply_damage(amount: float) -> float:
	hp -= amount
	return hp

func is_dead() -> bool:
	return hp <= 0.0

func die(_event: DamageEvent) -> void:
	DebugManager.register_combat_event("death", {})
	EventBus.player_died.emit()
	died.emit()
	hp = max_hp
	global_position = Vector2(0.0, -60.0)
	velocity = Vector2.ZERO

func get_defense() -> float:
	return defense + _equipment_bonus(&"defense_bonus")

func equipment_power() -> float:
	return _equipment_bonus(&"power")

func equipped_in(slot_name: StringName) -> EquipmentDefinition:
	return equipment.get(slot_name)

func equip(item: EquipmentDefinition) -> EquipmentDefinition:
	if item == null:
		return null
	if level < item.level_requirement:
		return item
	var slot_name := item.slot_name()
	var replaced: EquipmentDefinition = equipment.get(slot_name)
	equipment[slot_name] = item
	_recalculate_stats()
	DebugManager.register_combat_event("equip", {"item": item.id, "slot": slot_name})
	return replaced

func unequip(slot_name: StringName) -> EquipmentDefinition:
	var removed: EquipmentDefinition = equipment.get(slot_name)
	if removed == null:
		return null
	equipment.erase(slot_name)
	_recalculate_stats()
	return removed

func capture_state() -> Dictionary:
	var worn := {}
	for slot_name in equipment:
		var item: EquipmentDefinition = equipment[slot_name]
		worn[slot_name] = item.resource_path if item != null else ""
	var levels := {}
	for ability_id: StringName in ability_levels:
		levels[String(ability_id)] = ability_levels[ability_id]
	var items := {}
	for item_id: StringName in inventory.items:
		items[String(item_id)] = inventory.items[item_id]
	return {
		"level": level,
		"xp": xp,
		"hp": hp,
		"mana": mana,
		"skill_points": skill_points,
		"skill_points_spent": skill_points_spent,
		"ability_levels": levels,
		"equipment": worn,
		"inventory_items": items,
		"currency": inventory.currency,
		"advanced": advanced,
		"class_path": class_definition.resource_path if class_definition != null else "",
	}

func restore_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var class_path: String = data.get("class_path", "")
	if not class_path.is_empty():
		var loaded_class: ClassDefinition = load(class_path)
		if loaded_class != null:
			apply_class(loaded_class)
	level = int(data.get("level", 1))
	xp = float(data.get("xp", 0.0))
	skill_points = int(data.get("skill_points", 0))
	skill_points_spent = int(data.get("skill_points_spent", 0))
	advanced = bool(data.get("advanced", false))
	_apply_class_visual()
	ability_levels.clear()
	var levels: Dictionary = data.get("ability_levels", {})
	for ability_id in levels:
		ability_levels[StringName(ability_id)] = int(levels[ability_id])
	equipment.clear()
	var worn: Dictionary = data.get("equipment", {})
	for slot_name in worn:
		var item_path: String = worn[slot_name]
		if item_path.is_empty():
			continue
		var loaded: EquipmentDefinition = load(item_path)
		if loaded != null:
			equipment[StringName(slot_name)] = loaded
	inventory.items.clear()
	var stored_items: Dictionary = data.get("inventory_items", {})
	for item_id in stored_items:
		inventory.items[StringName(item_id)] = int(stored_items[item_id])
	inventory.currency = int(data.get("currency", 0))
	_recalculate_stats()
	hp = clampf(float(data.get("hp", max_hp)), 0.0, max_hp)
	mana = clampf(float(data.get("mana", max_mana)), 0.0, max_mana)

func _equipment_bonus(field: StringName) -> float:
	var total := 0.0
	for slot_name in equipment:
		var item: EquipmentDefinition = equipment[slot_name]
		if item != null:
			total += float(item.get(field))
	return total

func get_crit_chance() -> float:
	return crit_chance

func get_crit_multiplier() -> float:
	return crit_multiplier

func apply_debug_kill() -> void:
	take_damage(999999.0, null)

func heal_full() -> void:
	hp = max_hp

func get_inventory() -> Inventory:
	return inventory

func grant_xp(amount: float) -> float:
	if xp_table == null or amount <= 0.0:
		return 0.0
	var granted := amount
	if xp_table.is_max_level(level):
		return 0.0
	xp += amount
	xp_gained.emit(amount)
	while not xp_table.is_max_level(level) and xp >= xp_table.xp_for_level(level + 1):
		level += 1
		_apply_level_stats()
		leveled_up.emit(level)
		DebugManager.register_combat_event("level_up", {"level": level})
	return granted

func xp_into_level() -> float:
	if xp_table == null:
		return 0.0
	return xp - xp_table.xp_for_level(level)

func xp_to_next_level() -> float:
	if xp_table == null or xp_table.is_max_level(level):
		return 0.0
	return xp_table.xp_for_level(level + 1) - xp

func level_progress() -> float:
	if xp_table == null or xp_table.is_max_level(level):
		return 1.0
	var required := xp_table.xp_for_level(level + 1) - xp_table.xp_for_level(level)
	if required <= 0.0:
		return 1.0
	return clampf(xp_into_level() / required, 0.0, 1.0)

func ability_level(ability: AbilityDefinition) -> int:
	if ability == null:
		return 0
	return ability_levels.get(ability.id, 1)

func can_spend_skill_point(ability: AbilityDefinition) -> bool:
	if ability == null:
		return false
	if skill_points <= 0:
		return false
	if level < ability.unlock_level:
		return false
	return ability_level(ability) < ability.max_level

func spend_skill_point(ability: AbilityDefinition) -> bool:
	if not can_spend_skill_point(ability):
		return false
	skill_points -= 1
	skill_points_spent += 1
	ability_levels[ability.id] = ability_level(ability) + 1
	skill_points_changed.emit(skill_points)
	return true

func reset_skills() -> int:
	var refunded: int = skill_points_spent
	skill_points += refunded
	skill_points_spent = 0
	ability_levels.clear()
	skill_reset.emit()
	skill_points_changed.emit(skill_points)
	return refunded

func add_skill_points(count: int) -> int:
	if count <= 0:
		return 0
	skill_points += count
	skill_points_changed.emit(skill_points)
	return count

func set_level(new_level: int) -> void:
	var cap := xp_table.max_level if xp_table != null else 50
	var target := clampi(new_level, 1, cap)
	reset_skills()
	level = target
	xp = xp_table.xp_for_level(target) if xp_table != null else 0.0
	skill_points = maxi(0, target - 1)
	skill_points_spent = 0
	_recalculate_stats()
	hp = max_hp
	mana = max_mana
	DebugManager.register_combat_event("level_set", {"level": target})

func _apply_level_stats() -> void:
	_recalculate_stats()
	hp = max_hp
	mana = max_mana
	if level > 1:
		add_skill_points(1)

func _recalculate_stats() -> void:
	var base_hp := _class_starting_hp()
	var base_mana := _class_starting_mana()
	var aura := effective_party_bonus()
	max_hp = base_hp + hp_per_level * float(level - 1) + _equipment_bonus(&"max_hp_bonus") + aura.x
	max_mana = base_mana + mana_per_level * float(level - 1) + _equipment_bonus(&"max_mana_bonus") + aura.y
	hp = minf(hp, max_hp)
	mana = minf(mana, max_mana)
	if aura.x != _last_aura_hp or aura.y != _last_aura_mp:
		_last_aura_hp = aura.x
		_last_aura_mp = aura.y
		party_aura_changed.emit(aura.x, aura.y)
		DebugManager.register_combat_event("party_aura", {"hp": aura.x, "mp": aura.y})

func effective_party_bonus() -> Vector2:
	var roster := party if not party.is_empty() else [self]
	var best := Vector2.ZERO
	for member in roster:
		if not is_instance_valid(member):
			continue
		var member_class: ClassDefinition = member.get("class_definition")
		if member_class == null:
			continue
		best.x = maxf(best.x, member_class.party_hp_bonus)
		best.y = maxf(best.y, member_class.party_mp_bonus)
	return best

func set_party(members: Array) -> void:
	party = members.duplicate()
	_recalculate_stats()

func leave_party() -> void:
	party.clear()
	_recalculate_stats()

func refresh_stats() -> void:
	_recalculate_stats()

func _class_starting_hp() -> float:
	return class_definition.starting_hp if class_definition != null else 100.0

func _class_starting_mana() -> float:
	return class_definition.starting_mana if class_definition != null else 100.0

func receive_loot(item: ItemDefinition, count: int) -> int:
	if item == null or count <= 0:
		return 0
	if item.is_currency():
		return inventory.add_currency(item.value * count)
	return inventory.add_item(item, count)

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_tick_attack(delta)
	_tick_cast(delta)
	_regenerate_mana(delta)
	move_direction = Input.get_axis("move_left", "move_right")
	_update_facing()
	_apply_horizontal(delta)
	_apply_gravity(delta)
	_apply_jump()
	if _casting_locked():
		velocity.x = 0.0
	move_and_slide()
	_update_state()

func _casting_locked() -> bool:
	return _cast_timer > 0.0

func _regenerate_mana(delta: float) -> void:
	if DebugManager.infinite_mana or mana >= max_mana:
		return
	mana = minf(max_mana, mana + mana_regen_per_second * delta)

func _tick_cast(delta: float) -> void:
	if _cast_timer > 0.0:
		_cast_timer = maxf(0.0, _cast_timer - delta)
		if _cast_timer == 0.0:
			_finish_cast()
		return
	_tick_shield(delta)
	_tick_summons(delta)
	for slot in ABILITY_SLOT_COUNT:
		if Input.is_action_just_pressed("skill_%d" % (slot + 1)):
			_try_cast_ability(slot)
			return

func _apply_shield(ability: AbilityDefinition) -> void:
	_shield_hp = ability.shield_absorb
	_shield_lifetime = ability.shield_duration
	shield_applied.emit(_shield_hp)
	DebugManager.register_combat_event("shield", {
		"ability": ability.id,
		"absorb": ability.shield_absorb,
		"duration": ability.shield_duration,
	})
	EventBus.shield_applied.emit(ability.id, ability.shield_absorb)

func _tick_shield(delta: float) -> void:
	_shield_lifetime = maxf(0.0, _shield_lifetime - delta)
	if _shield_lifetime <= 0.0 and _shield_hp > 0.0:
		_shield_hp = 0.0
	_tick_lethal_protection(delta)

func _tick_summons(delta: float) -> void:
	for summon in _summons.duplicate():
		if not is_instance_valid(summon):
			_summons.erase(summon)

func _try_cast_ability(slot: int) -> void:
	var ability := ability_at(slot)
	if ability == null:
		return
	var cost := ability.mana_cost_at(ability_level(ability))
	if not DebugManager.infinite_mana and cost > 0.0:
		if mana < cost:
			return
		mana -= cost
	_start_cast(ability)

func _start_cast(ability: AbilityDefinition) -> void:
	_cast_ability = ability
	if ability.cast_time <= 0.0:
		_finish_cast()
		return
	_cast_timer = ability.cast_time
	_spawn_cast_telegraph(ability)
	DebugManager.register_combat_event("cast", {
		"ability": ability.id,
		"phase": &"start",
		"cast_time": ability.cast_time,
		"mana_cost": ability.mana_cost_at(ability_level(ability)),
	})
	EventBus.ability_cast_started.emit(ability)
	cast_started.emit(ability)

func _finish_cast() -> void:
	var ability := _cast_ability
	_cast_ability = null
	_cast_timer = 0.0
	_free_cast_telegraph()
	if ability == null:
		return
	if ability.is_shield():
		_apply_shield(ability)
		return
	var targets: Array = _resolve_targets(ability)
	var targets_hit := 0
	var damage := ability.damage_at(ability_level(ability)) + equipment_power()
	var jump_index := 0
	for target: Object in targets:
		var multiplier := pow(ability.chain_falloff, float(jump_index)) if ability.chain_jumps > 0 else 1.0
		if ability.boss_multiplier != 1.0 and target is Mob:
			var target_definition: MobDefinition = (target as Mob).definition
			if target_definition != null and target_definition.is_boss:
				multiplier *= ability.boss_multiplier
		var result := DamageSystem.apply(DamageEvent.create(target, damage * multiplier, self))
		if result.valid:
			targets_hit += 1
			if ability.slow_duration > 0.0 and ability.slow_factor > 0.0 and target is Mob:
				(target as Mob).apply_slow(ability.slow_duration, ability.slow_factor)
			_spawn_impact_burst(ability, target)
		jump_index += 1
	if ability.is_summon():
		_spawn_summons(ability)
	DebugManager.register_combat_event("cast", {
		"ability": ability.id,
		"phase": &"complete",
		"targets_hit": targets_hit,
	})
	EventBus.ability_cast_completed.emit(ability, targets_hit)
	cast_completed.emit(ability, targets_hit)

func _spawn_summons(ability: AbilityDefinition) -> void:
	var slots := maxi(0, max_summons - active_summons())
	var to_spawn := mini(ability.summon_count, slots)
	var damage := ability.summon_damage + equipment_power()
	for index in range(to_spawn):
		var summon: Summon = ability.summon_scene.instantiate()
		var world := get_parent()
		if world == null:
			summon.queue_free()
			continue
		world.add_child(summon)
		summon.pool_owner = self
		summon.attack_interval = ability.summon_interval
		summon.damage = damage
		summon.duration = ability.summon_duration
		summon.global_position = global_position + Vector2(-24.0 + float(index) * 12.0, 24.0)
		_summons.append(summon)
		summon_spawned.emit(summon)
	DebugManager.register_combat_event("summon", {
		"ability": ability.id,
		"count": to_spawn,
		"active": active_summons(),
	})
	EventBus.summon_spawned.emit(ability.id, to_spawn)

func _resolve_targets(ability: AbilityDefinition) -> Array:
	if ability.chain_jumps > 0:
		return TargetQuery.enemies_in_chain(self, facing, ability.range, ability.width, ability.chain_jumps, ability.chain_radius, self)
	match ability.area_mode:
		AbilityDefinition.AreaMode.CENTERED:
			return TargetQuery.enemies_in_blast(self, ability.range, ability.width, ability.max_targets, self)
		_:
			return TargetQuery.enemies_in_area(self, facing, ability.range, ability.width, ability.max_targets, self)

func _spawn_cast_telegraph(ability: AbilityDefinition) -> void:
	if ability.cast_effect == null:
		return
	var telegraph: Node2D = ability.cast_effect.instantiate()
	telegraph.add_to_group("effects")
	add_child(telegraph)
	telegraph.scale = Vector2(ability.range / CastTelegraph.BASE_SIZE.x, ability.width / CastTelegraph.BASE_SIZE.y)
	if ability.area_mode == AbilityDefinition.AreaMode.CENTERED:
		telegraph.position = Vector2.ZERO
	else:
		telegraph.position = Vector2(float(facing) * ability.range * 0.5, 0.0)
	_cast_telegraph = telegraph

func _free_cast_telegraph() -> void:
	if _cast_telegraph != null:
		_cast_telegraph.queue_free()
		_cast_telegraph = null

func _spawn_impact_burst(ability: AbilityDefinition, target: Object) -> void:
	if ability.impact_effect == null:
		return
	var burst: Node2D = ability.impact_effect.instantiate()
	burst.add_to_group("effects")
	var world := get_parent()
	if world == null:
		burst.queue_free()
		return
	world.add_child(burst)
	burst.global_position = (target as Node2D).global_position

func _tick_attack(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if _attack_active > 0.0:
		_attack_active = maxf(0.0, _attack_active - delta)
		if _attack_active == 0.0:
			_end_basic_attack()
	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0 and _attack_active <= 0.0:
		_start_basic_attack()

func _start_basic_attack() -> void:
	_attack_timer = basic_attack_cooldown
	_attack_active = basic_attack_duration
	_attack_hit_targets.clear()
	if _attack_hitbox == null:
		return
	var hit_size: Vector2 = (_attack_hitbox.get_node("Collision").shape as RectangleShape2D).size
	_attack_hitbox.position = Vector2(float(facing) * basic_attack_range * 0.5, 0.0)
	_attack_hitbox.scale = Vector2(basic_attack_range / hit_size.x, 1.0)
	_attack_hitbox.monitoring = true
	for body: Node in _attack_hitbox.get_overlapping_bodies():
		_attack_hit(body)
	if not _attack_hitbox.body_entered.is_connected(_attack_hit):
		_attack_hitbox.body_entered.connect(_attack_hit)
	attack_started.emit()

func _end_basic_attack() -> void:
	if _attack_hitbox != null:
		_attack_hitbox.monitoring = false

func _attack_hit(body: Node) -> void:
	if not body is Mob:
		return
	if _attack_hit_targets.has(body):
		return
	_attack_hit_targets.append(body)
	(body as Mob).take_damage(basic_attack_damage + equipment_power(), self)

static func _state_name(state_value: int) -> StringName:
	match state_value:
		State.RUN:
			return &"run"
		State.JUMP:
			return &"jump"
		State.FALL:
			return &"fall"
	return &"idle"

func _update_timers(delta: float) -> void:
	_coyote = coyote_time if is_on_floor() else maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer = maxf(0.0, _jump_buffer - delta)

func _update_facing() -> void:
	if move_direction == 0.0:
		return
	facing = signi(move_direction)
	if _visual != null:
		_visual.scale.x = float(facing)

func _apply_horizontal(delta: float) -> void:
	var target := move_direction * run_speed
	var rate := ground_deceleration
	if move_direction != 0.0:
		rate = ground_acceleration if is_on_floor() else air_acceleration
	elif is_on_floor():
		rate = ground_deceleration
	else:
		rate = air_deceleration
	velocity.x = move_toward(velocity.x, target, rate * delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		return
	var gravity_scale := 1.0
	if velocity.y < 0.0:
		gravity_scale = rise_gravity_multiplier if Input.is_action_pressed("jump") else jump_cut_multiplier
	elif velocity.y > 0.0:
		gravity_scale = fall_gravity_multiplier
	velocity.y += gravity * gravity_scale * delta

func _apply_jump() -> void:
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0

func _update_state() -> void:
	var new_state: State
	if is_on_floor():
		new_state = State.RUN if absf(velocity.x) > 1.0 else State.IDLE
	elif velocity.y < 0.0:
		new_state = State.JUMP
	else:
		new_state = State.FALL
	state = new_state

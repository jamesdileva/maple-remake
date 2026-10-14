extends RefCounted

const ROSTERS := {
	"four_mages": [&"mage", &"mage", &"mage", &"mage"],
	"four_warriors": [&"warrior", &"warrior", &"warrior", &"warrior"],
	"four_archers": [&"archer", &"archer", &"archer", &"archer"],
	"four_assassins": [&"assassin", &"assassin", &"assassin", &"assassin"],
	"mixed": [&"mage", &"warrior", &"archer", &"assassin"],
}

func get_suite_name() -> String:
	return "party_simulation"

func run(t) -> void:
	var room: PackedScene = load("res://scenes/maps/test_room.tscn")
	var world: Node2D = room.instantiate()
	t.root.add_child(world)
	t.register_world(world)
	SpawnManager.enabled = false
	LootManager.enabled = false
	await t.physics_frame
	await t.physics_frame

	var player: Player = world.get_node("Player")
	t.assert_eq(player.unique_class_count(), 1, "a solo player is one unique class")
	t.assert_almost_eq(player.party_xp_multiplier(), 1.0, 0.0001, "solo play earns no diversity bonus")

	DebugManager.disable_ai = true
	player.set_level(5)

	# the mixed party: the world player leads as the mage
	var mixed_ids: Array = ROSTERS["mixed"]
	var mixed: Array = _build_party(t, world, player, mixed_ids)
	_apply_roster(mixed, mixed_ids)

	for member: Player in mixed:
		t.assert_eq(member.unique_class_count(), 4, "every member sees four unique classes")
		t.assert_almost_eq(member.party_xp_multiplier(), 4.0, 0.0001,
			"every member earns the full diversity bonus")

	# every member banks granted xp exactly once, no duplication
	for member: Player in mixed:
		var before: float = member.xp
		var granted: float = member.grant_xp(10.0)
		t.assert_almost_eq(granted, 40.0, 0.001, "granted xp carries the party multiplier for %s" % String(member.class_definition.id))
		t.assert_almost_eq(member.xp - before, granted, 0.001, "xp banks exactly what was granted")

	# duplicate-only parties earn only the single-class bonus
	for roster_name in ["four_mages", "four_warriors", "four_archers", "four_assassins"]:
		var duplicates: Array = _build_party(t, world, player, ROSTERS[roster_name])
		_apply_roster(duplicates, ROSTERS[roster_name])
		var duplicate_leader: Player = duplicates[0]
		t.assert_eq(duplicate_leader.unique_class_count(), 1, "%s is one unique class" % roster_name)
		t.assert_almost_eq(duplicate_leader.party_xp_multiplier(), 1.0, 0.0001,
			"%s earns no inflated xp" % roster_name)
		for member: Player in duplicates:
			t.assert_eq(member.unique_class_count(), 1, "duplicates do not add diversity")
			var granted_duplicate: float = member.grant_xp(10.0)
			t.assert_almost_eq(granted_duplicate, 10.0, 0.001, "duplicate rosters gain no extra xp")
		await _clear(t, duplicates, true)

	# restore the mixed party after the duplicate runs
	_apply_roster(mixed, mixed_ids)

	# all four presence buffs are live at once in the mixed party
	for member: Player in mixed:
		t.assert_eq(member.effective_party_bonus(), Vector2(40.0, 15.0), "the warrior aura covers the party")
		t.assert_eq(member.effective_tactics_bonus(), Vector2(0.05, 0.15), "the archer aura covers the party")
		t.assert_eq(member.effective_alacrity_bonus(), Vector3(0.15, 0.1, 0.1), "the assassin aura covers the party")

	# the mage lethal aura protects a party member who is not a mage
	var warrior_member: Player = mixed[1]
	t.assert_eq(warrior_member.class_definition.id, &"warrior", "the protected ally is not a mage")
	var lethal_events: Array = []
	warrior_member.lethal_protection_triggered.connect(func(): lethal_events.append(1))
	warrior_member.hp = 10.0
	DebugManager.god_mode = false
	var survived: float = warrior_member.take_damage(999999.0, null)
	t.assert_eq(survived, 0.0, "the lethal hit is absorbed by the mage aura")
	t.assert_eq(warrior_member.hp, 1.0, "the protected ally survives at 1 HP")
	t.assert_eq(lethal_events.size(), 1, "protection fires exactly once")
	t.assert_true(warrior_member.is_lethal_protected(), "the recovery window opens for the ally")
	for _i in range(240):
		await t.physics_frame
	t.assert_false(warrior_member.is_lethal_protected(), "the window expires on its own")

	# when the mage leaves, the party loses lethal protection automatically
	var deaths: Array = []
	EventBus.player_died.connect(func(): deaths.append(1))
	warrior_member.hp = 10.0
	warrior_member.take_damage(999999.0, null)
	t.assert_eq(deaths.size(), 1, "without a mage present the lethal hit lands")

	await _clear(t, mixed, true)
	DebugManager.god_mode = false
	DebugManager.disable_ai = false
	world.queue_free()
	await t.physics_frame
	t.complete_suite(get_suite_name())

func _build_party(t, world: Node2D, leader: Player, class_ids: Array) -> Array:
	var roster: Array = [leader]
	for index in range(1, class_ids.size()):
		var member: Player = load("res://scenes/player/player.tscn").instantiate()
		world.add_child(member)
		member.global_position = Vector2(-100.0 + float(index) * 70.0, -60.0)
		roster.append(member)
	for member: Player in roster:
		member.set_party(roster)
	return roster

func _apply_roster(roster: Array, class_ids: Array) -> void:
	for index in range(class_ids.size()):
		var member: Player = roster[index]
		member.set_level(5)
		member.apply_class(load("res://data/classes/%s.tres" % String(class_ids[index])) as ClassDefinition)
	for member: Player in roster:
		member.set_party(roster)

func _clear(t, roster: Array, keep_leader: bool) -> void:
	for index in range(roster.size()):
		if keep_leader and index == 0:
			continue
		var member: Player = roster[index]
		if not is_instance_valid(member):
			continue
		member.leave_party()
		member.queue_free()
	await t.physics_frame

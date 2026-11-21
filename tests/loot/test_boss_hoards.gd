extends RefCounted

const HOARDS := [
	"res://data/loot/boss_hoard.tres",
	"res://data/loot/boss_hoard_forest.tres",
	"res://data/loot/boss_hoard_forge.tres",
	"res://data/loot/boss_hoard_blight.tres",
]
const TRIALS := 60

func get_suite_name() -> String:
	return "boss_hoards"

func run(t) -> void:
	for path: String in HOARDS:
		var table := load(path) as LootTable
		t.assert_true(table != null, "%s loads" % path.get_file())
		if table == null:
			continue
		var display := path.get_file()
		var has_currency := false
		var gear_entries := 0
		for entry in table.entries:
			if entry.item == null:
				continue
			if entry.item.is_currency():
				has_currency = true
			elif entry.item is EquipmentDefinition and entry.weight > 0.0:
				gear_entries += 1
		t.assert_true(has_currency, "%s pays currency" % display)
		t.assert_true(gear_entries > 0, "%s lists gear" % display)
		var trials_with_gear := 0
		for _i in range(TRIALS):
			var gear_in_trial := false
			for drop in table.roll():
				var item: ItemDefinition = drop.get("item")
				if item is EquipmentDefinition:
					gear_in_trial = true
			if gear_in_trial:
				trials_with_gear += 1
		var share := float(trials_with_gear) / float(TRIALS)
		t.assert_true(share >= 0.65,
			"%s honors the always-gear contract (%d/%d trials, %.0f%%)" % [
				display, trials_with_gear, TRIALS, share * 100.0])
	t.complete_suite(get_suite_name())

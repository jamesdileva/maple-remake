class_name Inventory
extends RefCounted

signal currency_changed(total: int)
signal item_added(item_id: StringName, count: int)

var currency := 0
var items: Dictionary = {}

func add_currency(amount: int) -> int:
	if amount <= 0:
		return 0
	currency += amount
	currency_changed.emit(currency)
	return currency

func add_item(item: ItemDefinition, count: int) -> int:
	if item == null or count <= 0:
		return 0
	var item_id: StringName = item.id
	var current: int = items.get(item_id, 0)
	var room: int = maxi(0, item.max_stack - current)
	var accepted: int = mini(count, room)
	if accepted <= 0:
		return 0
	items[item_id] = current + accepted
	item_added.emit(item_id, accepted)
	return accepted

func item_count(item_id: StringName) -> int:
	return items.get(item_id, 0)

func reset() -> void:
	currency = 0
	items.clear()

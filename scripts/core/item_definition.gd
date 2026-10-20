class_name ItemDefinition
extends Resource

enum Kind { CURRENCY, MATERIAL, EQUIPMENT }

@export var id := &"gold"
@export var display_name := "Gold"
@export var kind: Kind = Kind.CURRENCY
@export var value := 1
@export var max_stack := 99
@export var tint := Color(1.0, 0.85, 0.3, 1.0)

func is_currency() -> bool:
	return kind == Kind.CURRENCY

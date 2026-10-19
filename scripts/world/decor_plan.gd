class_name DecorPlan
extends Resource

@export var id := &""
@export var kit: EnvironmentKit
@export var props := PackedStringArray()
@export var positions := PackedVector2Array()
@export var scales := PackedFloat32Array()
@export var flips := PackedByteArray()
@export var z_index := 0

func count() -> int:
	return min(props.size(), positions.size())

func scale_at(index: int) -> float:
	if index < 0 or index >= scales.size():
		return 1.0
	return scales[index]

func flip_at(index: int) -> bool:
	if index < 0 or index >= flips.size():
		return false
	return flips[index] != 0

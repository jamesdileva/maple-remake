class_name SpriteEffect
extends AnimatedSprite2D

@export var frames: SpriteFrames
@export var autoplay_animation: StringName = &""

func _ready() -> void:
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frames != null:
		sprite_frames = frames
	animation_finished.connect(queue_free)
	if sprite_frames == null:
		return
	var target := autoplay_animation
	var names := sprite_frames.get_animation_names()
	if target == &"" and not names.is_empty():
		target = names[0]
	if sprite_frames.has_animation(target):
		play(target)

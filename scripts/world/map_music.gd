class_name MapMusic
extends AudioStreamPlayer

func _ready() -> void:
	add_to_group("music")
	var wav := stream as AudioStreamWAV
	if wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS and wav.mix_rate > 0:
		var bytes_per_frame := 4 if wav.stereo else 2
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / bytes_per_frame
	play()

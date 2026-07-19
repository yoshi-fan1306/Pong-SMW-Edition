extends AnimatedSprite2D

func _ready() -> void:
	var _background_names = sprite_frames.get_animation_names()
	if _background_names.size() > 0:
		var random_index = randi() % _background_names.size()
		var _chosen_background = _background_names[random_index]
		play(_chosen_background)

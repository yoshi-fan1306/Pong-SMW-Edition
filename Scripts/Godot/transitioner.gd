extends CanvasLayer

@onready var color_rect = $ColorRect

func _ready() -> void:
	color_rect.modulate.a = 0.0
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(_target_scene_path: String) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.visible = true
	var fade_in = create_tween()
	fade_in.tween_property(color_rect, "modulate:a", 1.0, 0.4)
	await fade_in.finished
	get_tree().change_scene_to_file(_target_scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_out = create_tween()
	fade_out.tween_property(color_rect, "modulate:a", 0.0, 0.4)
	await fade_out.finished
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

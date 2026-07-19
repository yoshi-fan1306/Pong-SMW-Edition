extends CanvasLayer
signal sequence_finished

@onready var bg = $Background
@onready var sequence_sprite = $SequenceText
@onready var crt_overlay = $CRTOverlay

func _ready() -> void:
	if crt_overlay:
		crt_overlay.visible = GameManager.tv_effect_enabled
	bg.visible = false
	sequence_sprite.visible = false

func play_start_sequence() -> void:
	if not is_node_ready():
		await ready
	get_tree().paused = true
	sequence_sprite.visible = true
	sequence_sprite.modulate.a = 1.0
	bg.color = Color.BLACK
	bg.modulate.a = 1.0
	bg.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(1.0)
	tween.tween_property(sequence_sprite, "modulate:a", 0.0, 0.0)
	tween.tween_interval(0.5)
	tween.tween_property(bg, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		bg.visible = false
		sequence_sprite.visible = false
		get_tree().paused = false
		sequence_finished.emit()
	)

func play_clear_sequence() -> void:
	if not is_node_ready():
		await ready
	get_tree().paused = true
	bg.color = Color(0, 0, 0, 0.6)
	bg.modulate.a = 0.0
	bg.visible = true
	sequence_sprite.modulate.a = 0.0
	sequence_sprite.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(bg, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(sequence_sprite, "modulate:a", 0.0, 0.0)
	get_tree().paused = false
	Transitioner.change_scene("res://Scenes/main_menu.tscn")

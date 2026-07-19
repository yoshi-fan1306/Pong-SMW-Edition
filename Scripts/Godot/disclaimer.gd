extends Control

@onready var mario = $CanvasLayer/Mario
@onready var block = $CanvasLayer/MessageBlock
@onready var box = $CanvasLayer/MessageBox
@onready var label = $CanvasLayer/MessageBox/Label
@onready var jump_sound = $CanvasLayer/Mario/Jump
@onready var disclaimer_sound = $CanvasLayer/MessageBlock/Disclaimer
@onready var bump_sound = $CanvasLayer/MessageBlock/Bump
@onready var crt_overlay = $CanvasLayer/CRTOverlay

var tv_effect_on: bool = true

func _ready():
	_load_settings()
	if crt_overlay:
		crt_overlay.visible = tv_effect_on
	_load_and_apply_language()
	label.visible = true
	label.modulate.a = 0.0
	box.visible = true 
	await get_tree().process_frame
	box.size.y = label.size.y + 40 
	label.position.y = 20
	box.pivot_offset = box.size / 2.0
	box.scale = Vector2.ZERO
	await get_tree().create_timer(1.0).timeout
	play_sequence()

func _load_and_apply_language():
	var config = ConfigFile.new()
	var lang_idx = 0
	if config.load("user://settings.cfg") == OK:
		lang_idx = config.get_value("Settings", "lang_index", 0)
	var locales = ["en", "es", "pt", "it"]
	TranslationServer.set_locale(locales[clamp(lang_idx, 0, locales.size() - 1)])

func play_sequence():
	var start_y = mario.position.y 
	var tween = create_tween()
	mario.play("jump")
	jump_sound.play()
	tween.tween_property(mario, "position:y", start_y - 250, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(hit_block)
	tween.tween_property(mario, "position:y", start_y + 30, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func hit_block():
	bump_sound.play()
	var block_start_y = block.position.y
	var block_tween = create_tween()
	block_tween.tween_property(block, "position:y", block_start_y - 12, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	block_tween.tween_property(block, "position:y", block_start_y, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	disclaimer_sound.play()
	var box_tween = create_tween()
	box_tween.tween_property(box, "scale", Vector2.ONE, 0.1)
	box_tween.tween_callback(func(): label.modulate.a = 1.0)

func _input(event):
	if event.is_action_pressed("ui_accept") or (event is InputEventScreenTouch and event.pressed):
		if label.modulate.a == 1.0:
			start_exit_sequence()

func start_exit_sequence():
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(box, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(func(): Transitioner.change_scene("res://Scenes/main_menu.tscn"))

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		GameManager.current_lang_index = config.get_value("Settings", "lang_index", 0)
		GameManager.tv_effect_enabled = config.get_value("Settings", "tv_effect", false)
		GameManager.music_volume = config.get_value("Settings", "music_volume", 100)
		GameManager.sound_volume = config.get_value("Settings", "sound_volume", 100)
	tv_effect_on = GameManager.tv_effect_enabled

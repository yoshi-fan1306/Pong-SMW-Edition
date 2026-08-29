extends Area2D

enum Type { MUSHROOM, LIGHTNING, STAR }
var current_type: Type = Type.MUSHROOM

@export var float_speed: float = 120.0
@export var sway_amplitude: float = 40.0
@export var sway_speed: float = 2.5
@export var min_x_spawn: float = 320.0
@export var max_x_spawn: float = 960.0

@export var mushroom_texture: Sprite2D
@export var lightningbolt_texture: AnimatedSprite2D
@export var star_texture: AnimatedSprite2D

@onready var bubble_sprite = $BubbleSprite
@onready var item_sprite = $ItemSprite
@onready var starman_theme = $ItemSprite/Starman

@onready var pop_sound = preload("res://Assets/Audio/SFXs/pop.wav")
@onready var power_up_sound = preload("res://Assets/Audio/SFXs/power-up.wav")
@onready var power_down_sound = preload("res://Assets/Audio/SFXs/power-down.wav")

var time_passed: float = 0.0
var start_x: float = 0.0
var is_popped: bool = false
var p_x: float = 0.0
var p_type: int = -1

func setup(x_pos: float, item_type: int) -> void:
	p_x = x_pos
	global_position.x = p_x
	start_x = global_position.x
	set_type(item_type)

func _ready() -> void:
	randomize()
	body_entered.connect(_on_body_entered)
	if starman_theme:
		starman_theme.stop()
	if p_type == -1:
		p_x = clamp(randf_range(min_x_spawn, max_x_spawn), min_x_spawn + sway_amplitude, max_x_spawn - sway_amplitude)
		global_position.x = p_x
		start_x = global_position.x
		set_type(randi() % 3)
	else:
		set_type(p_type)

func set_type(type_index: int) -> void:
	p_type = type_index
	if mushroom_texture: mushroom_texture.visible = false
	if lightningbolt_texture: lightningbolt_texture.visible = false
	if star_texture: star_texture.visible = false
	match p_type:
		0:
			current_type = Type.MUSHROOM
			if mushroom_texture: mushroom_texture.visible = true
		1:
			current_type = Type.LIGHTNING
			if lightningbolt_texture:
				lightningbolt_texture.visible = true
				lightningbolt_texture.play("default")
		2:
			current_type = Type.STAR
			if star_texture:
				star_texture.visible = true
				star_texture.play("default")

func _physics_process(delta: float) -> void:
	if is_popped: 
		return
	if bubble_sprite: bubble_sprite.play("default")
	time_passed += delta
	position.x = start_x + sin(time_passed * sway_speed) * sway_amplitude
	position.y += float_speed * delta
	if position.y > 800:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if is_popped: 
		return
	if body.is_in_group("ball"):
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
			return
		is_popped = true
		trigger_effect(body.last_hit_by)
		pop_bubble()
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
			WebsocketManager.send_data({"type": "trigger_powerup", "hitter": body.last_hit_by})

func play_sfx(stream_resource: AudioStream) -> void:
	if not stream_resource:
		return
	var asp = AudioStreamPlayer.new()
	asp.stream = stream_resource
	asp.bus = &"SFX"
	get_tree().root.add_child(asp)
	asp.play()
	asp.finished.connect(asp.queue_free)

func trigger_effect(hitter_id: int) -> void:
	match current_type:
		Type.MUSHROOM, Type.STAR:
			play_sfx(power_up_sound)
		Type.LIGHTNING:
			play_sfx(power_down_sound)
	if hitter_id == 0:
		return
	var player_paddle = get_parent().get_node_or_null("Player")
	var opponent_paddle = get_parent().get_node_or_null("Opponent")
	if not player_paddle or not opponent_paddle:
		return
	match current_type:
		Type.MUSHROOM:
			var ball = get_parent().get_node_or_null("Ball")
			if ball and ball.has_method("apply_mushroom_grow"):
				ball.apply_mushroom_grow(7.0)
		Type.LIGHTNING:
			var target = opponent_paddle if hitter_id == 1 else player_paddle
			if target and target.has_method("apply_poison_shrink"):
				target.apply_poison_shrink(7.0)
		Type.STAR:
			var target = player_paddle if hitter_id == 1 else opponent_paddle
			if target and target.has_method("apply_star_effect"):
				target.apply_star_effect(7.0)
			var music_node = get_tree().root.find_child("GameMusic", true, false)
			if not music_node:
				music_node = get_tree().root.find_child("game_music", true, false)
			if music_node:
				music_node.volume_db = -80.0
			if starman_theme:
				starman_theme.play()
			await get_tree().create_timer(7.0).timeout
			if music_node:
				var normal_vol = GameManager.music_volume / 100.0
				music_node.volume_db = linear_to_db(normal_vol) if normal_vol > 0 else -80.0

func pop_bubble() -> void:
	set_physics_process(false)
	play_sfx(pop_sound)
	if mushroom_texture: mushroom_texture.visible = false
	if lightningbolt_texture: lightningbolt_texture.visible = false
	if star_texture: star_texture.visible = false
	if bubble_sprite and bubble_sprite.sprite_frames.has_animation("pop"):
		bubble_sprite.play("pop")
		await bubble_sprite.animation_finished
		bubble_sprite.visible = false
	if current_type == Type.STAR:
		await get_tree().create_timer(7.0).timeout 
	queue_free()

extends Area2D

enum Type { MUSHROOM, LIGHTNING }
var current_type: Type = Type.MUSHROOM

@export var float_speed: float = 120.0
@export var sway_amplitude: float = 40.0
@export var sway_speed: float = 2.5
@export var min_x_spawn: float = 320.0
@export var max_x_spawn: float = 960.0

@export var mushroom_texture: Sprite2D
@export var lightningbolt_texture: AnimatedSprite2D

@onready var bubble_sprite = $BubbleSprite
@onready var item_sprite = $ItemSprite
@onready var pop_sound = $ItemSprite/PopSound
@onready var power_up_sound = preload("res://Assets/Audio/SFXs/power-up.wav")
@onready var power_down_sound = preload("res://Assets/Audio/SFXs/power-down.wav")

var time_passed: float = 0.0
var start_x: float = 0.0
var is_popped: bool = false
var p_x: float = 0.0
var p_type: int = -1
func setup(x_pos: float, item_type: int):
	p_x = x_pos
	p_type = item_type

func _ready():
	body_entered.connect(_on_body_entered)
	if p_type == -1:
		p_x = clamp(randf_range(min_x_spawn, max_x_spawn), min_x_spawn + sway_amplitude, max_x_spawn - sway_amplitude)
		p_type = 0 if randf() > 0.5 else 1
	global_position.x = p_x
	start_x = global_position.x
	if p_type == 0:
		current_type = Type.MUSHROOM
		if item_sprite and mushroom_texture:
			mushroom_texture.visible = true
			lightningbolt_texture.visible = false
			item_sprite.texture = mushroom_texture
	else:
		current_type = Type.LIGHTNING
		if item_sprite and lightningbolt_texture:
			mushroom_texture.visible = false
			lightningbolt_texture.visible = true
			lightningbolt_texture.play("default")
			item_sprite.texture = lightningbolt_texture

func _physics_process(delta: float) -> void:
	if is_popped: 
		return
	bubble_sprite.play("default")
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

func trigger_effect(hitter_id: int) -> void:
	if hitter_id == 0:
		return
	var player_paddle = get_parent().get_node_or_null("Player")
	var opponent_paddle = get_parent().get_node_or_null("Opponent")
	if not player_paddle or not opponent_paddle:
		return
	if current_type == Type.MUSHROOM:
		var ball = get_parent().get_node_or_null("Ball")
		if ball and ball.has_method("apply_mushroom_grow"):
			ball.apply_mushroom_grow(7.0)
		pop_sound.stream = power_up_sound
		pop_sound.play()
	elif current_type == Type.LIGHTNING:
		var target = opponent_paddle if hitter_id == 1 else player_paddle
		if target.has_method("apply_poison_shrink"):
			target.apply_poison_shrink(7.0)
			pop_sound.stream = power_down_sound
			pop_sound.play()

func pop_bubble() -> void:
	set_physics_process(false)
	if item_sprite:
		item_sprite.visible = false
	if bubble_sprite and bubble_sprite.sprite_frames.has_animation("pop"):
		bubble_sprite.play("pop")
		await bubble_sprite.animation_finished
		bubble_sprite.visible = false
	if pop_sound.playing:
		await pop_sound.finished
	queue_free()

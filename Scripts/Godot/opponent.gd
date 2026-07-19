extends CharacterBody2D

var touch_target_y: float = -1.0
var start_x: float = 0.0
var is_shrunk: bool = false
var original_collision_height: float = 0.0

@export var speed: float = 600.0
@export var normal_texture: Texture2D
@export var small_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var power_up_sound = preload("res://Assets/Audio/SFXs/power-up.wav")

func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 1.0
	start_x = global_position.x
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		if WebsocketManager.is_host:
			if not WebsocketManager.peer_p2_pos.is_connected(_sync_y_pos):
				WebsocketManager.peer_p2_pos.connect(_sync_y_pos)
	if collision_shape and collision_shape.shape:
		collision_shape.shape = collision_shape.shape.duplicate()
		if collision_shape.shape is RectangleShape2D:
			original_collision_height = collision_shape.shape.size.y

func _sync_y_pos(y: float) -> void:
	global_position.y = y

func apply_poison_shrink(duration: float) -> void:
	if is_shrunk: 
		return
	is_shrunk = true
	if small_texture and sprite: sprite.texture = small_texture
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size.y = original_collision_height * 0.5
	await get_tree().create_timer(duration).timeout
	if normal_texture and sprite: sprite.texture = normal_texture
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size.y = original_collision_height
	is_shrunk = false
	var sfx = AudioStreamPlayer.new()
	sfx.stream = power_up_sound
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func get_bounce_direction(ball_pos: Vector2) -> Vector2:
	var current_height = original_collision_height
	if collision_shape and collision_shape.shape is RectangleShape2D:
		current_height = collision_shape.shape.size.y
	var relative_y = ball_pos.y - global_position.y
	var normalized_y = clamp(relative_y / (current_height / 2.0), -1.0, 1.0)
	var bounce_angle = normalized_y * (PI / 3.0) 
	return Vector2(-cos(bounce_angle), sin(bounce_angle)).normalized()

func _input(event: InputEvent) -> void:
	if GameManager.current_mode == GameManager.Mode.NPC: 
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.position.x > get_viewport_rect().size.x / 2:
			touch_target_y = event.position.y
			if event is InputEventScreenTouch and not event.pressed: touch_target_y = -1.0

func _physics_process(delta: float) -> void:
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		velocity.y = _get_input_direction() * speed
		move_and_collide(velocity * delta)
		global_position.y = clamp(global_position.y, 82.0, 566.0)
		WebsocketManager.send_data({"type": "p2", "y": global_position.y})
	elif GameManager.current_mode == GameManager.Mode.MULTIPLAYER and WebsocketManager.is_host:
		global_position.y = clamp(global_position.y, 82.0, 566.0)
	elif GameManager.current_mode == GameManager.Mode.NPC:
		_handle_npc_ai()
		move_and_collide(velocity * delta)
		global_position.y = clamp(global_position.y, 82.0, 566.0)
	else:
		velocity.y = _get_input_direction() * speed
		move_and_collide(velocity * delta)
		global_position.y = clamp(global_position.y, 82.0, 566.0)
	global_position.x = start_x

func _get_input_direction() -> float:
	var dir = Input.get_axis("p2_up", "p2_down")
	if dir == 0 and touch_target_y != -1.0:
		var d = touch_target_y - global_position.y
		dir = sign(d) if abs(d) > 10 else 0.0
	return dir

func _handle_npc_ai() -> void:
	var ball = get_tree().get_first_node_in_group("ball")
	if not ball: 
		return
	var speed_multiplier = 0.75
	var deadzone = 20.0
	var difficulty = ""
	if "npc_difficulty" in GameManager:
		difficulty = str(GameManager.npc_difficulty).to_lower()
	if "easy" in difficulty or "fácil" in difficulty or "facile" in difficulty:
		speed_multiplier = 0.5
		deadzone = 45.0
	elif "hard" in difficulty or "difícil" in difficulty or "difficile" in difficulty:
		speed_multiplier = 1.0
		deadzone = 5.0
	var distance = ball.global_position.y - global_position.y
	if abs(distance) > deadzone:
		velocity.y = sign(distance) * (speed * speed_multiplier)
	else:
		velocity.y = 0.0

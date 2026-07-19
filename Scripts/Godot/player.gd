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
		if not WebsocketManager.peer_p1_visual.is_connected(_sync_y_pos):
			WebsocketManager.peer_p1_visual.connect(_sync_y_pos)
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
	return Vector2(cos(bounce_angle), sin(bounce_angle)).normalized()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.position.x < get_viewport_rect().size.x / 2:
			touch_target_y = event.position.y
			if event is InputEventScreenTouch and not event.pressed: touch_target_y = -1.0

func _physics_process(_delta: float) -> void:
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and WebsocketManager.is_host:
		velocity.y = _get_input_direction() * speed
		move_and_collide(velocity * _delta)
		global_position.y = clamp(global_position.y, 82.0, 566.0)
		WebsocketManager.send_data({"type": "p1_visual", "y": global_position.y})
	elif GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		pass
	elif GameManager.current_mode != GameManager.Mode.MULTIPLAYER:
		velocity.y = _get_input_direction() * speed
		move_and_collide(velocity * _delta)
		global_position.y = clamp(global_position.y, 82.0, 566.0)
	global_position.x = start_x

func _get_input_direction() -> float:
	var dir = Input.get_axis("ui_up", "ui_down")
	if dir == 0 and touch_target_y != -1.0:
		var d = touch_target_y - global_position.y
		dir = sign(d) if abs(d) > 10 else 0.0
	return dir

extends CharacterBody2D

var touch_target_y: float = -1.0
var start_x: float = 0.0
var is_shrunk: bool = false
var original_collision_height: float = 0.0
var is_starred: bool = false
var original_speed: float = 0.0 

@export var speed: float = 600.0
@export var normal_texture: Texture2D
@export var small_texture: Texture2D

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D
@onready var power_up_sound = preload("res://Assets/Audio/SFXs/power-up.wav")
@onready var star_sparkle = $Sparkle 

func _ready():
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 1.0
	start_x = global_position.x
	original_speed = speed 
	if star_sparkle:
		star_sparkle.visible = false
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

func apply_star_effect(duration: float) -> void:
	if is_starred:
		return
	is_starred = true
	speed = original_speed * 1.75
	if sprite and not sprite.material is ShaderMaterial:
		var shader = Shader.new()
		shader.code = """
		shader_type canvas_item;
		uniform vec4 flash_color : source_color = vec4(1.0);
		uniform float active : hint_range(0.0, 1.0) = 0.0;
		uniform float white_overlay : hint_range(0.0, 1.0) = 0.0; 
		
		void fragment() {
			vec4 tex = texture(TEXTURE, UV);
			float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
			vec3 light_tint = flash_color.rgb;
			vec3 dark_tint = flash_color.rgb * 0.3; 
			vec3 inverted_palette = mix(light_tint, dark_tint, luma);
			vec3 final_effect = mix(inverted_palette, vec3(1.0), white_overlay);
			COLOR = vec4(mix(tex.rgb, final_effect, active), tex.a);
		}
		"""
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("flash_color", Color("9beac0"))
		mat.set_shader_parameter("active", 0.0)
		mat.set_shader_parameter("white_overlay", 0.0)
		sprite.material = mat
	var rainbow_tween = create_tween().set_loops()
	var flash_time = 0.1
	if sprite and sprite.material:
		var smw_states = [
			{"color": Color("9bffc0ff"), "active": 1.0, "white": 0.0},
			{"color": Color("ffffff"), "active": 0.25, "white": 1.0},
			{"color": Color("ffff8bff"), "active": 1.0, "white": 0.0},
			{"color": Color("ffffff"), "active": 0.25, "white": 1.0},
			{"color": Color("ffaca2ff"), "active": 1.0, "white": 0.0},
			{"color": Color("ffffff"), "active": 0.4, "white": 1.0}
		]
		for state in smw_states:
			rainbow_tween.tween_property(sprite.material, "shader_parameter/flash_color", state["color"], flash_time)
			rainbow_tween.parallel().tween_property(sprite.material, "shader_parameter/active", state["active"], flash_time)
			rainbow_tween.parallel().tween_property(sprite.material, "shader_parameter/white_overlay", state["white"], flash_time)
	if star_sparkle:
		spawn_sparkle()
	await get_tree().create_timer(duration).timeout
	if rainbow_tween and rainbow_tween.is_valid():
		rainbow_tween.kill()
	if is_instance_valid(sprite) and sprite.material:
		sprite.material.set_shader_parameter("active", 0.0)
		sprite.material.set_shader_parameter("white_overlay", 0.0)
	speed = original_speed
	is_starred = false
	for sparkle in get_tree().get_nodes_in_group("star_sparkles"):
		if is_instance_valid(sparkle):
			sparkle.queue_free()

func spawn_sparkle() -> void:
	if not is_starred or not star_sparkle:
		return
	var new_sparkle = star_sparkle.duplicate()
	add_child(new_sparkle)
	new_sparkle.visible = true
	new_sparkle.add_to_group("star_sparkles")
	new_sparkle.scale = Vector2(2.5, 2.5)
	var half_height = original_collision_height / 2.0
	if half_height == 0: 
		half_height = 50.0 
	var rand_x = randf_range(25.0, 55.0)
	if randf() > 0.5: 
		rand_x *= -1.0
	var rand_y = randf_range(-half_height - 15.0, half_height + 15.0)
	new_sparkle.position = Vector2(rand_x, rand_y)
	new_sparkle.frame_changed.connect(_on_sparkle_frame_changed.bind(new_sparkle))
	new_sparkle.animation_finished.connect(new_sparkle.queue_free)
	new_sparkle.animation_looped.connect(new_sparkle.queue_free)
	new_sparkle.play()

func _on_sparkle_frame_changed(sparkle_node: AnimatedSprite2D) -> void:
	if not is_instance_valid(sparkle_node): 
		return
	if sparkle_node.frame == 2 and is_starred:
		if sparkle_node.frame_changed.is_connected(_on_sparkle_frame_changed):
			sparkle_node.frame_changed.disconnect(_on_sparkle_frame_changed.bind(sparkle_node))
		spawn_sparkle()

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

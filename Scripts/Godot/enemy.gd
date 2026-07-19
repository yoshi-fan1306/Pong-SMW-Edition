extends Area2D

@onready var sprite = $AnimatedSprite2D
@onready var kick_sound = $KickSound
@onready var hitbox = $CollisionShape2D

var speed: float = 120.0
var direction: int = 1

var e_type: String = ""
var e_is_top: int = -1
var e_dir: int = 0

var is_dead: bool = false
var velocity_y: float = 0.0
var custom_gravity: float = 1800.0 
var death_horizontal_speed: float = 0.0
var rotation_speed: float = 0.0

func setup(type_str: String, top: bool, dir_int: int):
	e_type = type_str
	e_is_top = 1 if top else 0
	e_dir = dir_int

func _ready() -> void:
	if e_is_top == -1: 
		var enemy_types = ["galoomba", "koopa", "buzzy_beetle"]
		e_type = enemy_types[randi() % enemy_types.size()]
		e_is_top = 1 if (randi() % 2 == 0) else 0
		e_dir = 1 if randi() % 2 == 0 else -1
	var is_top = (e_is_top == 1)
	direction = e_dir
	sprite.play(e_type)
	if e_type == "koopa":
		sprite.position.y = 16
	else:
		var y_offset = 0 if is_top else 32
		sprite.position.y = y_offset
	position.y = 24.0 if is_top else 592.5
	sprite.flip_v = is_top 
	position.x = -100.0 if direction == 1 else 1200.0
	sprite.flip_h = (direction == 1)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if is_dead:
		velocity_y += custom_gravity * delta
		position.y += velocity_y * delta
		position.x += death_horizontal_speed * delta
		sprite.rotation += rotation_speed * delta
		if position.y > 1000 or position.y < -200:
			queue_free()
	else:
		position.x += speed * direction * delta
		if position.x < -100 or position.x > 1250:
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball") and not is_dead:
		if e_type == "koopa":
			sprite.play("koopa_hit")
		if e_type == "buzzy_beetle":
			sprite.play("buzzy_hit")
		if e_type == "galoomba":
			sprite.stop()
		is_dead = true
		hitbox.set_deferred("disabled", true)
		if kick_sound: 
			kick_sound.play()
		var bump_dir = 1.0
		if body.velocity.x < 0:
			bump_dir = -1.0
		death_horizontal_speed = 125.0 * bump_dir
		var is_top = (e_is_top == 1)
		if is_top:
			velocity_y = 150.0  
			custom_gravity = 1800.0 
		else:
			velocity_y = -450.0 
			custom_gravity = 1800.0 
		rotation_speed = 15.0 * bump_dir

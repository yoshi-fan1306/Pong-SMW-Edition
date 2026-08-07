extends CharacterBody2D

@export var speed: float = 350.0
@export var can_move: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var bump_sound: AudioStreamPlayer = $Bump
@onready var big_bump_sound: AudioStreamPlayer = $BigBump
@onready var score_sound: AudioStreamPlayer = $Score
@onready var music_player: AudioStreamPlayer = $GameMusic

@onready var music_intro = preload("res://Assets/Audio/Music/game_music_i.ogg")
@onready var music_loop = preload("res://Assets/Audio/Music/game_music.ogg")
@onready var power_down_sound = preload("res://Assets/Audio/SFXs/power-down.wav")

var is_first_start: bool = true
var can_play_bump: bool = true
var is_waiting: bool = false
var last_hit_by: int = 0

func _ready() -> void:
	add_to_group("ball")
	if animated_sprite: animated_sprite.play("Spin")
	if music_player:
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		music_player.stream = music_intro
		music_player.play()
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		if not WebsocketManager.peer_ball_pos.is_connected(sync_ball_pos):
			WebsocketManager.peer_ball_pos.connect(sync_ball_pos)
		if not WebsocketManager.peer_sound.is_connected(play_sound_networked):
			WebsocketManager.peer_sound.connect(play_sound_networked)
		if not WebsocketManager.peer_ball_visibility.is_connected(sync_visibility):
			WebsocketManager.peer_ball_visibility.connect(sync_visibility)

func _on_music_finished() -> void:
	if music_player.stream == music_intro:
		music_player.stream = music_loop
	music_player.play()

func reset_ball() -> void:
	scale = Vector2.ONE
	if has_meta("powerup_tween"):
		var existing_tween = get_meta("powerup_tween", null)
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		return
	if is_waiting: 
		return
	var game_scene = get_tree().current_scene
	if game_scene.has_node("HBoxContainer/WinLose1"):
		var w1 = game_scene.get_node("HBoxContainer/WinLose1")
		var w2 = game_scene.get_node("HBoxContainer/WinLose2")
		if w1.visible or w2.visible:
			visible = false
			can_move = false
			return
	is_waiting = true
	can_move = false
	velocity = Vector2.ZERO
	var center_x = get_viewport_rect().size.x / 2.0
	var center_y = get_viewport_rect().size.y / 2.0
	var player_paddle = get_node_or_null("../Player")
	var opponent_paddle = get_node_or_null("../Opponent")
	if player_paddle and opponent_paddle and player_paddle.global_position.x > 0 and opponent_paddle.global_position.x > 0:
		center_x = (player_paddle.global_position.x + opponent_paddle.global_position.x) / 2.0
	global_position = Vector2(center_x, center_y)
	if is_first_start:
		is_first_start = false
		visible = true
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
			WebsocketManager.send_data({"type": "ball_vis", "v": true})
		await get_tree().create_timer(3.0).timeout
	else:
		visible = false
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
			WebsocketManager.send_data({"type": "ball_vis", "v": false})
		await get_tree().create_timer(1.0).timeout
	is_waiting = false
	last_hit_by = 0
	_launch_ball()

func apply_mushroom_grow(duration: float) -> void:
	if has_meta("powerup_tween"):
		var existing_tween = get_meta("powerup_tween", null)
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	var tween = create_tween()
	set_meta("powerup_tween", tween)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.0)
	tween.tween_interval(duration)
	tween.tween_callback(func():
		scale = Vector2.ONE
		var sfx = AudioStreamPlayer.new()
		sfx.stream = power_down_sound
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)
	)

func _launch_ball() -> void:
	var game_scene = get_tree().current_scene
	if game_scene.has_node("HBoxContainer/WinLose1"):
		if game_scene.get_node("HBoxContainer/WinLose1").visible:
			return
	visible = true
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "ball_vis", "v": true})
	velocity = Vector2(1 if randf() > 0.5 else -1, randf_range(0.3, 0.8)).normalized() * speed
	can_move = true

func _physics_process(delta: float) -> void:
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		return
	if can_move:
		_process_ball_physics(delta)
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
			WebsocketManager.send_data({"type": "ball", "x": global_position.x, "y": global_position.y})

func _process_ball_physics(_delta: float) -> void:
	var step_velocity = (velocity * _delta) / 3.0
	for i in range(4):
		var collision = move_and_collide(step_velocity)
		if collision:
			var collider = collision.get_collider()
			var normal = collision.get_normal()
			global_position += normal * 4.0
			if collider and ("Player" in collider.name or "Opponent" in collider.name):
				if "Player" in collider.name:
					last_hit_by = 1
				elif "Opponent" in collider.name:
					last_hit_by = 2
				if collider.has_method("get_bounce_direction"):
					var target_speed = velocity.length() + 20.0
					var bounce_dir = collider.get_bounce_direction(global_position)
					if "Player" in collider.name:
						bounce_dir.x = abs(bounce_dir.x)
					elif "Opponent" in collider.name:
						bounce_dir.x = -abs(bounce_dir.x)
					velocity = bounce_dir.normalized() * min(target_speed, 1200.0)
				else:
					velocity = velocity.bounce(normal)
					velocity = velocity.normalized() * min(velocity.length() + 20.0, 1200.0)
				if can_play_bump:
					var sound_to_play = "bump_sound"
					if scale.x > 1.0:
						sound_to_play = "big_bump_sound"
					if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
						WebsocketManager.send_data({"type": "sound", "name": sound_to_play})
					if sound_to_play == "big_bump_sound" and big_bump_sound:
						big_bump_sound.play()
					elif bump_sound: 
						bump_sound.play()
					can_play_bump = false
					get_tree().create_timer(0.1).timeout.connect(func(): can_play_bump = true)
				if scale.x > 1.0: 
					shake_screen(5.0, 0.3)
				break
			else:
				velocity = velocity.bounce(normal)
				break
	if global_position.y <= 0 or global_position.y >= 642:
		velocity.y = -velocity.y
	if global_position.x < 0.0: score_point(1)
	elif global_position.x > 1152.0: score_point(2)

func score_point(_player_num: int) -> void:
	if not can_move: 
		return
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		return
	can_move = false
	velocity = Vector2.ZERO
	if score_sound: score_sound.play()
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "sound", "name": "score_sound"})
	var game_manager = get_parent()
	if game_manager and game_manager.has_method("player_scored"):
		game_manager.player_scored(_player_num)
	reset_ball()

func sync_visibility(new_visibility: bool) -> void: visible = new_visibility
func sync_ball_pos(pos: Vector2) -> void: global_position = pos

func play_sound_networked(sound_name: String) -> void:
	if sound_name == "bump_sound" and bump_sound: 
		bump_sound.play()
	elif sound_name == "big_bump_sound" and big_bump_sound:
		big_bump_sound.play()
		shake_screen(5.0, 0.3)
	elif sound_name == "score_sound" and score_sound: 
		score_sound.play()

func shake_screen(intensity: float, duration: float) -> void:
	var camera = get_viewport().get_camera_2d()
	var background = get_node_or_null("../AnimatedSprite2D")
	if not camera:
		return
	if background and not background.has_meta("base_pos"):
		background.set_meta("base_pos", background.position)
	var bg_base_pos = background.get_meta("base_pos") if background else Vector2.ZERO
	if has_meta("shake_tween"):
		var existing_tween = get_meta("shake_tween", null)
		if existing_tween and existing_tween.is_valid():
			existing_tween.kill()
	var tween = create_tween()
	set_meta("shake_tween", tween)
	var snap_sequence = [1.0, -1.0, 0.75, -0.75, 0.5, -0.5, 0.25, -0.25, 0.0]
	var time_per_snap = duration / float(snap_sequence.size())
	for multiplier in snap_sequence:
		var cam_offset = Vector2(0, intensity * multiplier)
		tween.tween_property(camera, "offset", cam_offset, 0.0)
		if background:
			var bg_offset = Vector2(0, intensity * multiplier * 3.0)
			tween.parallel().tween_property(background, "position", bg_base_pos + bg_offset, 0.0)
		tween.tween_interval(time_per_snap)

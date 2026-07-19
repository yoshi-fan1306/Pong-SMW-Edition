extends Node2D

@onready var score_label = $HBoxContainer/ScoreSystem
@onready var match_music = $Ball/GameMusic
@onready var victory_music = $HBoxContainer/ScoreSystem/MusicPlayer
@onready var win_lose_1 = $HBoxContainer/WinLose1
@onready var win_lose_2 = $HBoxContainer/WinLose2
@onready var crt_overlay = $CRTOverlay
@onready var sequence_ui = $SequenceUI

var player1_score: int = 0
var player2_score: int = 0
var match_started = false
var powerup_scene = preload("res://Scenes/power_up_bubble.tscn")
var enemy_scene = preload("res://Scenes/enemy.tscn")
var powerup_timer: Timer

func _ready():
	if crt_overlay:
		crt_overlay.visible = GameManager.tv_effect_enabled
	sequence_ui.play_start_sequence()
	await sequence_ui.sequence_finished
	start_game_logic()

func start_game_logic():
	var global_music = get_tree().root.get_node_or_null("MusicPlayer")
	if global_music: global_music.stop()
	win_lose_1.visible = false
	win_lose_2.visible = false
	update_score_display()
	if not $EnemySpawner/Timer.timeout.is_connected(_on_timer_timeout):
		$EnemySpawner/Timer.timeout.connect(_on_timer_timeout)
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		if not WebsocketManager.peer_score.is_connected(sync_score_ui):
			WebsocketManager.peer_score.connect(sync_score_ui)
		if not WebsocketManager.peer_game_over.is_connected(trigger_game_over):
			WebsocketManager.peer_game_over.connect(trigger_game_over)
		if not WebsocketManager.peer_ball_visibility.is_connected(_on_ball_visibility_received):
			WebsocketManager.peer_ball_visibility.connect(_on_ball_visibility_received)
		if not WebsocketManager.peer_spawn_powerup.is_connected(_on_network_spawn_powerup):
			WebsocketManager.peer_spawn_powerup.connect(_on_network_spawn_powerup)
		if not WebsocketManager.peer_spawn_enemy.is_connected(_on_network_spawn_enemy):
			WebsocketManager.peer_spawn_enemy.connect(_on_network_spawn_enemy)
		if not WebsocketManager.peer_trigger_powerup.is_connected(_on_network_trigger_powerup):
			WebsocketManager.peer_trigger_powerup.connect(_on_network_trigger_powerup)
		if not WebsocketManager.peer_loaded.is_connected(_on_peer_ready):
			WebsocketManager.peer_loaded.connect(_on_peer_ready)
		$EnemySpawner/Timer.stop()
		$Ball.set_physics_process(false)
		$Ball.visible = false
		WebsocketManager.send_data({"type": "player_loaded"})
		if WebsocketManager.peer_is_in_game:
			_on_peer_ready()
	else:
		_on_peer_ready()

func _on_peer_ready():
	if match_started:
		return
	match_started = true
	var global_music = get_tree().root.get_node_or_null("MusicPlayer")
	if global_music:
		global_music.play()
	$Ball.visible = true
	$Ball.set_physics_process(true)
	if GameManager.current_mode != GameManager.Mode.MULTIPLAYER or WebsocketManager.is_host:
		$Ball.reset_ball()
		powerup_timer = Timer.new()
		powerup_timer.wait_time = 15.0
		powerup_timer.autostart = true
		powerup_timer.timeout.connect(spawn_powerup)
		add_child(powerup_timer)
		if GameManager.current_mode != GameManager.Mode.MULTIPLAYER:
			$EnemySpawner/Timer.start()
		elif WebsocketManager.is_host:
			$EnemySpawner/Timer.start()
			WebsocketManager.send_data({"type": "ball_vis", "v": true})

func player_scored(player_num: int) -> void:
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER and not WebsocketManager.is_host:
		return
	$Ball.visible = false
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "ball_vis", "v": false})
	if player_num == 2: player1_score += 1
	elif player_num == 1: player2_score += 1
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "score", "p1": player1_score, "p2": player2_score})
	sync_score_ui(player1_score, player2_score)
	if player1_score >= GameManager.max_score or player2_score >= GameManager.max_score:
		var winner = 1 if player1_score >= GameManager.max_score else 2
		if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
			WebsocketManager.send_data({"type": "game_over", "winner": winner})
		trigger_game_over(winner)
	else:
		await get_tree().create_timer(1.0).timeout
		if player1_score < GameManager.max_score and player2_score < GameManager.max_score:
			$Ball.visible = true
			if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
				WebsocketManager.send_data({"type": "ball_vis", "v": true})
			$Ball.reset_ball()

func _on_timer_timeout():
	var enemy_types = ["galoomba", "koopa", "buzzy_beetle"]
	var e_type = enemy_types[randi() % enemy_types.size()]
	var is_top = randi() % 2 == 0
	var dir = 1 if randi() % 2 == 0 else -1
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "spawn_enemy", "e_type": e_type, "is_top": is_top, "dir": dir})
	_create_enemy(e_type, is_top, dir)

func _on_network_spawn_enemy(e_type, is_top, dir):
	if not WebsocketManager.is_host:
		_create_enemy(e_type, is_top, dir)

func _create_enemy(e_type, is_top, dir):
	var enemy = enemy_scene.instantiate()
	enemy.setup(e_type, is_top, dir)
	enemy.add_to_group("enemies")
	add_child(enemy)

func spawn_powerup():
	if not has_node("Ball") or $Ball.is_waiting or has_node("PowerUpBubble"):
		return
	var x_pos = clamp(randf_range(320.0, 960.0), 360.0, 920.0)
	var item_type = 0 if randf() > 0.5 else 1
	if GameManager.current_mode == GameManager.Mode.MULTIPLAYER:
		WebsocketManager.send_data({"type": "spawn_powerup", "x": x_pos, "item_type": item_type})
	_create_powerup(x_pos, item_type)

func _on_network_spawn_powerup(x_pos, item_type):
	if not WebsocketManager.is_host:
		_create_powerup(x_pos, item_type)

func _create_powerup(x_pos, item_type):
	var bubble = powerup_scene.instantiate()
	bubble.name = "PowerUpBubble"
	bubble.z_index = 5
	bubble.setup(x_pos, item_type)
	bubble.add_to_group("powerups")
	add_child(bubble)

func _on_network_trigger_powerup(hitter_int):
	if not WebsocketManager.is_host and has_node("PowerUpBubble"):
		var bubble = $PowerUpBubble
		bubble.is_popped = true
		bubble.trigger_effect(hitter_int)
		bubble.pop_bubble()

func _on_ball_visibility_received(visible_status):
	$Ball.visible = visible_status

func sync_score_ui(p1: int, p2: int) -> void:
	player1_score = p1
	player2_score = p2
	update_score_display()

func update_score_display() -> void:
	score_label.text = str(player1_score) + " - " + str(player2_score)

func trigger_game_over(winner_num: int) -> void:
	if has_node("Ball"):
		$Ball.visible = false
		$Ball.set_physics_process(false)
	if has_node("EnemySpawner/Timer"):
		$EnemySpawner/Timer.stop()
	if is_instance_valid(powerup_timer):
		powerup_timer.stop()
	if match_music: match_music.stop()
	await get_tree().create_timer(1.0).timeout
	if victory_music: victory_music.play()
	if winner_num == 1:
		win_lose_1.text = "WINNER"
	else:
		win_lose_2.text = "WINNER"
	win_lose_1.visible = true
	win_lose_2.visible = true
	await get_tree().create_timer(5.0).timeout
	call_deferred("_transition_to_menu")

func _transition_to_menu() -> void:
	WebsocketManager.cleanup()
	Transitioner.change_scene("res://Scenes/main_menu.tscn")

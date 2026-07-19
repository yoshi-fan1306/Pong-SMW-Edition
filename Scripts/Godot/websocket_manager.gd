extends Node

signal match_ready
signal peer_p1_pos(y)
signal peer_p2_pos(y)

signal peer_p1_input(direction)
signal peer_p2_input(direction)

signal peer_ball_pos(pos)
signal peer_score(p1, p2)
signal peer_p1_visual(y)
signal peer_sound(sound_name)
signal peer_game_over(winner)
signal peer_ball_visibility(is_visible)
signal peer_loaded

var socket = null
var is_connected_to_server = false
var game_started = false
var is_host = false 
var current_lobby_id = ""
var peer_is_in_game = false

var last_state = -1
var ping_timer = 0.0
const PING_INTERVAL = 3.0

signal peer_spawn_powerup(x, item_type)
signal peer_spawn_enemy(e_type, is_top, dir)
signal peer_trigger_powerup(hitter_int)

func cleanup():
	if socket:
		socket.close()
	socket = null
	is_connected_to_server = false
	game_started = false
	peer_is_in_game = false

func start_host(lobby_id):
	cleanup()
	socket = WebSocketPeer.new()
	is_host = true
	current_lobby_id = str(lobby_id)
	_connect_to_server()

func start_join(lobby_id):
	cleanup()
	socket = WebSocketPeer.new()
	is_host = false
	current_lobby_id = str(lobby_id)
	_connect_to_server()

func _connect_to_server():
	var url = "wss://psmwe-multiplayer-servers.onrender.com"
	socket.connect_to_url(url)

func _process(delta):
	if not socket: 
		return
	socket.poll()
	var state = socket.get_ready_state()
	if state != last_state:
		last_state = state
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected_to_server:
			is_connected_to_server = true
			send_data({"type": "join_lobby", "lobby": current_lobby_id})
		ping_timer += delta
		if ping_timer >= PING_INTERVAL:
			ping_timer = 0.0
			send_data({"type": "ping"})
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			_on_data_received(packet)

func _on_data_received(packet: String):
	var json = JSON.new()
	if json.parse(packet) == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_DICTIONARY and data.has("type"):
			match data["type"]:
				"player_loaded":
					if not peer_is_in_game:
						peer_is_in_game = true
						peer_loaded.emit()
					send_data({"type": "player_loaded_ack"})
				"player_loaded_ack":
					if not peer_is_in_game:
						peer_is_in_game = true
						peer_loaded.emit()
				"lobby_joined":
					send_data({"type": "ready"})
				"ready":
					if not game_started:
						game_started = true
						send_data({"type": "ready"})
						match_ready.emit()
				"input":
					if is_host:
						peer_p2_input.emit(data["direction"])
					else:
						peer_p1_input.emit(data["direction"])
				"p1": peer_p1_pos.emit(data["y"])
				"p1_visual": peer_p1_visual.emit(data["y"])
				"p2": peer_p2_pos.emit(data["y"])
				"ball": peer_ball_pos.emit(Vector2(data["x"], data["y"]))
				"ball_vis": peer_ball_visibility.emit(data["v"])
				"score": peer_score.emit(data["p1"], data["p2"])
				"sound": peer_sound.emit(data["name"])
				"game_over": peer_game_over.emit(data["winner"])
				"spawn_powerup": peer_spawn_powerup.emit(data["x"], data["item_type"])
				"spawn_enemy": peer_spawn_enemy.emit(data["e_type"], data["is_top"], data["dir"])
				"trigger_powerup": peer_trigger_powerup.emit(data["hitter"])

func send_data(data: Dictionary):
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		data["lobby"] = current_lobby_id
		var json_str = JSON.stringify(data)
		socket.put_packet(json_str.to_utf8_buffer())

extends Control

enum MenuState { TITLE, MAIN, NPC_DIFF, POINTS, MULTIPLAYER, SETTINGS, HIDDEN }

var current_state: MenuState = MenuState.TITLE
var history: Array[MenuState] = []
var selected_mode: String = ""
var selected_diff: String = ""
var current_lang: int = 0
var languages: Array[String] = ["English", "Espanol", "Portugues", "Italiano"]
var tv_effect_on: bool = false
var music_volume: int = 100
var sound_volume: int = 100
var last_click_time: int = 0
var active_target_button: Button = null
var intro_music = preload("res://Assets/Audio/Music/main_menu_music_i.ogg")
var loop_music = preload("res://Assets/Audio/Music/main_menu_music.ogg")
var is_starting_game: bool = false
var can_interact: bool = false
var is_sliding: bool = false
var menu_bar_original_x: float = 600.0
var title_original_x: float = 0.0

@export var title_left_offset: float = -190.0

@onready var title_screen = $CanvasLayer/UIContainer/Title
@onready var menu_bar = $CanvasLayer/UIContainer/MenuBar
@onready var main_menu_buttons = $CanvasLayer/UIContainer/MenuBar/MainMenuButtons
@onready var npc_diff_menu = $CanvasLayer/UIContainer/MenuBar/NPCDiffMenu
@onready var points_menu = $CanvasLayer/UIContainer/MenuBar/PointsMenu
@onready var multiplayer_menu = $CanvasLayer/UIContainer/MenuBar/MultiplayerMenu
@onready var settings_menu = $CanvasLayer/UIContainer/MenuBar/SettingsMenu
@onready var multiplayer_status_label = $CanvasLayer/UIContainer/MenuBar/MultiplayerStatusLabel
@onready var join_input_dialog = $CanvasLayer/UIContainer/MenuBar/MultiplayerStatusLabel/JoinInputDialog
@onready var join_line_edit = join_input_dialog.get_node("JoinLineEdit") 
@onready var discord_button = $CanvasLayer/UIContainer/MenuBar/DiscordButton
@onready var github_button = $CanvasLayer/UIContainer/MenuBar/GitHubButton

@onready var red_arrow = $CanvasLayer/UIContainer/RedArrow
@onready var music_player = $MusicPlayer
@onready var iris_rect = $IrisRect
@onready var crt_overlay = $CanvasLayer/UIContainer/CRTOverlay
@onready var arrow_sound = $ArrowSound
@onready var click_sound = $ClickSound

func _ready() -> void:
	_enable_interaction_timer()
	if title_screen:
		title_original_x = title_screen.position.x
	if menu_bar:
		menu_bar.position.x = menu_bar_original_x + 900
	_load_settings() 
	if crt_overlay:
		crt_overlay.visible = tv_effect_on
	if has_node("CRTOverlay"):
		$CRTOverlay.visible = GameManager.tv_effect_enabled
	if multiplayer_status_label: 
		multiplayer_status_label.visible = false
	if not WebsocketManager.match_ready.is_connected(_on_match_found):
		WebsocketManager.match_ready.connect(_on_match_found)
	if not join_input_dialog.confirmed.is_connected(_on_join_code_confirmed):
		join_input_dialog.confirmed.connect(_on_join_code_confirmed)
	_connect_menu_buttons()
	_display_state(MenuState.TITLE)
	music_player.stream = intro_music
	music_player.play()
	if not music_player.finished.is_connected(_on_music_finished):
		music_player.finished.connect(_on_music_finished)
	title_screen.modulate.a = 0.0
	if iris_rect and iris_rect.material is ShaderMaterial:
		iris_rect.material.set_shader_parameter("radius", 0.0)
		var fade_tween = create_tween()
		fade_tween.tween_property(title_screen, "modulate:a", 1.0, 0.5)
		await fade_tween.finished
		await get_tree().create_timer(0.5).timeout
		var iris_tween = create_tween()
		iris_tween.tween_property(iris_rect.material, "shader_parameter/radius", 1.5, 1.0)
	_update_settings_text()

func _enable_interaction_timer() -> void:
	await get_tree().create_timer(2.0).timeout
	can_interact = true

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		GameManager.current_lang_index = config.get_value("Settings", "lang_index", 0)
		GameManager.tv_effect_enabled = config.get_value("Settings", "tv_effect", false)
		GameManager.music_volume = config.get_value("Settings", "music_volume", 100)
		GameManager.sound_volume = config.get_value("Settings", "sound_volume", 100)
	current_lang = GameManager.current_lang_index
	tv_effect_on = GameManager.tv_effect_enabled
	music_volume = GameManager.music_volume
	sound_volume = GameManager.sound_volume

	var locales = ["en", "es", "pt", "it"]
	TranslationServer.set_locale(locales[clamp(current_lang, 0, locales.size() - 1)])
	_apply_audio_volumes()

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "lang_index", GameManager.current_lang_index)
	config.set_value("Settings", "tv_effect", GameManager.tv_effect_enabled)
	config.set_value("Settings", "music_volume", GameManager.music_volume)
	config.set_value("Settings", "sound_volume", GameManager.sound_volume)
	config.save("user://settings.cfg")

func _apply_audio_volumes() -> void:
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume / 100.0))
		AudioServer.set_bus_mute(music_idx, music_volume == 0)
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sound_volume / 100.0))
		AudioServer.set_bus_mute(sfx_idx, sound_volume == 0)

func _connect_menu_buttons() -> void:
	var menus = [main_menu_buttons, npc_diff_menu, points_menu, multiplayer_menu, settings_menu]
	for menu in menus:
		if menu:
			_search_and_connect_buttons(menu, menu)

func _search_and_connect_buttons(current_node: Node, menu_root: Node) -> void:
	for child in current_node.get_children():
		if child is Button:
			if not child.mouse_entered.is_connected(_move_arrow_to_target):
				child.mouse_entered.connect(_move_arrow_to_target.bind(child))
			if not child.focus_entered.is_connected(_move_arrow_to_target):
				child.focus_entered.connect(_move_arrow_to_target.bind(child))
			if not child.pressed.is_connected(_play_click_sound):
				child.pressed.connect(_play_click_sound)
			if menu_root == npc_diff_menu:
				if not child.pressed.is_connected(_on_difficulty_selected):
					child.pressed.connect(_on_difficulty_selected.bind(child.text))
			elif menu_root == points_menu:
				if not child.pressed.is_connected(_on_points_selected):
					child.pressed.connect(_on_points_selected.bind(child.text.to_int()))
		else:
			_search_and_connect_buttons(child, menu_root)

func _move_arrow_to_target(target_button: Button) -> void:
	if active_target_button != target_button:
		active_target_button = target_button
		if red_arrow:
			red_arrow.visible = true
		if arrow_sound and (Time.get_ticks_msec() - last_click_time > 150):
			arrow_sound.play()

func _play_click_sound() -> void:
	last_click_time = Time.get_ticks_msec()
	if arrow_sound and arrow_sound.playing:
		arrow_sound.stop()
	if click_sound:
		click_sound.play()

func _process(_delta: float) -> void:
	if red_arrow and red_arrow.visible:
		var target = active_target_button
		if is_instance_valid(target):
			red_arrow.global_position = Vector2(target.global_position.x - 30, target.global_position.y + (target.size.y / 2) - (red_arrow.size.y / 2))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if current_state != MenuState.TITLE: _handle_back()
		else: get_tree().quit()

func _input(event: InputEvent) -> void:
	if not can_interact or is_sliding: 
		return
	if event.is_action_pressed("ui_cancel") and current_state != MenuState.TITLE:
		_handle_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		if event.keycode == KEY_VOLUMEUP or event.keycode == KEY_VOLUMEDOWN:
			return
	if current_state == MenuState.TITLE:
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
			if event.is_pressed():
				_slide_menu_in()
				_change_state(MenuState.MAIN)
				get_viewport().set_input_as_handled()

func _slide_menu_in() -> void:
	if menu_bar:
		is_sliding = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(menu_bar, "position:x", menu_bar_original_x, 0.5)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if title_screen:
			tween.tween_property(title_screen, "position:x", title_original_x + title_left_offset, 0.5)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await tween.finished
		is_sliding = false

func _slide_menu_out() -> void:
	if menu_bar:
		is_sliding = true
		var tween = create_tween().set_parallel(true)
		tween.tween_property(menu_bar, "position:x", menu_bar_original_x + 500, 0.4)\
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		if title_screen:
			tween.tween_property(title_screen, "position:x", title_original_x, 0.4)\
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await tween.finished
		is_sliding = false

func _on_music_finished() -> void:
	if music_player.stream == intro_music:
		music_player.stream = loop_music
		music_player.play()

func _change_state(new_state: MenuState) -> void:
	if current_state != MenuState.TITLE and current_state != MenuState.HIDDEN:
		history.append(current_state)
	current_state = new_state
	active_target_button = null
	_display_state(current_state)

func _handle_back() -> void:
	if multiplayer_status_label.visible:
		multiplayer_status_label.visible = false
		WebsocketManager.cleanup()
		_change_state(MenuState.MULTIPLAYER)
		return
	if history.size() > 0:
		current_state = history.pop_back()
		_display_state(current_state)
	else:
		await _slide_menu_out()
		current_state = MenuState.TITLE
		_display_state(current_state)

func _display_state(state: MenuState) -> void:
	last_click_time = Time.get_ticks_msec()
	title_screen.visible = (state != MenuState.HIDDEN or MenuState.MULTIPLAYER)
	main_menu_buttons.visible = (state == MenuState.MAIN)
	npc_diff_menu.visible = (state == MenuState.NPC_DIFF)
	points_menu.visible = (state == MenuState.POINTS)
	multiplayer_menu.visible = (state == MenuState.MULTIPLAYER)
	settings_menu.visible = (state == MenuState.SETTINGS)
	if red_arrow:
		red_arrow.visible = (state != MenuState.TITLE and state != MenuState.HIDDEN)
	var active_menu = null
	if main_menu_buttons.visible: active_menu = main_menu_buttons
	elif npc_diff_menu.visible: active_menu = npc_diff_menu
	elif points_menu.visible: active_menu = points_menu
	elif multiplayer_menu.visible: active_menu = multiplayer_menu
	elif settings_menu.visible: active_menu = settings_menu
	if active_menu:
		var first_btn = _find_first_button_recursive(active_menu)
		if first_btn:
			active_target_button = first_btn
			first_btn.grab_focus()

func _find_first_button_recursive(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var sub_child = _find_first_button_recursive(child)
		if sub_child:
			return sub_child
	return null

func _on_vs_npc_pressed() -> void:
	selected_mode = "NPC"
	_change_state(MenuState.NPC_DIFF)

func _on_local_game_pressed() -> void:
	selected_mode = "LOCAL"
	_change_state(MenuState.POINTS)

func _on_multiplayer_pressed() -> void:
	selected_mode = "MULTIPLAYER"
	_change_state(MenuState.POINTS)

func _on_difficulty_selected(diff: String = "") -> void:
	if diff == "" and active_target_button:
		diff = active_target_button.text
	selected_diff = diff
	GameManager.npc_difficulty = selected_diff
	_change_state(MenuState.POINTS)

func _on_points_selected(points: int = -1) -> void:
	if is_starting_game:
		return 
	is_starting_game = true
	if points == -1 and active_target_button:
		points = active_target_button.text.to_int()
	GameManager.max_score = points
	if selected_mode == "NPC":
		GameManager.current_mode = GameManager.Mode.NPC
	elif selected_mode == "LOCAL":
		GameManager.current_mode = GameManager.Mode.LOCAL
	elif selected_mode == "MULTIPLAYER":
		GameManager.current_mode = GameManager.Mode.MULTIPLAYER
	if selected_mode == "MULTIPLAYER":
		is_starting_game = false
		_change_state(MenuState.MULTIPLAYER)
	else:
		points_menu.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().create_timer(0.15).timeout
		Transitioner.change_scene("res://Scenes/game.tscn")

func _on_host_game_pressed() -> void:
	GameManager.current_mode = GameManager.Mode.MULTIPLAYER
	_change_state(MenuState.HIDDEN)
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var lobby_code = str(rng.randi_range(1000, 9999)) 
	multiplayer_status_label.text = "LOBBY CODE: " + lobby_code
	multiplayer_status_label.visible = true
	WebsocketManager.start_host(lobby_code)

func _on_join_pressed() -> void:
	GameManager.current_mode = GameManager.Mode.MULTIPLAYER
	join_line_edit.text = ""
	join_input_dialog.popup()

func _on_join_code_confirmed() -> void:
	GameManager.current_mode = GameManager.Mode.MULTIPLAYER
	var code = join_line_edit.text.strip_edges()
	join_line_edit.text = ""
	if code == "": 
		return
	_change_state(MenuState.HIDDEN)
	multiplayer_status_label.text = "CONNECTING TO: " + code
	multiplayer_status_label.visible = true
	WebsocketManager.start_join(code)

func _on_match_found() -> void:
	multiplayer_status_label.text = "CONNECTED! STARTING GAME"
	Transitioner.change_scene("res://Scenes/game.tscn")

func _on_settings_pressed() -> void:
	_change_state(MenuState.SETTINGS)

func _on_lang_button_pressed() -> void:
	current_lang = (GameManager.current_lang_index + 1) % languages.size()
	GameManager.current_lang_index = current_lang
	var locales = ["en", "es", "pt", "it"]
	TranslationServer.set_locale(locales[current_lang])
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	_update_settings_text()
	_save_settings()

func _on_tv_button_pressed() -> void:
	tv_effect_on = !tv_effect_on
	GameManager.tv_effect_enabled = tv_effect_on
	if crt_overlay:
		crt_overlay.visible = tv_effect_on
	_update_settings_text()
	_save_settings()

func _on_music_button_pressed() -> void:
	music_volume = (music_volume + 10) % 110
	GameManager.music_volume = music_volume
	_apply_audio_volumes()
	_update_settings_text()
	_save_settings()

func _on_sound_button_pressed() -> void:
	sound_volume = (sound_volume + 10) % 110
	GameManager.sound_volume = sound_volume
	_apply_audio_volumes()
	_update_settings_text()
	_save_settings()

func _update_settings_text() -> void:
	settings_menu.get_node("LangButton").text = tr("LANGUAGES_OPTION") + ": " + languages[current_lang]
	var tv_status = "ON" if tv_effect_on else "OFF"
	settings_menu.get_node("OldTVButton").text = tr("OLD_TV_OPTION") + ": " + tv_status
	settings_menu.get_node("MusicButton").text = tr("MUSIC_VOL") + ": " + str(music_volume)
	settings_menu.get_node("SoundButton").text = tr("SOUNDS_VOL") + ": " + str(sound_volume)

func _on_discord_button_pressed() -> void:
	discord_button.play("press")
	await get_tree().create_timer(0.5).timeout
	discord_button.play("default")

func _on_github_button_pressed() -> void:
	github_button.play("press")
	await get_tree().create_timer(0.5).timeout
	github_button.play("default")

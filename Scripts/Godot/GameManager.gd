extends Node

enum Mode { LOCAL, NPC, MULTIPLAYER }
enum Difficulty { EASY, MEDIUM, HARD }

var current_mode: Mode = Mode.LOCAL
var npc_difficulty: String = ""
var max_score: int = 10
var tv_effect_enabled: bool = false
var music_volume: int = 100
var sound_volume: int = 100
var current_lang_index: int = 0

signal shadows_toggled(enabled: bool)

var shadows_enabled: bool = true:
	set(value):
		shadows_enabled = value
		shadows_toggled.emit(shadows_enabled)

@rpc("authority", "call_local", "reliable")
func sync_game_settings(new_max_score: int) -> void:
	max_score = new_max_score

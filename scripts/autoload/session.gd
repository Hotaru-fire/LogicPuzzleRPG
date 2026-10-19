extends Node

var user_id: int = -1
var username: String = ""

var selected_character: String = ""
var level: int = 1
var player_exp: int = 0
var gold: int = 0

var score: int = 0
var mobs_defeated: int = 0
var dungeon_enemies_defeated: int = 0
var bosses_killed: int = 0


func is_logged_in() -> bool:
	return user_id > 0


func clear_session() -> void:
	user_id = -1
	username = ""
	selected_character = ""
	level = 1
	player_exp = 0
	gold = 0
	score = 0
	mobs_defeated = 0
	bosses_killed = 0
	dungeon_enemies_defeated = 0


func record_mob_kill(points: int = 10) -> void:
	mobs_defeated += 1
	score += points

	print("Total mobs killed: ", mobs_defeated)
	print("Current score: ", score)


func record_boss_kill(points: int = 100) -> void:
	bosses_killed += 1
	score += points

	print("Total bosses killed: ", bosses_killed)
	print("Current score: ", score)

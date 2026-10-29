extends Node

signal stats_changed

const EXP_BASE_REQUIREMENT := 100
const EXP_REQUIREMENT_PER_LEVEL := 50
const MAX_SAVED_INT := 9223372036854775807
const MAX_COUNTER := 4294967295
const MAX_SIGNED_COUNTER := 2147483647

# Balance rewards here; level N requires 100 + 50 * (N - 1) EXP.
const NORMAL_MOB_EXP := 25
const NORMAL_MOB_GOLD := 8
const NORMAL_MOB_SCORE := 10
const DUNGEON_ENEMY_EXP := 40
const DUNGEON_ENEMY_GOLD := 12
const DUNGEON_ENEMY_SCORE := 20
const BOSS_EXP := 250
const BOSS_GOLD := 100
const BOSS_SCORE := 100
const PUZZLE_CLEAR_SCORE := 50
const PUZZLE_SCORE_REFERENCE_SECONDS := 10.0
const PUZZLE_SCORE_PER_SECOND := 5.0
# Puzzle score is 50 + 5 * max(10 - clear_seconds, 0), rounded down.
const DEATH_SCREEN_SCENE := preload("res://scenes/main/death_screen.tscn")

var user_id: int = -1
var username: String = ""
var auth_token: String = ""

var selected_character: String = ""
var level: int = 1
var player_exp: int = 0
var gold: int = 0

var score: int = 0
var mobs_defeated: int = 0
var dungeon_enemies_defeated: int = 0
var bosses_killed: int = 0

var total_deaths: int = 0
var puzzle_clear_time: float = 0.0
var best_puzzle_clear_time: float = 0.0
var first_puzzle_clear_time: float = 0.0
var puzzle_time_improvement: float = 0.0
var puzzles_cleared: int = 0

var playtime_seconds: int = 0
var _unsaved_playtime_msec: int = 0
var _gameplay_time_active := false
var _last_playtime_tick_msec: int = 0
var _exit_save_pending := false
var _death_screen_active := false
var checkpoint_data: Dictionary = {}
var checkpoint_user_id: int = -1
var _last_displayed_playtime_seconds := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_playtime_tick_msec = Time.get_ticks_msec()
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(_on_window_close_requested)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var elapsed_msec := maxi(now - _last_playtime_tick_msec, 0)
	_last_playtime_tick_msec = now

	if (
		_gameplay_time_active
		and not get_tree().paused
		and elapsed_msec > 0
	):
		_add_unsaved_playtime(elapsed_msec)
		var display_seconds := playtime_seconds + int(
			_unsaved_playtime_msec / 1000
		)
		if display_seconds != _last_displayed_playtime_seconds:
			_last_displayed_playtime_seconds = display_seconds
			stats_changed.emit()


func start_gameplay_time() -> void:
	_gameplay_time_active = true
	_last_playtime_tick_msec = Time.get_ticks_msec()


func stop_gameplay_time() -> void:
	_update_playtime_clock()
	_gameplay_time_active = false


func get_playtime_snapshot() -> Dictionary:
	_update_playtime_clock()
	var unsaved_seconds := int(_unsaved_playtime_msec / 1000)
	var additional_seconds := mini(
		unsaved_seconds,
		MAX_SAVED_INT - playtime_seconds
	)
	return {
		"playtime_seconds": playtime_seconds + additional_seconds,
		"unsaved_playtime_msec": _unsaved_playtime_msec
	}


func confirm_playtime_saved(saved_seconds: int, elapsed_snapshot_msec: int) -> void:
	if saved_seconds < playtime_seconds or elapsed_snapshot_msec < 0:
		return

	playtime_seconds = mini(saved_seconds, MAX_SAVED_INT)
	_unsaved_playtime_msec = maxi(
		_unsaved_playtime_msec - elapsed_snapshot_msec,
		0
	)
	stats_changed.emit()


func _update_playtime_clock() -> void:
	var now := Time.get_ticks_msec()
	var elapsed_msec := maxi(now - _last_playtime_tick_msec, 0)
	_last_playtime_tick_msec = now

	if _gameplay_time_active and not get_tree().paused:
		_add_unsaved_playtime(elapsed_msec)


func _on_window_close_requested() -> void:
	if _exit_save_pending:
		return

	if not _gameplay_time_active or not is_logged_in():
		get_tree().quit()
		return

	_exit_save_pending = true
	stop_gameplay_time()

	if not GameAPI.save_progress():
		push_error("Could not start the final save before exiting.")
		get_tree().quit()
		return

	var response: Array
	while true:
		response = await GameAPI.response_received
		if (
			str(response[2].get("action", "")) == "save_progress"
			and not GameAPI.request_pending
			and GameAPI.queued_payloads.is_empty()
		):
			break

	if not bool(response[0]):
		push_error("Final save failed before exiting: " + str(response[1]))

	get_tree().quit()


func begin_player_death() -> void:
	if _death_screen_active:
		return

	_death_screen_active = true
	stop_gameplay_time()
	record_death()

	if is_logged_in():
		GameAPI.record_death()

	get_tree().paused = true
	call_deferred("_change_to_death_screen")


func finish_player_respawn() -> void:
	_death_screen_active = false
	get_tree().paused = false
	start_gameplay_time()


func dismiss_death_screen() -> void:
	_death_screen_active = false
	get_tree().paused = false


func _change_to_death_screen() -> void:
	var tree := get_tree()
	tree.paused = false
	var error := tree.change_scene_to_packed(DEATH_SCREEN_SCENE)
	tree.paused = true

	if error != OK:
		push_error("Could not load the DeathScreen. Error: " + str(error))


func transition_from_death_screen(scene_path: String) -> Error:
	if not ResourceLoader.exists(scene_path):
		return ERR_FILE_NOT_FOUND

	var tree := get_tree()
	tree.paused = false
	var error := tree.change_scene_to_file(scene_path)
	tree.paused = true
	if error != OK:
		return error

	await tree.scene_changed
	finish_player_respawn()
	return OK


func return_to_main_menu_from_death_screen(scene_path: String) -> Error:
	if not ResourceLoader.exists(scene_path):
		return ERR_FILE_NOT_FOUND

	var tree := get_tree()
	tree.paused = false
	var error := tree.change_scene_to_file(scene_path)
	tree.paused = true
	if error != OK:
		return error

	dismiss_death_screen()
	return OK


func is_death_screen_active() -> bool:
	return _death_screen_active


func validate_checkpoint(data: Dictionary) -> bool:
	for field in [
		"character_class",
		"level",
		"exp",
		"gold",
		"score",
		"current_scene",
		"hp",
		"max_hp",
		"attack",
		"defense",
		"player_position_x",
		"player_position_y",
		"inventory",
		"equipment"
	]:
		if not data.has(field):
			return false

	var character_class := str(data.get("character_class", ""))
	if not ["Knight", "Mage", "Thief", "Archer"].has(character_class):
		return false

	var scene_path := str(data.get("current_scene", ""))
	if scene_path == "res://scenes/world.tscn":
		scene_path = "res://scenes/maps/world.tscn"
	if not scene_path.begins_with("res://") or not ResourceLoader.exists(scene_path):
		return false
	if scene_path.contains("/battle/"):
		return false

	var max_hp_value := int(data.get("max_hp", 0))
	if max_hp_value < 1:
		return false
	if int(data.get("hp", -1)) < 0 or int(data.get("hp", -1)) > max_hp_value:
		return false
	if int(data.get("level", 0)) < 1:
		return false
	for field in [
		"level",
		"hp",
		"max_hp",
		"attack",
		"defense"
	]:
		if not data[field] is int:
			return false
	for field in [
		"exp",
		"gold",
		"score",
		"attack",
		"defense",
		"player_position_x",
		"player_position_y"
	]:
		var value: Variant = data[field]
		if not (value is int or value is float):
			return false
		if not is_finite(float(value)) or float(value) < 0.0:
			if field != "player_position_x" and field != "player_position_y":
				return false
	if not (data["player_position_x"] is int or data["player_position_x"] is float):
		return false
	if not (data["player_position_y"] is int or data["player_position_y"] is float):
		return false
	if not is_finite(float(data["player_position_x"])) or not is_finite(
		float(data["player_position_y"])
	):
		return false
	if not (data.get("inventory") is String) or not (
		data.get("equipment") is String
	):
		return false
	var inventory_json := JSON.new()
	if inventory_json.parse(data["inventory"]) != OK:
		return false
	if not (
		inventory_json.data is Array
		or inventory_json.data is Dictionary
	):
		return false
	var equipment_json := JSON.new()
	if equipment_json.parse(data["equipment"]) != OK:
		return false
	if not (
		equipment_json.data is Array
		or equipment_json.data is Dictionary
	):
		return false

	return true


func accept_checkpoint(data: Dictionary, owner_user_id: int) -> bool:
	if owner_user_id != user_id or not validate_checkpoint(data):
		return false
	checkpoint_data = data.duplicate(true)
	checkpoint_user_id = owner_user_id
	return true


func cache_offline_checkpoint(data: Dictionary) -> bool:
	if is_logged_in() or not validate_checkpoint(data):
		return false
	checkpoint_data = data.duplicate(true)
	checkpoint_user_id = -1
	return true


func get_checkpoint_for_current_session() -> Dictionary:
	if checkpoint_data.is_empty() or checkpoint_user_id != user_id:
		return {}
	return checkpoint_data.duplicate(true)


func restore_checkpoint(data: Dictionary) -> bool:
	if not validate_checkpoint(data):
		return false

	var deaths_before_restore := total_deaths
	selected_character = str(data["character_class"])
	PlayerData.player_name = username
	match selected_character:
		"Knight":
			PlayerData.selected_character = 1
		"Mage":
			PlayerData.selected_character = 2
		"Thief":
			PlayerData.selected_character = 3
		"Archer":
			PlayerData.selected_character = 4
		_:
			PlayerData.selected_character = 0
	PlayerData.saved_current_scene = str(data["current_scene"])
	if PlayerData.saved_current_scene == "res://scenes/world.tscn":
		PlayerData.saved_current_scene = "res://scenes/maps/world.tscn"
	PlayerData.saved_position = Vector2(
		float(data["player_position_x"]),
		float(data["player_position_y"])
	)
	PlayerData.saved_max_hp = int(data["max_hp"])
	PlayerData.set_health(
		maxi(int(data["hp"]), 1),
		PlayerData.saved_max_hp
	)
	PlayerData.saved_attack = int(data["attack"])
	PlayerData.saved_defense = int(data["defense"])
	PlayerData.saved_inventory = str(data["inventory"])
	PlayerData.saved_equipment = str(data["equipment"])
	PlayerData.saved_boss_completed = bool(data.get("boss_completed", false))
	PlayerData.has_save_data = true

	level = clampi(int(data["level"]), 1, MAX_COUNTER)
	player_exp = clampi(int(data["exp"]), 0, MAX_SAVED_INT)
	gold = clampi(int(data["gold"]), 0, MAX_SAVED_INT)
	score = clampi(int(data["score"]), 0, MAX_SAVED_INT)
	mobs_defeated = clampi(int(data.get("mobs_defeated", 0)), 0, MAX_COUNTER)
	dungeon_enemies_defeated = clampi(
		int(data.get("dungeon_enemies_defeated", 0)),
		0,
		MAX_SIGNED_COUNTER
	)
	bosses_killed = clampi(
		int(data.get("bosses_killed", 0)),
		0,
		MAX_SIGNED_COUNTER
	)
	load_analytics(data)
	total_deaths = maxi(total_deaths, deaths_before_restore)
	stats_changed.emit()
	return true


func _add_unsaved_playtime(elapsed_msec: int) -> void:
	var additional_msec := mini(
		elapsed_msec,
		MAX_SAVED_INT - _unsaved_playtime_msec
	)
	_unsaved_playtime_msec += additional_msec


func exp_required_for_next_level(current_level: int = -1) -> int:
	var checked_level := level if current_level < 1 else current_level
	return EXP_BASE_REQUIREMENT + (
		mini(checked_level - 1, MAX_COUNTER) * EXP_REQUIREMENT_PER_LEVEL
	)


func award_exp(amount: int) -> int:
	var reward := clampi(amount, 0, 1000000)
	if reward == 0:
		return 0

	var gained := mini(reward, MAX_SAVED_INT - player_exp)
	player_exp += gained
	print("EXP gained: ", gained, " (", player_exp, " toward next level)")

	while level < MAX_COUNTER:
		var requirement := exp_required_for_next_level(level)
		if player_exp < requirement:
			break
		player_exp -= requirement
		level += 1
		print("LEVEL UP! Current level: ", level)

	stats_changed.emit()
	return gained


func award_gold(amount: int) -> int:
	var reward := clampi(amount, 0, MAX_SAVED_INT)
	var gained := mini(reward, MAX_SAVED_INT - gold)
	gold += gained
	stats_changed.emit()
	return gained


func award_score(amount: int) -> int:
	var reward := clampi(amount, 0, MAX_SAVED_INT)
	var gained := mini(reward, MAX_SAVED_INT - score)
	score += gained
	stats_changed.emit()
	return gained


func record_normal_mob_kill(
	exp_reward: int = NORMAL_MOB_EXP,
	gold_reward: int = NORMAL_MOB_GOLD,
	score_reward: int = NORMAL_MOB_SCORE
) -> void:
	mobs_defeated = mini(mobs_defeated + 1, MAX_COUNTER)
	award_exp(exp_reward)
	award_gold(gold_reward)
	award_score(score_reward)
	stats_changed.emit()
	print("Normal mobs defeated: ", mobs_defeated, " | score: ", score)


func record_dungeon_enemy_kill(
	exp_reward: int = DUNGEON_ENEMY_EXP,
	gold_reward: int = DUNGEON_ENEMY_GOLD,
	score_reward: int = DUNGEON_ENEMY_SCORE
) -> void:
	dungeon_enemies_defeated = mini(
		dungeon_enemies_defeated + 1,
		MAX_SIGNED_COUNTER
	)
	award_exp(exp_reward)
	award_gold(gold_reward)
	award_score(score_reward)
	stats_changed.emit()
	print("Dungeon enemies defeated: ", dungeon_enemies_defeated)


func record_boss_kill(
	exp_reward: int = BOSS_EXP,
	gold_reward: int = BOSS_GOLD,
	score_reward: int = BOSS_SCORE
) -> void:
	bosses_killed = mini(bosses_killed + 1, MAX_SIGNED_COUNTER)
	award_exp(exp_reward)
	award_gold(gold_reward)
	award_score(score_reward)
	stats_changed.emit()
	print("Bosses defeated: ", bosses_killed, " | score: ", score)


func record_puzzle_clear(elapsed_seconds: float) -> bool:
	if (
		not is_finite(elapsed_seconds)
		or elapsed_seconds <= 0.0
		or elapsed_seconds > 86400.0
	):
		return false

	var previous_best := best_puzzle_clear_time
	puzzle_clear_time = elapsed_seconds
	puzzles_cleared = mini(puzzles_cleared + 1, MAX_COUNTER)

	if first_puzzle_clear_time <= 0.0:
		first_puzzle_clear_time = elapsed_seconds

	# Improvement is seconds faster than the previous best, or zero otherwise.
	puzzle_time_improvement = 0.0
	if previous_best > 0.0 and elapsed_seconds < previous_best:
		puzzle_time_improvement = previous_best - elapsed_seconds

	if previous_best <= 0.0 or elapsed_seconds < previous_best:
		best_puzzle_clear_time = elapsed_seconds

	var time_bonus := int(
		maxf(
			PUZZLE_SCORE_REFERENCE_SECONDS - elapsed_seconds,
			0.0
		) * PUZZLE_SCORE_PER_SECOND
	)
	award_score(PUZZLE_CLEAR_SCORE + time_bonus)
	stats_changed.emit()

	print("Puzzles cleared: ", puzzles_cleared)
	print("Latest puzzle time: ", puzzle_clear_time, " seconds")
	print("Best puzzle time: ", best_puzzle_clear_time, " seconds")
	print("Puzzle time improvement: ", puzzle_time_improvement, " seconds")
	return true


func record_death() -> void:
	total_deaths = mini(total_deaths + 1, MAX_COUNTER)
	stats_changed.emit()
	print("TOTAL PLAYER DEATHS: ", total_deaths)


func is_logged_in() -> bool:
	return user_id > 0 and not auth_token.is_empty()


func clear_session() -> void:
	stop_gameplay_time()
	user_id = -1
	username = ""
	auth_token = ""
	selected_character = ""
	checkpoint_data.clear()
	checkpoint_user_id = -1
	_death_screen_active = false
	reset_game_progress()


func load_analytics(data: Dictionary) -> void:
	total_deaths = clampi(int(data.get("total_deaths", 0)), 0, MAX_COUNTER)
	puzzle_clear_time = maxf(float(data.get("puzzle_clear_time", 0.0)), 0.0)
	best_puzzle_clear_time = maxf(
		float(data.get("best_puzzle_clear_time", 0.0)),
		0.0
	)
	first_puzzle_clear_time = maxf(
		float(data.get("first_puzzle_clear_time", 0.0)),
		0.0
	)
	puzzle_time_improvement = maxf(
		float(data.get("puzzle_time_improvement", 0.0)),
		0.0
	)
	puzzles_cleared = clampi(int(data.get("puzzles_cleared", 0)), 0, MAX_COUNTER)
	playtime_seconds = clampi(int(data.get("playtime_seconds", 0)), 0, MAX_SAVED_INT)
	_unsaved_playtime_msec = 0
	_last_displayed_playtime_seconds = playtime_seconds
	stats_changed.emit()


func reset_game_progress() -> void:
	level = 1
	player_exp = 0
	gold = 0
	score = 0
	mobs_defeated = 0
	dungeon_enemies_defeated = 0
	bosses_killed = 0
	total_deaths = 0
	puzzle_clear_time = 0.0
	best_puzzle_clear_time = 0.0
	first_puzzle_clear_time = 0.0
	puzzle_time_improvement = 0.0
	puzzles_cleared = 0
	playtime_seconds = 0
	_unsaved_playtime_msec = 0
	_gameplay_time_active = false
	_last_playtime_tick_msec = Time.get_ticks_msec()
	_death_screen_active = false
	checkpoint_data.clear()
	checkpoint_user_id = -1
	_last_displayed_playtime_seconds = -1
	stats_changed.emit()

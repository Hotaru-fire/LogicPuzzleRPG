extends Node

signal response_received(success: bool, message: String, data: Dictionary)

const API_URL := "http://127.0.0.1/rpg_api/game_data.php"

var http_request: HTTPRequest
var request_pending := false
var queued_payload: Dictionary = {}
var current_request_action := ""


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)


func save_character(character_class: String) -> bool:
	return _send_request({
		"action": "save_character",
		"character_class": character_class
	})


func check_save() -> bool:
	return _send_request({
		"action": "check_save"
	})


func delete_save() -> bool:
	return _send_request({
		"action": "delete_save"
	})


func load_save() -> bool:
	return _send_request({
		"action": "load_save"
	})



func save_progress() -> bool:
	var character_class := Session.selected_character

	if character_class.is_empty():
		match PlayerData.selected_character:
			1:
				character_class = "Knight"
			2:
				character_class = "Mage"
			3:
				character_class = "Thief"
			4:
				character_class = "Archer"

	var scene_path := PlayerData.saved_current_scene
	var save_position := PlayerData.saved_position
	var current_scene := get_tree().current_scene
	var current_scene_path := ""

	if current_scene != null:
		current_scene_path = current_scene.scene_file_path
		if not current_scene_path.is_empty():
			scene_path = current_scene_path

	print("SAVE: Current scene path: ", current_scene_path)

	if current_scene_path.contains("/battle/"):
		if BattleData.return_scene.is_empty():
			push_error("SAVE: Battle scene has no recorded return scene.")
			return false

		scene_path = BattleData.return_scene
		save_position = BattleData.return_position
		print("SAVE: Using battle return position: ", save_position)
	else:
		var player := _find_player_in_current_scene()
		print("SAVE: Player found: ", player != null)

		if player == null:
			push_error(
				"SAVE: No player found in the current scene; "
				+ "database save was not sent."
			)
			return false

		print("SAVE: Player node path: ", player.get_path())
		print("SAVE: Player global position: ", player.global_position)
		save_position = player.global_position

		PlayerData.saved_hp = int(
			_get_property(player, "hp", PlayerData.saved_hp)
		)
		PlayerData.saved_max_hp = int(
			_get_property(player, "max_hp", PlayerData.saved_max_hp)
		)
		PlayerData.saved_attack = int(
			_get_property(player, "attack", PlayerData.saved_attack)
		)
		PlayerData.saved_defense = int(
			_get_property(player, "defense", PlayerData.saved_defense)
		)

	print("SAVE: save_position: ", save_position)

	PlayerData.saved_position = save_position
	PlayerData.saved_current_scene = scene_path

	var payload := {
		"action": "save_progress",
		"character_class": character_class,
		"level": Session.level,
		"exp": Session.player_exp,
		"gold": Session.gold,
		"score": Session.score,
		"mobs_defeated": Session.mobs_defeated,
		"dungeon_enemies_defeated": Session.dungeon_enemies_defeated,
		"bosses_killed": Session.bosses_killed,
		"total_deaths": Session.total_deaths,
		"puzzle_clear_time": Session.puzzle_clear_time,
		"best_puzzle_clear_time": Session.best_puzzle_clear_time,
		"first_puzzle_clear_time": Session.first_puzzle_clear_time,
		"puzzle_time_improvement": Session.puzzle_time_improvement,
		"puzzles_cleared": Session.puzzles_cleared,
		"playtime_seconds": 0,
		"hp": PlayerData.saved_hp,
		"max_hp": PlayerData.saved_max_hp,
		"attack": PlayerData.saved_attack,
		"defense": PlayerData.saved_defense,
		"current_scene": scene_path,
		"boss_completed": PlayerData.saved_boss_completed,
		"inventory": PlayerData.saved_inventory,
		"equipment": PlayerData.saved_equipment,
		"player_position_x": save_position.x,
		"player_position_y": save_position.y
	}

	print("SAVE: Final payload player_position_x = ", payload["player_position_x"])
	print("SAVE: Final payload player_position_y = ", payload["player_position_y"])

	return _send_request(payload)


func record_score(final_score: int) -> bool:
	return _send_request({
		"action": "record_score",
		"score": final_score
	})


func _find_player_in_current_scene() -> Node2D:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D:
			if node == current_scene or current_scene.is_ancestor_of(node):
				return node as Node2D

	return null


func _has_property(target: Object, property_name: String) -> bool:
	for property in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true

	return false


func _get_property(
	target: Object,
	property_name: String,
	fallback: Variant
) -> Variant:
	if _has_property(target, property_name):
		return target.get(property_name)

	return fallback


func _send_request(payload: Dictionary) -> bool:
	if not Session.is_logged_in():
		push_warning("Cannot access game data: no user is logged in.")
		return false

	payload["user_id"] = Session.user_id

	if request_pending:
		queued_payload = payload.duplicate(true)
		return true

	return _start_request(payload)


func _start_request(payload: Dictionary) -> bool:
	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	current_request_action = str(payload.get("action", ""))
	request_pending = true
	print(
		"HTTP REQUEST: action=",
		current_request_action,
		" user_id=",
		payload.get("user_id", "missing")
	)

	var error := http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		request_pending = false
		print(
			"HTTP REQUEST FAILED TO START: action=",
			current_request_action,
			" error=",
			error
		)

		response_received.emit(
			false,
			"Could not send the game-data request.",
			{"action": current_request_action}
		)

		current_request_action = ""
		_send_queued_request()
		return false

	print("HTTP REQUEST STARTED: action=", current_request_action)
	return true


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	request_pending = false

	var completed_action := current_request_action
	current_request_action = ""
	print(
		"HTTP REQUEST COMPLETED: action=",
		completed_action,
		" result=",
		result,
		" response_code=",
		response_code,
		" transport_succeeded=",
		result == HTTPRequest.RESULT_SUCCESS
	)

	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP REQUEST FAILED: action=", completed_action)
		response_received.emit(
			false,
			"Cannot reach the server.",
			{"action": completed_action}
		)
		_send_queued_request()
		return

	var response_text: String = body.get_string_from_utf8()

	print("HTTP RESPONSE CODE: ", response_code)
	print("RAW PHP RESPONSE: ", response_text)

	var json := JSON.new()
	var parse_error := json.parse(response_text)

	if parse_error != OK or not (json.data is Dictionary):
		print("JSON PARSE ERROR: ", json.get_error_message())
		print("JSON ERROR LINE: ", json.get_error_line())

		response_received.emit(
			false,
			"Invalid server response.",
			{"action": completed_action}
		)
		_send_queued_request()
		return

	var data: Dictionary = json.data
	data["action"] = completed_action

	var success := bool(data.get("success", false))
	var message := str(data.get("message", "Unknown response."))

	if response_code < 200 or response_code >= 300:
		success = false

	print("DATABASE RESPONSE: ", message)
	print("DATABASE SUCCESS: ", success)
	print("RESPONSE DATA: ", data)
	if completed_action == "save_progress":
		print("SAVE RESPONSE: ", message, " | success=", success)
	elif completed_action == "load_save":
		print(
			"LOAD RESPONSE POSITION: (",
			data.get("player_position_x", "missing"),
			", ",
			data.get("player_position_y", "missing"),
			")"
		)

	response_received.emit(success, message, data)

	_send_queued_request()


func _send_queued_request() -> void:
	if queued_payload.is_empty():
		return

	var payload := queued_payload.duplicate(true)
	queued_payload.clear()

	_start_request(payload)

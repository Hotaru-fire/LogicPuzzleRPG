extends Node

signal response_received(success: bool, message: String, data: Dictionary)

const API_URL := "http://127.0.0.1/rpg_api/game_data.php"

var http_request: HTTPRequest
var request_pending := false
var queued_payloads: Array[Dictionary] = []
var current_request_action := ""
var current_playtime_seconds := 0
var current_playtime_elapsed_msec := 0
var current_request_checkpoint: Dictionary = {}
var current_request_user_id := -1


func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	http_request.timeout = 10.0
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


func get_leaderboard() -> bool:
	return _send_request({
		"action": "get_leaderboard"
	})


func save_checkpoint() -> bool:
	var snapshot := create_progress_snapshot()
	if snapshot.is_empty():
		return false
	snapshot.erase("_unsaved_playtime_msec")
	if not Session.validate_checkpoint(snapshot):
		push_error("Checkpoint snapshot is missing valid save data.")
		return false

	if not Session.is_logged_in():
		return Session.cache_offline_checkpoint(snapshot)

	return _send_request({
		"action": "save_checkpoint",
		"checkpoint": snapshot
	})


func load_checkpoint() -> bool:
	return _send_request({
		"action": "load_checkpoint"
	})


func record_death() -> bool:
	return _send_request({
		"action": "record_death"
	})



func save_progress() -> bool:
	var payload := create_progress_snapshot()
	if payload.is_empty():
		return false
	payload["action"] = "save_progress"
	return _send_request(payload)


func _resolve_checkpoint_character_class() -> String:
	if Session.selected_character in ["Knight", "Mage", "Thief", "Archer"]:
		return Session.selected_character

	match PlayerData.selected_character:
		1:
			return "Knight"
		2:
			return "Mage"
		3:
			return "Thief"
		4:
			return "Archer"
		_:
			return "Knight"


func _resolve_checkpoint_scene_path(scene_path: String) -> String:
	var resolved_scene_path := scene_path.strip_edges()
	if resolved_scene_path.is_empty():
		resolved_scene_path = PlayerData.saved_current_scene
	if resolved_scene_path.is_empty():
		resolved_scene_path = "res://scenes/maps/world.tscn"
	if resolved_scene_path == "res://scenes/world.tscn":
		resolved_scene_path = "res://scenes/maps/world.tscn"
	if not resolved_scene_path.begins_with("res://") or not ResourceLoader.exists(
		resolved_scene_path
	):
		return "res://scenes/maps/world.tscn"
	return resolved_scene_path


func create_progress_snapshot() -> Dictionary:
	var character_class := _resolve_checkpoint_character_class()

	var scene_path := _resolve_checkpoint_scene_path(PlayerData.saved_current_scene)
	var save_position: Vector2 = PlayerData.saved_position
	var current_scene := get_tree().current_scene
	var current_scene_path := ""

	if current_scene != null:
		current_scene_path = current_scene.scene_file_path
		if not current_scene_path.is_empty():
			scene_path = _resolve_checkpoint_scene_path(current_scene_path)

	print("SAVE: Current scene path: ", current_scene_path)

	if current_scene_path.contains("/battle/"):
		if BattleData.return_scene.is_empty():
			push_error("SAVE: Battle scene has no recorded return scene.")
			return {}

		scene_path = BattleData.return_scene
		save_position = BattleData.return_position
		PlayerData.saved_max_hp = maxi(
			int(
				_get_property(
					current_scene,
					"player_max_hp",
					PlayerData.saved_max_hp
				)
			),
			1
		)
		PlayerData.saved_hp = clampi(
			int(_get_property(current_scene, "player_hp", PlayerData.saved_hp)),
			0,
			PlayerData.saved_max_hp
		)
		print("SAVE: Using battle return position: ", save_position)
	else:
		var player := _find_player_in_current_scene()
		print("SAVE: Player found: ", player != null)

		if player == null:
			push_error(
				"SAVE: No player found in the current scene; "
				+ "database save was not sent."
			)
			return {}

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
	var playtime_snapshot: Dictionary = Session.get_playtime_snapshot()

	var inventory_value := PlayerData.saved_inventory
	if not (inventory_value is String) or inventory_value.strip_edges().is_empty():
		inventory_value = "[]"

	var equipment_value := PlayerData.saved_equipment
	if not (equipment_value is String) or equipment_value.strip_edges().is_empty():
		equipment_value = "{}"

	var max_hp_value := maxi(PlayerData.current_max_hp, 1)
	var hp_value := clampi(PlayerData.current_hp, 0, max_hp_value)
	var level_value := maxi(Session.level, 1)

	var snapshot := {
		"character_class": character_class,
		"level": level_value,
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
		"playtime_seconds": playtime_snapshot["playtime_seconds"],
		"_unsaved_playtime_msec": playtime_snapshot[
			"unsaved_playtime_msec"
		],
		"hp": hp_value,
		"max_hp": max_hp_value,
		"attack": clampi(int(PlayerData.saved_attack), 0, 2147483647),
		"defense": clampi(int(PlayerData.saved_defense), 0, 2147483647),
		"current_scene": scene_path,
		"boss_completed": PlayerData.saved_boss_completed,
		"inventory": inventory_value,
		"equipment": equipment_value,
		"player_position_x": float(save_position.x),
		"player_position_y": float(save_position.y)
	}

	print("SAVE: Final payload player_position_x = ", snapshot["player_position_x"])
	print("SAVE: Final payload player_position_y = ", snapshot["player_position_y"])
	return snapshot


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
	payload["auth_token"] = Session.auth_token

	if request_pending or not queued_payloads.is_empty():
		var queued_copy := payload.duplicate(true)
		var action := str(payload.get("action", ""))

		if action == "save_progress" and not queued_payloads.is_empty():
			var last_index := queued_payloads.size() - 1
			if str(queued_payloads[last_index].get("action", "")) == action:
				queued_payloads[last_index] = queued_copy
				return true

		queued_payloads.append(queued_copy)
		return true

	return _start_request(payload)


func _start_request(payload: Dictionary) -> bool:
	var request_payload := payload.duplicate(true)
	current_playtime_seconds = int(
		request_payload.get("playtime_seconds", 0)
	)
	current_playtime_elapsed_msec = int(
		request_payload.get("_unsaved_playtime_msec", 0)
	)
	request_payload.erase("_unsaved_playtime_msec")

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	current_request_action = str(payload.get("action", ""))
	current_request_checkpoint = {}
	current_request_user_id = int(payload.get("user_id", -1))
	if current_request_action == "save_checkpoint":
		var checkpoint: Variant = payload.get("checkpoint", {})
		if checkpoint is Dictionary:
			current_request_checkpoint = checkpoint.duplicate(true)
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
		JSON.stringify(request_payload)
	)

	if error != OK:
		request_pending = false
		print(
			"HTTP REQUEST FAILED TO START: action=",
			current_request_action,
			" error=",
			error
		)

		var failed_action := current_request_action
		if failed_action == "save_progress":
			push_error(
				"Progress save request could not start. Error: "
				+ str(error)
			)
		current_request_action = ""
		current_request_checkpoint.clear()
		current_request_user_id = -1
		response_received.emit(
			false,
			"Could not send the game-data request.",
			{"action": failed_action}
		)

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
		if completed_action == "save_progress":
			push_error("Progress save failed: cannot reach the server.")
		response_received.emit(
			false,
			"Cannot reach the server.",
			{"action": completed_action}
		)
		current_request_checkpoint.clear()
		current_request_user_id = -1
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
		if completed_action == "save_progress":
			push_error("Progress save failed: invalid server response.")

		response_received.emit(
			false,
			"Invalid server response.",
			{"action": completed_action}
		)
		current_request_checkpoint.clear()
		current_request_user_id = -1
		current_playtime_seconds = 0
		current_playtime_elapsed_msec = 0
		_send_queued_request()
		return

	var data: Dictionary = json.data
	data["action"] = completed_action

	var success := bool(data.get("success", false))
	var message := str(data.get("message", "Unknown response."))

	if response_code < 200 or response_code >= 300:
		success = false
	if not success and completed_action == "save_progress":
		push_error("Progress save failed: " + message)

	if success and completed_action == "save_progress":
		Session.confirm_playtime_saved(
			current_playtime_seconds,
			current_playtime_elapsed_msec
		)
	elif success and completed_action == "save_checkpoint":
		if not Session.accept_checkpoint(
			current_request_checkpoint,
			current_request_user_id
		):
			push_error(
				"Server saved a checkpoint that failed local validation."
			)

	current_request_checkpoint.clear()
	current_request_user_id = -1

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

	current_playtime_seconds = 0
	current_playtime_elapsed_msec = 0
	response_received.emit(success, message, data)

	_send_queued_request()


func _send_queued_request() -> void:
	if request_pending or queued_payloads.is_empty():
		return

	var payload: Dictionary = queued_payloads.pop_front()

	if str(payload.get("action", "")) == "save_progress":
		var playtime_snapshot := Session.get_playtime_snapshot()
		payload["playtime_seconds"] = playtime_snapshot[
			"playtime_seconds"
		]
		payload["_unsaved_playtime_msec"] = playtime_snapshot[
			"unsaved_playtime_msec"
		]

	_start_request(payload)

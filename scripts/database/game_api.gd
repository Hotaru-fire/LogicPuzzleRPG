extends Node

signal response_received(success: bool, message: String, data: Dictionary)

const API_URL := "http://127.0.0.1/rpg_api/game_data.php"

var http_request: HTTPRequest
var request_pending := false
var queued_payload: Dictionary = {}
var current_request_action := ""


func _ready() -> void:
	http_request = HTTPRequest.new()
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

	if current_scene != null:
		scene_path = current_scene.scene_file_path

	if scene_path.contains("/battle/") and not BattleData.return_scene.is_empty():
		scene_path = BattleData.return_scene

		if BattleData.return_position != Vector2.ZERO:
			save_position = BattleData.return_position
	else:
		var player := _find_player_in_current_scene()

		if player != null:
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

	PlayerData.saved_position = save_position
	PlayerData.saved_current_scene = scene_path

	return _send_request({
		"action": "save_progress",
		"character_class": character_class,
		"level": Session.level,
		"exp": Session.player_exp,
		"gold": Session.gold,
		"score": Session.score,
		"mobs_defeated": Session.mobs_defeated,
		"dungeon_enemies_defeated": Session.dungeon_enemies_defeated,
		"bosses_killed": Session.bosses_killed,
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
	})


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

	var error := http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		request_pending = false

		response_received.emit(
			false,
			"Could not send the game-data request.",
			{"action": current_request_action}
		)

		current_request_action = ""
		_send_queued_request()
		return false

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

	if result != HTTPRequest.RESULT_SUCCESS:
		response_received.emit(
			false,
			"Cannot reach the server.",
			{"action": completed_action}
		)
		_send_queued_request()
		return

	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK or not (json.data is Dictionary):
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

	response_received.emit(success, message, data)

	_send_queued_request()


func _send_queued_request() -> void:
	if queued_payload.is_empty():
		return

	var payload := queued_payload.duplicate(true)
	queued_payload.clear()

	_start_request(payload)

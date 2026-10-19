
extends Node

signal response_received(success: bool, message: String, data: Dictionary)

const API_URL := "http://127.0.0.1/rpg_api/game_data.php"

var http_request: HTTPRequest
var request_pending := false


func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)


func save_character(character_class: String):
	return _send_request({
		"action": "save_character",
		"character_class": character_class
	})


func load_save():
	return _send_request({
		"action": "load_save"
	})


func save_progress():
	return _send_request({
		"action": "save_progress",
		"level": Session.level,
		"exp": Session.exp,
		"gold": Session.gold,
		"score": Session.score,
		"mobs_defeated": Session.mobs_defeated
	})


func record_score(final_score: int):
	return _send_request({
		"action": "record_score",
		"score": final_score
	})


func _send_request(payload: Dictionary) -> bool:
	if not Session.is_logged_in():
		push_warning("Cannot access game data: no user is logged in.")
		return false

	if request_pending:
		push_warning("A game-data request is already in progress.")
		return false

	payload["user_id"] = Session.user_id

	var headers = PackedStringArray([
		"Content-Type: application/json"
	])

	request_pending = true

	var error = http_request.request(
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
			{}
		)
		return false

	return true


func _on_request_completed(result, response_code, _headers, body):
	request_pending = false

	if result != HTTPRequest.RESULT_SUCCESS:
		response_received.emit(false, "Cannot reach the server.", {})
		return

	var json = JSON.new()
	var parse_error = json.parse(body.get_string_from_utf8())

	if parse_error != OK or not (json.data is Dictionary):
		response_received.emit(false, "Invalid server response.", {})
		return

	var data: Dictionary = json.data
	var success = bool(data.get("success", false))
	var message = str(data.get("message", "Unknown response."))

	if response_code < 200 or response_code >= 300:
		success = false

	response_received.emit(success, message, data)

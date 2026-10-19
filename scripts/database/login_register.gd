
extends Control

var is_register_mode := false
const API_URL := "http://127.0.0.1/rpg_api/auth.php"
const WORLD_SCENE := "res://scenes/main/MainMenu.tscn"
	
var request_pending := false
var logged_in_user_id: int = -1
var logged_in_username := ""

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var title_label: Label = $CenterContainer/PanelContainer/VBoxContainer/TitleLabel
@onready var username_input: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/UsernameInput
@onready var password_input: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/PasswordInput
@onready var confirm_password_input: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/ConfirmPasswordInput
@onready var message_label: Label = $CenterContainer/PanelContainer/VBoxContainer/MessageLabel
@onready var submit_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SubmitButton
@onready var switch_mode_button: Button = $CenterContainer/PanelContainer/VBoxContainer/SwitchModeButton


func _ready():
	submit_button.pressed.connect(_on_submit_pressed)
	switch_mode_button.pressed.connect(_on_switch_mode_pressed)
	http_request.request_completed.connect(_on_request_completed)

	is_register_mode = false
	clear_inputs()
	update_form()


func update_form():
	confirm_password_input.visible = is_register_mode
	message_label.text = ""

	if is_register_mode:
		title_label.text = "CREATE ACCOUNT"
		submit_button.text = "Register"
		switch_mode_button.text = "Already have an account? Login"
	else:
		title_label.text = "WELCOME, ADVENTURER"
		submit_button.text = "Login"
		switch_mode_button.text = "Create an account"


func _on_switch_mode_pressed():
	is_register_mode = not is_register_mode
	clear_inputs()
	update_form()


func _on_submit_pressed():
	if request_pending:
		return

	var username = username_input.text.strip_edges()
	var password = password_input.text

	if username.is_empty() or password.is_empty():
		message_label.text = "Enter your username and password."
		return

	var action = "login"

	if is_register_mode:
		action = "register"

		if password != confirm_password_input.text:
			message_label.text = "Passwords do not match."
			return

		if password.length() < 8:
			message_label.text = "Password must be at least 8 characters."
			return

	var payload = {
		"action": action,
		"username": username,
		"password": password
	}

	var headers = PackedStringArray([
		"Content-Type: application/json"
	])

	request_pending = true
	submit_button.disabled = true
	switch_mode_button.disabled = true
	message_label.text = "Connecting to server..."
	print("API URL: ", API_URL)
	print("Action: ", action)

	var error = http_request.request(
		API_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error != OK:
		request_pending = false
		submit_button.disabled = false
		switch_mode_button.disabled = false
		message_label.text = "Could not send request. Check the API URL."




func _on_request_completed(result, response_code, _headers, body):
	request_pending = false
	submit_button.disabled = false
	switch_mode_button.disabled = false

	var raw_response = body.get_string_from_utf8()

	print("HTTP request result: ", result)
	print("HTTP status code: ", response_code)
	print("Raw server response: ", raw_response)

	if result != HTTPRequest.RESULT_SUCCESS:
		message_label.text = "Cannot reach server. Check XAMPP."
		return

	var json = JSON.new()
	var parse_error = json.parse(raw_response)

	if parse_error != OK:
		message_label.text = "Server returned invalid JSON. Check Output."
		print("JSON error: ", json.get_error_message())
		print("Error line: ", json.get_error_line())
		return

	var response = json.data

	if not (response is Dictionary):
		message_label.text = "Unexpected server response."
		return

	if response_code < 200 or response_code >= 300:
		message_label.text = str(
			response.get("message", "Server error.")
		)
		return

	message_label.text = str(
		response.get("message", "Unknown response.")
	)

	
	if response.get("success", false):
		if not is_register_mode:
			# Store the logged-in user's information
			Session.user_id = int(response.get("user_id", -1))
			Session.username = str(response.get("username", ""))

			print("Logged in user ID: ", Session.user_id)
			print("Logged in username: ", Session.username)

			# Change to the world scene after successful login
			if Session.user_id > 0:
				get_tree().change_scene_to_file(WORLD_SCENE)
			else:
				message_label.text = "Login response did not contain a valid user ID."
		else:
			# Registration succeeded; return to login mode
			is_register_mode = false
			clear_inputs()
			update_form()
			message_label.text = "Account created! You can now log in."



func clear_inputs():
	username_input.clear()
	password_input.clear()
	confirm_password_input.clear()
	message_label.text = ""

extends Control

@onready var menu_buttons = $MenuButtons
@onready var play_panel = $PlayPanel
@onready var settings_panel = $SettingsPanel
@onready var title = $Title
@onready var warning_label = $PlayPanel/WarningLbl

# Confirmation panel
@onready var confirmation_panel: PanelContainer = $ConfirmationPanel
@onready var confirmation_message: Label = $ConfirmationPanel/VBoxContainer/MessageLabel
@onready var continue_button: Button = $ConfirmationPanel/VBoxContainer/ButtonContainer/ContinueButton
@onready var cancel_button: Button = $ConfirmationPanel/VBoxContainer/ButtonContainer/CancelButton

var selected_character: int = 0

var waiting_for_new_game_flow: bool = false
var confirmation_received: bool = false
var existing_save_found: bool = false
var new_game_stage: String = ""


func _ready() -> void:
	play_panel.hide()
	settings_panel.hide()
	confirmation_panel.hide()
	warning_label.hide()

	if not continue_button.pressed.is_connected(_on_delete_save_confirmation_confirmed):
		continue_button.pressed.connect(_on_delete_save_confirmation_confirmed)

	if not cancel_button.pressed.is_connected(_on_delete_save_confirmation_canceled):
		cancel_button.pressed.connect(_on_delete_save_confirmation_canceled)

	if not GameAPI.response_received.is_connected(_on_game_api_response_received):
		GameAPI.response_received.connect(_on_game_api_response_received)


# --------------------------------------------------
# CHARACTER NAMES
# --------------------------------------------------

func get_character_name(character_id: int) -> String:
	match character_id:
		1:
			return "Knight"
		2:
			return "Mage"
		3:
			return "Thief"
		4:
			return "Archer"
		_:
			return ""


# --------------------------------------------------
# MAIN MENU NAVIGATION
# --------------------------------------------------

func _on_play_button_pressed() -> void:
	if waiting_for_new_game_flow:
		return

	warning_label.hide()

	# Check the database before opening character selection.
	if Session.is_logged_in():
		waiting_for_new_game_flow = true
		new_game_stage = "checking_save"

		print("Checking for existing save data...")

		if not GameAPI.check_save():
			waiting_for_new_game_flow = false
			new_game_stage = ""
			print("Could not start save check.")
			return

		return

	# Offline: open character selection directly.
	_open_character_selection()


func _on_settings_button_pressed() -> void:
	if waiting_for_new_game_flow:
		return

	menu_buttons.hide()
	play_panel.hide()
	settings_panel.show()
	title.hide()


func _on_back_button_pressed() -> void:
	_return_to_main_menu()


func _on_button_pressed() -> void:
	_return_to_main_menu()


func _on_settings_back_button_pressed() -> void:
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	if waiting_for_new_game_flow:
		return

	confirmation_panel.hide()
	play_panel.hide()
	settings_panel.hide()
	menu_buttons.show()
	title.show()
	warning_label.hide()


func _open_character_selection() -> void:
	confirmation_panel.hide()
	menu_buttons.hide()
	settings_panel.hide()
	play_panel.show()
	title.hide()
	warning_label.hide()


# --------------------------------------------------
# CHARACTER SELECTION BUTTONS
# --------------------------------------------------

func _on_character_1_pressed() -> void:
	selected_character = 1
	print("Selected Knight")
	print("Character value is now: ", selected_character)


func _on_character_2_pressed() -> void:
	selected_character = 2
	print("Selected Mage")
	print("Character value is now: ", selected_character)


func _on_character_3_pressed() -> void:
	selected_character = 3
	print("Selected Thief")
	print("Character value is now: ", selected_character)


func _on_character_4_pressed() -> void:
	selected_character = 4
	print("Selected Archer")
	print("Character value is now: ", selected_character)


# --------------------------------------------------
# START NEW GAME
# --------------------------------------------------

func _on_start_button_pressed() -> void:
	if selected_character == 0:
		warning_label.text = "Please select a character!"
		warning_label.show()
		return

	if waiting_for_new_game_flow:
		return

	warning_label.hide()

	PlayerData.player_name = Session.username
	PlayerData.selected_character = selected_character
	Session.selected_character = get_character_name(selected_character)

	# Reset old local save data in memory.
	PlayerData.has_save_data = false
	PlayerData.saved_position = Vector2.ZERO
	PlayerData.saved_hp = 0
	PlayerData.saved_mana = 0

	# Delete the old local save file.
	if FileAccess.file_exists("user://savegame.json"):
		var absolute_path = ProjectSettings.globalize_path(
			"user://savegame.json"
		)
		var delete_error = DirAccess.remove_absolute(absolute_path)

		if delete_error == OK:
			print("OLD LOCAL SAVE FILE DELETED")
		else:
			print("FAILED TO DELETE OLD LOCAL SAVE FILE: ", delete_error)

	# Save the selected character to the database.
	if Session.is_logged_in():
		waiting_for_new_game_flow = true
		new_game_stage = "saving_character"

		print("Saving character to database: ", Session.selected_character)

		if not GameAPI.save_character(Session.selected_character):
			waiting_for_new_game_flow = false
			new_game_stage = ""
			warning_label.text = "Could not save your character. Please try again."
			warning_label.show()

		return

	# Offline: launch immediately.
	_launch_new_game()


func _launch_new_game() -> void:
	print("NEW GAME STARTED")
	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)

	waiting_for_new_game_flow = false
	new_game_stage = ""
	confirmation_received = false
	existing_save_found = false
	confirmation_panel.hide()

	get_tree().change_scene_to_file(
		"res://scenes/maps/world.tscn"
	)


# --------------------------------------------------
# CONFIRMATION PANEL
# --------------------------------------------------


func _show_confirmation_panel() -> void:
	confirmation_message.text = (
		"An existing save was found.\n\n"
		+ "Starting a new game will delete your previous save.\n\n"
		+ "Do you want to continue?"
	)

	confirmation_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_message.visible = true

	continue_button.text = "Continue"
	cancel_button.text = "Cancel"

	# Preserve the position and layout you set in the Godot editor.
	menu_buttons.show()
	title.show()
	play_panel.hide()
	settings_panel.hide()

	confirmation_panel.show()
	confirmation_panel.move_to_front()

	print("Confirmation panel displayed.")
	print("Message text: ", confirmation_message.text)
	print("Message visible: ", confirmation_message.is_visible_in_tree())
	print("Message size: ", confirmation_message.size)
	print("Panel position: ", confirmation_panel.position)
	print("Panel size: ", confirmation_panel.size)



func _on_delete_save_confirmation_confirmed() -> void:
	if not waiting_for_new_game_flow:
		return

	if new_game_stage != "confirming_save":
		return

	confirmation_panel.hide()
	confirmation_received = true
	new_game_stage = "deleting_save"

	print("Deleting previous database save...")

	if not GameAPI.delete_save():
		waiting_for_new_game_flow = false
		confirmation_received = false
		new_game_stage = ""
		print("Could not start database save deletion.")


func _on_delete_save_confirmation_canceled() -> void:
	confirmation_panel.hide()

	waiting_for_new_game_flow = false
	confirmation_received = false
	existing_save_found = false
	new_game_stage = ""

	# Return to the original main menu.
	play_panel.hide()
	settings_panel.hide()
	menu_buttons.show()
	title.show()
	warning_label.hide()

	print("Canceled new game. Returned to main menu.")


# --------------------------------------------------
# DATABASE RESPONSES
# --------------------------------------------------

func _on_game_api_response_received(
	success: bool,
	message: String,
	data: Dictionary
) -> void:
	var action: String = str(data.get("action", ""))

	print("GameAPI response: ", action, " | ", success, " | ", message)

	if not waiting_for_new_game_flow:
		return

	match action:
		"check_save":
			if new_game_stage != "checking_save":
				return

			if not success:
				waiting_for_new_game_flow = false
				new_game_stage = ""
				print("Failed to check existing save: ", message)
				return

			existing_save_found = bool(data.get("has_save", false))

			if existing_save_found:
				new_game_stage = "confirming_save"
				_show_confirmation_panel()
			else:
				# No database save exists; proceed to character selection.
				waiting_for_new_game_flow = false
				new_game_stage = ""
				_open_character_selection()

			return

		"delete_save":
			if new_game_stage != "deleting_save":
				return

			if not success:
				waiting_for_new_game_flow = false
				confirmation_received = false
				new_game_stage = ""
				print("Failed to delete old database save: ", message)
				return

			print("Previous database save deleted successfully.")

			existing_save_found = false
			confirmation_received = false
			waiting_for_new_game_flow = false
			new_game_stage = ""

			# Select a character before creating the new save.
			_open_character_selection()
			return

		"save_character":
			if new_game_stage != "saving_character":
				return

			if not success:
				waiting_for_new_game_flow = false
				new_game_stage = ""
				warning_label.text = "Could not save your character. Please try again."
				warning_label.show()
				return

			print("Character saved successfully.")
			_launch_new_game()
			return


# --------------------------------------------------
# LOAD GAME — PRESERVED FROM YOUR ORIGINAL CODE
# --------------------------------------------------

func _on_loadgame_button_pressed() -> void:
	# Check whether the local save file exists.
	if not FileAccess.file_exists("user://savegame.json"):
		print("NO SAVE FILE FOUND")
		return

	# Open the local save file.
	var file = FileAccess.open(
		"user://savegame.json",
		FileAccess.READ
	)

	if file == null:
		print("FAILED TO OPEN SAVE FILE")
		return

	# Read JSON data.
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()

	if save_data == null or not (save_data is Dictionary):
		print("FAILED TO READ SAVE DATA")
		return

	print("SAVE DATA LOADED: ", save_data)

	# Load player name.
	PlayerData.player_name = Session.username

	# Load character.
	PlayerData.selected_character = int(
		save_data.get("character", 0)
	)

	Session.selected_character = get_character_name(
		PlayerData.selected_character
	)

	# Load player position.
	PlayerData.saved_position = Vector2(
		float(save_data.get("player_position_x", 0.0)),
		float(save_data.get("player_position_y", 0.0))
	)

	# Load HP and mana.
	PlayerData.saved_hp = int(save_data.get("hp", 0))
	PlayerData.saved_mana = int(save_data.get("mana", 0))

	# Tell the Player script to apply the saved data.
	PlayerData.has_save_data = true

	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)
	print("Position: ", PlayerData.saved_position)
	print("HP: ", PlayerData.saved_hp)
	print("Mana: ", PlayerData.saved_mana)

	# Load the saved scene.
	var saved_scene = str(
		save_data.get("scene", "res://scenes/maps/world.tscn")
	)

	if not ResourceLoader.exists(saved_scene):
		print("SAVED SCENE DOES NOT EXIST: ", saved_scene)
		return

	print("Loading Scene: ", saved_scene)
	get_tree().change_scene_to_file(saved_scene)


# Support either existing Quit button signal name.
func _on_save_quit_button_pressed() -> void:
	get_tree().quit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()

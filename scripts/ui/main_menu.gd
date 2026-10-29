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

	# Reset old saved player data.
	PlayerData.has_save_data = false
	PlayerData.saved_position = Vector2.ZERO
	PlayerData.saved_hp = 0
	PlayerData.reset_health()
	PlayerData.saved_mana = 0
	PlayerData.saved_current_scene = "res://scenes/maps/world.tscn"
	PlayerData.saved_boss_completed = false
	PlayerData.saved_inventory = "[]"
	PlayerData.saved_equipment = "{}"

	# Reset progress and analytics for the new game.
	Session.reset_game_progress()

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
	Session.start_gameplay_time()

	waiting_for_new_game_flow = false
	new_game_stage = ""
	confirmation_received = false
	existing_save_found = false
	confirmation_panel.hide()

	var error := get_tree().change_scene_to_file(
		"res://scenes/maps/world.tscn"
	)
	if error != OK:
		Session.stop_gameplay_time()
		push_error("Failed to start a new game. Error: " + str(error))


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

		"load_save":
			if new_game_stage != "loading_save":
				return

			waiting_for_new_game_flow = false
			new_game_stage = ""

			if not success:
				print("Failed to load database save: ", message)
				return

			if not bool(data.get("has_save", false)):
				print("No database save found for this account.")
				return

			if (
				not data.has("player_position_x")
				or not data.has("player_position_y")
			):
				push_error("Loaded save response is missing player coordinates.")
				return

			# Restore analytics.
			Session.load_analytics(data)

			# Restore character selection.
			Session.selected_character = str(
				data.get("character_class", "")
			)

			PlayerData.selected_character = match_character_id(
				Session.selected_character
			)
			PlayerData.player_name = Session.username

			# Restore player position and scene.
			print(
				"LOAD: Response position fields: x=",
				data.get("player_position_x", "missing"),
				" y=",
				data.get("player_position_y", "missing")
			)
			PlayerData.saved_position = Vector2(
				float(data.get("player_position_x", 0.0)),
				float(data.get("player_position_y", 0.0))
			)
			print("LOAD: PlayerData.saved_position: ", PlayerData.saved_position)

			PlayerData.saved_current_scene = str(
				data.get(
					"current_scene",
					"res://scenes/maps/world.tscn"
				)
			)

			# Restore health and combat stats.
			PlayerData.saved_hp = int(data.get("hp", 200))
			PlayerData.saved_max_hp = int(data.get("max_hp", 200))
			PlayerData.set_health(
				PlayerData.saved_hp,
				PlayerData.saved_max_hp
			)
			PlayerData.saved_attack = int(data.get("attack", 30))
			PlayerData.saved_defense = int(data.get("defense", 10))

			# Restore inventory and equipment.
			PlayerData.saved_inventory = str(
				data.get("inventory", "[]")
			)
			PlayerData.saved_equipment = str(
				data.get("equipment", "{}")
			)

			# Restore boss completion.
			PlayerData.saved_boss_completed = bool(
				data.get("boss_completed", false)
			)

			# Restore session progress.
			Session.level = clampi(
				int(data.get("level", 1)),
				1,
				Session.MAX_COUNTER
			)
			Session.player_exp = clampi(
				int(data.get("exp", 0)),
				0,
				Session.MAX_SAVED_INT
			)
			Session.gold = clampi(
				int(data.get("gold", 0)),
				0,
				Session.MAX_SAVED_INT
			)
			Session.score = clampi(
				int(data.get("score", 0)),
				0,
				Session.MAX_SAVED_INT
			)
			Session.mobs_defeated = clampi(
				int(data.get("mobs_defeated", 0)),
				0,
				Session.MAX_COUNTER
			)
			Session.dungeon_enemies_defeated = clampi(
				int(data.get("dungeon_enemies_defeated", 0)),
				0,
				Session.MAX_SIGNED_COUNTER
			)
			Session.bosses_killed = clampi(
				int(data.get("bosses_killed", 0)),
				0,
				Session.MAX_SIGNED_COUNTER
			)

			# Tell the player script to apply the saved data.
			PlayerData.has_save_data = true

			# Validate the saved scene before loading it.
			
			var saved_scene: String = PlayerData.saved_current_scene

			# Fix the old saved world scene path.
			if saved_scene == "res://scenes/world.tscn":
				saved_scene = "res://scenes/maps/world.tscn"
				PlayerData.saved_current_scene = saved_scene

			if not ResourceLoader.exists(saved_scene):
				PlayerData.has_save_data = false
				print("Saved scene does not exist: ", saved_scene)
				return

			Session.start_gameplay_time()


			print("Database save loaded successfully.")
			print("Character: ", Session.selected_character)
			print("Level: ", Session.level)
			print("Saved scene: ", saved_scene)
			print("Saved position: ", PlayerData.saved_position)
			print("Player HP: ", PlayerData.saved_hp)
			print("Total deaths: ", Session.total_deaths)
			print("Puzzles cleared: ", Session.puzzles_cleared)

			# A database load must not be overridden by a previous battle's return state.
			BattleData.return_scene = ""
			BattleData.return_position = Vector2.ZERO

			var error: Error = get_tree().change_scene_to_file(
				saved_scene
			)

			if error != OK:
				PlayerData.has_save_data = false
				Session.stop_gameplay_time()
				print("Failed to change to saved scene. Error: ", error)

			return


# LOAD GAME 
func _on_loadgame_button_pressed() -> void:
	if not Session.is_logged_in():
		print("Please log in to load your account save.")
		return

	if waiting_for_new_game_flow:
		return

	waiting_for_new_game_flow = true
	new_game_stage = "loading_save"

	print("Loading save from database...")

	if not GameAPI.load_save():
		waiting_for_new_game_flow = false
		new_game_stage = ""
		print("Could not start database load request.")


# Support either existing Quit button signal name.
func _on_save_quit_button_pressed() -> void:
	get_tree().quit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func match_character_id(character_name: String) -> int:
	match character_name:
		"Knight":
			return 1
		"Mage":
			return 2
		"Thief":
			return 3
		"Archer":
			return 4
		_:
			return 0


func _on_leader_board_button_pressed() -> void:
	print("LEADERBOARDS BUTTON CLICKED!")

	var error = get_tree().change_scene_to_file(
		"res://scenes/main/leaderboards.tscn"
	)

	if error != OK:
		push_error("Failed to open Leaderboards. Error: " + str(error))

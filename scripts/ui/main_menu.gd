extends Control

@onready var menu_buttons = $MenuButtons
@onready var play_panel = $PlayPanel
@onready var settings_panel = $SettingsPanel
@onready var title = $Title
@onready var warning_label = $PlayPanel/WarningLbl

var selected_character = 0


func _ready():
	play_panel.hide()
	settings_panel.hide()


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


func _on_play_button_pressed():
	menu_buttons.hide()
	play_panel.show()
	title.hide()


func _on_settings_button_pressed():
	menu_buttons.hide()
	settings_panel.show()


func _on_character_1_pressed():
	selected_character = 1
	print("Selected Knight")
	print("Character value is now: ", selected_character)


func _on_character_2_pressed():
	selected_character = 2
	print("Selected Mage")
	print("Character value is now: ", selected_character)


func _on_character_3_pressed():
	selected_character = 3
	print("Selected Rogue")
	print("Character value is now: ", selected_character)


func _on_character_4_pressed():
	selected_character = 4
	print("Selected Archer")
	print("Character value is now: ", selected_character)


func _on_start_button_pressed():

	# Check if player selected a character
	if selected_character == 0:
		warning_label.text = "Please select a character!"
		warning_label.show()
		return

	warning_label.hide()

	# Save the logged-in username
	PlayerData.player_name = Session.username

	# Save selected character
	PlayerData.selected_character = selected_character
	Session.selected_character = get_character_name(selected_character)

	# Save character to database
	if Session.is_logged_in():
		GameAPI.save_character(Session.selected_character)
		print("Saving character to database: ",
			Session.selected_character)
	else:
		print("No logged-in account.")

	# Clear old save data in memory
	PlayerData.has_save_data = false
	PlayerData.saved_position = Vector2.ZERO
	PlayerData.saved_hp = 0
	PlayerData.saved_mana = 0

	# Delete previous local save file
	if FileAccess.file_exists("user://savegame.json"):
		var absolute_path = ProjectSettings.globalize_path(
			"user://savegame.json"
		)
		var delete_error = DirAccess.remove_absolute(absolute_path)

		if delete_error == OK:
			print("OLD SAVE FILE DELETED")
		else:
			print("FAILED TO DELETE OLD SAVE FILE: ", delete_error)

	print("NEW GAME STARTED")
	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)

	# Start the game
	get_tree().change_scene_to_file(
		"res://scenes/maps/world.tscn"
	)


func _on_back_button_pressed():
	play_panel.hide()
	settings_panel.hide()
	menu_buttons.show()


func _on_button_pressed() -> void:
	play_panel.hide()
	menu_buttons.show()
	title.show()


func _on_save_quit_button_pressed() -> void:
	get_tree().quit()


func _on_loadgame_button_pressed():

	# Check if a save file exists
	if not FileAccess.file_exists("user://savegame.json"):
		print("NO SAVE FILE FOUND")
		return

	# Open save file
	var file = FileAccess.open(
		"user://savegame.json",
		FileAccess.READ
	)

	if file == null:
		print("FAILED TO OPEN SAVE FILE")
		return

	# Read JSON data
	var save_data = JSON.parse_string(file.get_as_text())
	file.close()

	if save_data == null or not (save_data is Dictionary):
		print("FAILED TO READ SAVE DATA")
		return

	print("SAVE DATA LOADED: ", save_data)

	# Load player name from the logged-in account
	PlayerData.player_name = Session.username

	# Load character
	PlayerData.selected_character = int(
		save_data.get("character", 0)
	)

	Session.selected_character = get_character_name(
		PlayerData.selected_character
	)

	# Load player position
	PlayerData.saved_position = Vector2(
		float(save_data.get("player_position_x", 0.0)),
		float(save_data.get("player_position_y", 0.0))
	)

	# Load HP and mana
	PlayerData.saved_hp = int(save_data.get("hp", 0))
	PlayerData.saved_mana = int(save_data.get("mana", 0))

	# Tell Player script to apply saved data
	PlayerData.has_save_data = true

	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)
	print("Position: ", PlayerData.saved_position)
	print("HP: ", PlayerData.saved_hp)
	print("Mana: ", PlayerData.saved_mana)

	# Load saved scene
	var saved_scene = str(
		save_data.get("scene", "res://scenes/maps/world.tscn")
	)

	print("Loading Scene: ", saved_scene)
	get_tree().change_scene_to_file(saved_scene)

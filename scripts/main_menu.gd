extends Control

@onready var menu_buttons = $MenuButtons
@onready var play_panel = $PlayPanel
@onready var settings_panel = $SettingsPanel
@onready var player_name_input = $PlayPanel/PlayerNameInput
@onready var title = $Title
@onready var warning_label = $PlayPanel/WarningLbl

var selected_character = 0


func _ready():
	play_panel.hide()
	settings_panel.hide()


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
	var player_name = player_name_input.text.strip_edges()

	# Check if player entered a name
	if player_name == "":
		warning_label.text = "Please enter your player name!"
		warning_label.show()
		return

	# Check if player selected a character
	if selected_character == 0:
		warning_label.text = "Please select a character!"
		warning_label.show()
		return

	warning_label.hide()

	# -------------------------
	# START A NEW GAME
	# -------------------------

	# Save the new player's information
	PlayerData.player_name = player_name
	PlayerData.selected_character = selected_character

	# Clear old save data from memory
	PlayerData.has_save_data = false
	PlayerData.saved_position = Vector2.ZERO
	PlayerData.saved_hp = 0
	PlayerData.saved_mana = 0

	# Delete the previous save file
	if FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute("user://savegame.json")
		print("OLD SAVE FILE DELETED")

	print("NEW GAME STARTED")
	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)

	# Start the game from the beginning
	get_tree().change_scene_to_file("res://scenes/maps/world.tscn")


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
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)

	if file == null:
		print("FAILED TO OPEN SAVE FILE")
		return

	# Read JSON data
	var save_data = JSON.parse_string(file.get_as_text())

	if save_data == null:
		print("FAILED TO READ SAVE DATA")
		return

	print("SAVE DATA LOADED: ", save_data)

	# -------------------------
	# LOAD PLAYER NAME
	# -------------------------

	PlayerData.player_name = str(save_data["player_name"])

	# -------------------------
	# LOAD CHARACTER
	# -------------------------

	PlayerData.selected_character = int(save_data["character"])

	# -------------------------
	# LOAD PLAYER POSITION
	# -------------------------

	PlayerData.saved_position = Vector2(
		save_data["player_position_x"],
		save_data["player_position_y"]
	)

	# -------------------------
	# LOAD HP
	# -------------------------

	PlayerData.saved_hp = int(save_data["hp"])

	# -------------------------
	# LOAD MANA
	# -------------------------

	PlayerData.saved_mana = int(save_data["mana"])

	# Tell the Player script that saved data should be applied
	PlayerData.has_save_data = true

	# -------------------------
	# PRINT LOADED DATA
	# -------------------------

	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)
	print("Position: ", PlayerData.saved_position)
	print("HP: ", PlayerData.saved_hp)
	print("Mana: ", PlayerData.saved_mana)

	# -------------------------
	# LOAD SAVED SCENE
	# -------------------------

	var saved_scene = str(save_data["scene"])

	print("Loading Scene: ", saved_scene)

	get_tree().change_scene_to_file(saved_scene)

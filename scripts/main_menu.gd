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


func _on_quit_button_pressed():
	get_tree().quit()


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

	if player_name == "":
		warning_label.text = "Please enter your player name!"
		warning_label.show()
		return

	if selected_character == 0:
		warning_label.text = "Please select a character!"
		warning_label.show()
		return

	warning_label.hide()

	# Save the player's information
	PlayerData.player_name = player_name
	PlayerData.selected_character = selected_character

	print("Player Name: ", PlayerData.player_name)
	print("Character: ", PlayerData.selected_character)

	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _on_back_button_pressed():
	play_panel.hide()
	settings_panel.hide()
	menu_buttons.show()


func _on_button_pressed() -> void:
	play_panel.hide()
	menu_buttons.show()
	title.show()

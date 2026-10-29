extends Control

func _input(event):
	if event.is_action_pressed("pause_game"):
		get_tree().paused = !get_tree().paused
		visible = get_tree().paused

func save_game():
	print("SAVE FUNCTION STARTED")
	print("CURRENT SCENE: ", get_tree().current_scene.name)
	print("CURRENT SCENE PATH: ", get_tree().current_scene.scene_file_path)

	var player = get_tree().current_scene.get_node("player")
	
	print("PLAYER FOUND: ", player)

	var save_data = {
		"player_position_x": player.position.x,
		"player_position_y": player.position.y,
		"hp": player.hp,
		"mana": player.mana,
		"character": PlayerData.selected_character,
		"scene": get_tree().current_scene.scene_file_path,
		"player_name": PlayerData.player_name,
	}

	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)

	if file == null:
		return

	file.store_string(JSON.stringify(save_data))

	print("SAVE FILE CREATED")
	print("SAVE DATA: ", save_data)

func _on_save_quit_button_pressed():
	save_game()

	if Session.is_logged_in():
		if GameAPI.save_progress():
			var response: Array = await GameAPI.response_received
			while str(response[2].get("action", "")) != "save_progress":
				response = await GameAPI.response_received

			if bool(response[0]):
				print("DATABASE SAVE COMPLETED: ", response[1])
			else:
				push_error("DATABASE SAVE FAILED: " + str(response[1]))
		else:
			push_error("DATABASE SAVE COULD NOT BE STARTED.")

	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _on_resume_button_pressed() -> void:
	pass # Replace with function body.

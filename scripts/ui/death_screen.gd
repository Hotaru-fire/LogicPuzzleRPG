extends Control

const MAIN_MENU_SCENE := "res://scenes/main/MainMenu.tscn"

@onready var respawn_button: Button = $CenterContainer/ConfirmationPanel/VBoxContainer/RespawnButton
@onready var quit_button: Button = $CenterContainer/ConfirmationPanel/VBoxContainer/QuitButton
@onready var checkpoint_label: Label = $CenterContainer/ConfirmationPanel/VBoxContainer/CheckpointLabel

var _transition_in_progress := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	respawn_button.pressed.connect(_on_respawn_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)


func _on_respawn_button_pressed() -> void:
	if _transition_in_progress:
		return

	_transition_in_progress = true
	_set_buttons_disabled(true)
	checkpoint_label.text = "Loading latest checkpoint..."

	var checkpoint := await _load_checkpoint()
	if checkpoint.is_empty():
		checkpoint_label.text = (
			"No valid checkpoint is available. You can quit to the main menu."
		)
		_transition_in_progress = false
		_set_buttons_disabled(false)
		return

	if not Session.restore_checkpoint(checkpoint):
		push_error("The selected checkpoint failed local validation.")
		checkpoint_label.text = "The checkpoint data is invalid."
		_transition_in_progress = false
		_set_buttons_disabled(false)
		return

	BattleData.return_scene = ""
	BattleData.return_position = Vector2.ZERO
	BattleData.enemy = null
	BattleData.enemy_name = ""
	BattleData.enemy_hp = 20
	BattleData.enemy_damage = 10
	BattleData.enemy_exp_reward = 25
	BattleData.enemy_gold_reward = 8
	BattleData.enemy_score_reward = 10
	BattleData.enemy_defeated = false
	BattleData.kill_counted = false
	BattleData.enemy_is_dungeon = false

	var error: Error = await Session.transition_from_death_screen(
		PlayerData.saved_current_scene
	)
	if error != OK:
		push_error("Could not load the checkpoint scene. Error: " + str(error))
		get_tree().paused = true
		checkpoint_label.text = "Could not load the checkpoint scene."
		_transition_in_progress = false
		_set_buttons_disabled(false)


func _load_checkpoint() -> Dictionary:
	var cached_checkpoint := Session.get_checkpoint_for_current_session()

	if not Session.is_logged_in():
		return cached_checkpoint

	if not GameAPI.load_checkpoint():
		if not cached_checkpoint.is_empty():
			return cached_checkpoint
		return {}

	var response: Array
	while true:
		response = await GameAPI.response_received
		if str(response[2].get("action", "")) == "load_checkpoint":
			break

	if bool(response[0]) and bool(response[2].get("has_checkpoint", false)):
		var server_checkpoint: Variant = response[2].get("checkpoint")
		if server_checkpoint is Dictionary:
			if Session.accept_checkpoint(server_checkpoint, Session.user_id):
				return server_checkpoint
			push_error("The server returned an invalid checkpoint.")

	return cached_checkpoint


func _on_quit_button_pressed() -> void:
	if _transition_in_progress:
		return

	_transition_in_progress = true
	_set_buttons_disabled(true)
	var error := Session.return_to_main_menu_from_death_screen(
		MAIN_MENU_SCENE
	)
	if error != OK:
		push_error("Could not load the main menu. Error: " + str(error))
		checkpoint_label.text = "Could not return to the main menu."
		_transition_in_progress = false
		_set_buttons_disabled(false)
		return



func _set_buttons_disabled(disabled: bool) -> void:
	respawn_button.disabled = disabled
	quit_button.disabled = disabled

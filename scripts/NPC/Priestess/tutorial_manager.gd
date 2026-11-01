extends Node

static var tutorial_completed := false
static var _completed_user_id := -1

@export var player: CharacterBody2D
@export var priestess: CharacterBody2D
@export var combat_spot: Marker2D
@export var enemy_spawn: Marker2D

var dialogue_box: Control
var objective_label: Label
var _tutorial_running := false


func _ready() -> void:
	add_to_group("tutorial_manager")

	var current_user_id := Session.user_id if Session.is_logged_in() else -1
	if _completed_user_id != current_user_id:
		tutorial_completed = false
		_completed_user_id = current_user_id
	if Session.tutorial_done:
		tutorial_completed = true

	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		push_error(
			"TutorialManager: assign the player export or add the player to "
			+ "the 'player' group."
		)
		return
	if priestess == null:
		push_error("TutorialManager: priestess is not assigned.")
		return
	if combat_spot == null:
		push_error("TutorialManager: combat_spot is not assigned.")
		return
	if enemy_spawn == null:
		push_error("TutorialManager: enemy_spawn is not assigned.")
		return

	var existing_companion := get_tree().get_first_node_in_group(
		"priestess_companion"
	) as CharacterBody2D
	if existing_companion != null and existing_companion != priestess:
		priestess.queue_free()
		priestess = existing_companion

	dialogue_box = priestess.get("dialogue_box") as Control
	if dialogue_box == null:
		dialogue_box = get_node_or_null("../UI/DialogueBox") as Control
	if dialogue_box == null:
		push_error("TutorialManager: UI/DialogueBox was not found.")
		return
	if not dialogue_box.has_method("start") or not dialogue_box.has_signal(
		"dialogue_finished"
	):
		push_error("TutorialManager: DialogueBox does not expose its tutorial API.")
		return

	objective_label = get_node_or_null("../UI/ObjectiveLabel") as Label
	if objective_label == null:
		push_error("TutorialManager: UI/ObjectiveLabel was not found.")
		return
	objective_label.hide()
	if tutorial_completed:
		_restore_after_battle()
	else:
		call_deferred("_run_tutorial")


func say(speaker: String, text: String) -> void:
	if not dialogue_box.has_method("start") or not dialogue_box.has_signal(
		"dialogue_finished"
	):
		push_error("TutorialManager: DialogueBox does not expose its tutorial API.")
		return

	var name_label := dialogue_box.get_node_or_null("%NameLabel") as Label
	if name_label == null:
		push_error("TutorialManager: DialogueBox is missing its name label.")
		return

	name_label.text = speaker
	dialogue_box.call("start", [{"speaker": speaker, "text": text}])
	await Signal(dialogue_box, "dialogue_finished")


func start_tutorial() -> void:
	if not tutorial_completed:
		_run_tutorial()


func _run_tutorial() -> void:
	if _tutorial_running:
		return
	_tutorial_running = true

	player.set("can_move", false)
	priestess.call("face_toward", player.global_position)
	await say(
		"Priestess",
		"Welcome, hero. I am glad you are here. Let me teach you how to survive."
	)

	player.call("face_toward", priestess.global_position)
	await say("Priestess", "Use W, A, S, and D to move around.")
	objective_label.text = "Move with W A S D"
	objective_label.show()
	player.set("can_move", true)
	await get_tree().create_timer(3.0).timeout

	player.set("can_move", false)
	player.call("face_toward", priestess.global_position)
	objective_label.hide()

	await say("Priestess", "Now follow me. Stay close, and I will lead you to your first foe.")
	objective_label.text = "Follow the priestess"
	objective_label.show()
	player.set("can_move", true)

	priestess.call("walk_to", combat_spot.global_position, player)
	await Signal(priestess, "walk_completed")
	while is_instance_valid(player) and (
		player.global_position.distance_to(combat_spot.global_position) > 40.0
	):
		await get_tree().physics_frame

	player.set("can_move", false)
	player.call("face_toward", priestess.global_position)
	priestess.call("face_toward", enemy_spawn.global_position)
	objective_label.hide()

	await say(
		"Priestess",
		"Touching the orc starts a turn-based battle."
	)
	await say(
		"Priestess",
		"On your turn, press Attack and solve the memory puzzle to strike."
	)
	await say(
		"Priestess",
		"On the enemy's turn, dodge with W, A, S, or D. Every hit costs HP."
	)

	Session.tutorial_done = true
	tutorial_completed = true
	_tutorial_running = false
	player.set("can_move", true)

	if Session.is_logged_in() and not GameAPI.save_progress():
		push_error("Tutorial completed, but its progress save could not start.")

	enemy_spawn.call("spawn_enemy")


func _restore_after_battle() -> void:
	var current_scene: Node = get_tree().current_scene
	var returning_to_battle_scene: bool = false
	var returning_from_tutorial_orc: bool = false
	if current_scene != null:
		returning_to_battle_scene = (
			BattleData.return_scene == current_scene.scene_file_path
		)
	if returning_to_battle_scene and BattleData.enemy_defeated:
		if BattleData.has_meta("enemy_spawn_id"):
			returning_from_tutorial_orc = (
				str(BattleData.get_meta("enemy_spawn_id")) == "tutorial_orc"
			)
	if returning_to_battle_scene and BattleData.return_position != Vector2.ZERO:
		player.global_position = BattleData.return_position
	if returning_to_battle_scene:
		BattleData.return_scene = ""
		BattleData.return_position = Vector2.ZERO
	player.set("can_move", true)

	if returning_from_tutorial_orc:
		BattleData.remove_meta("enemy_spawn_id")
		call_deferred("_introduce_companion")
	elif Session.cleared_spawns.has("tutorial_orc"):
		priestess.call_deferred("become_companion", player, dialogue_box)

	if is_instance_valid(enemy_spawn):
		enemy_spawn.call("spawn_enemy")


func _introduce_companion() -> void:
	priestess.global_position = player.global_position + Vector2(-32.0, 0.0)
	priestess.show()
	priestess.call("face_toward", player.global_position)
	player.set("can_move", false)
	await say(
		"Priestess",
		"You fought bravely, hero. I will follow you on your journey."
	)
	await say(
		"Priestess",
		"Wherever your path leads, I will be there beside you."
	)
	await say(
		"Priestess",
		"When your health is low, speak with me and ask for healing."
	)
	player.set("can_move", true)
	priestess.call("become_companion", player, dialogue_box)

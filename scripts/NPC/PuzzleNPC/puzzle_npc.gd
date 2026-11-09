extends StaticBody2D

signal puzzle_completed
signal trial_completed(trial_id: StringName)

@export var player_path: NodePath = ^"../player"
@export var trial_id: StringName = &""
@export var speaker_name: String = "Rune Keeper Orc Shaman"
@export var intro_lines: Array[String] = [
	"Welcome human hero, you must complete the run mastery trial before you can face him.",
	"Watch all six runes glow, then repeat their order. You can try again if you make a mistake."
]
@export var mock_lines: Array[String] = [
	"Pathetic. Even a goblin could remember six runes.",
	"Hah! The great hero, defeated by glowing rocks.",
	"Run along, human. My master doesn't fight idiots.",
	"Did the runes frighten you? Come back when you grow a spine.",
	"Haha bubu."
]

@export var puzzle_scene: PackedScene
var player: Node2D
var player_nearby := false
var interaction_active := false
var _trial_completed := false
var _puzzle_use_letters := false

@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_button: Button = $InteractionButton
@onready var npc_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var dialogue_box: Control = $CanvasLayer/DialogueBox
@onready var rune_puzzle: Control = $CanvasLayer/MissingRunePuzzle


func _ready() -> void:
	add_to_group("minotaur_trial")
	player = get_node_or_null(player_path) as Node2D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("PuzzleNPC could not find a player at player_path or in the 'player' group.")
	if str(trial_id).is_empty():
		push_error("PuzzleNPC requires a unique trial_id.")
	
	_apply_trial_profile()
	npc_sprite.play("idle_down")
	if puzzle_scene != null:
		var custom_puzzle := puzzle_scene.instantiate() as Control
		if custom_puzzle != null:
			if _puzzle_use_letters:
				custom_puzzle.set("use_letters", true)
			var holder := rune_puzzle.get_parent()
			rune_puzzle.queue_free()
			holder.add_child(custom_puzzle)
			rune_puzzle = custom_puzzle
	rune_puzzle.set("mock_lines", mock_lines)
	interaction_area.body_entered.connect(_on_interaction_area_body_entered)
	interaction_area.body_exited.connect(_on_interaction_area_body_exited)
	interaction_button.pressed.connect(_begin_interaction)
	if rune_puzzle.has_signal("puzzle_completed"):
		rune_puzzle.connect("puzzle_completed", _on_rune_puzzle_completed)
	else:
		push_error("PuzzleNPC MissingRunePuzzle does not expose puzzle_completed.")
	interaction_button.hide()


func _physics_process(_delta: float) -> void:
	_update_interaction_button()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("interact")
		and player_nearby
		and not interaction_active
		and not _player_at_door()
	):
		_begin_interaction()


func _player_at_door() -> bool:
	for door in get_tree().get_nodes_in_group("room_door"):
		if door.get("player_nearby"):
			return true
	return false


func _update_interaction_button() -> void:
	if (
		player_nearby
		and not interaction_active
		and not _trial_completed
		and not _player_at_door()
	):
		interaction_button.show()
	else:
		interaction_button.hide()


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body == player:
		player_nearby = true
		_update_interaction_button()


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body == player:
		player_nearby = false
		_update_interaction_button()


func _begin_interaction() -> void:
	if (
		interaction_active
		or _trial_completed
		or not player_nearby
		or _player_at_door()
	):
		_update_interaction_button()
		return
	if (
		not dialogue_box.has_method("start")
		or not dialogue_box.has_signal("dialogue_finished")
	):
		push_error("PuzzleNPC DialogueBox does not expose the existing dialogue API.")
		return
	if (
		not rune_puzzle.has_method("start_puzzle")
		or not rune_puzzle.has_signal("puzzle_closed")
	):
		push_error("PuzzleNPC MissingRunePuzzle does not expose its puzzle API.")
		return

	interaction_active = true
	interaction_button.hide()
	_set_portrait_hidden(true)
	dialogue_box.call("start", _make_lines(intro_lines))
	
	await Signal(dialogue_box, "dialogue_finished")
	_set_portrait_hidden(false)
	if not is_inside_tree():
		return

	rune_puzzle.call("start_puzzle")
	await Signal(rune_puzzle, "puzzle_closed")
	
	if is_inside_tree():
		interaction_active = false
		_update_interaction_button()


func _on_rune_puzzle_completed() -> void:
	if _trial_completed:
		return

	_trial_completed = true
	_update_interaction_button()
	puzzle_completed.emit()
	trial_completed.emit(trial_id)


func set_trial_completed(completed: bool) -> void:
	_trial_completed = completed
	_update_interaction_button()


func should_prioritize_interaction() -> bool:
	return player_nearby and not interaction_active and not _trial_completed


func _set_portrait_hidden(should_hide: bool) -> void:
	# Adjust the path to wherever Portrait sits under DialogueBox
	var portrait := dialogue_box.get_node_or_null("%Portrait") as Control
	if portrait == null:
		push_warning("PuzzleNPC could not find the Portrait node.")
		return
	portrait.self_modulate.a = 0.0 if should_hide else 1.0


func _make_lines(texts: Array[String]) -> Array:
	var lines: Array = []
	for text in texts:
		lines.append({"speaker": speaker_name, "text": text})
	return lines


const NPC_PROFILES := {
	&"room_b": {
		"speaker": "Elf Rune Keeper",
		"puzzle": "res://scenes/puzzles/pair_match_puzzle.tscn",
		"intro": [
			"Welcome, traveler. The runes have whispered of your coming.",
			"Flip the cards and find every matching pair. Do not fear a mistake, you may try again."
		],
		"mock": [
			"Oh dear. Even the saplings in my grove remember better than that.",
			"The cards are patient, hero. Your memory is not.",
			"How graceful, to stumble over simple symbols.",
			"Breathe, little hero. Then try not to embarrass yourself again."
		]
	},
	&"room_c": {
		"speaker": "Human Rune Keeper",
		"puzzle": "res://scenes/puzzles/riddle_puzzle.tscn",
		"use_letters": true,
		"intro": [
			"Hold there, hero. Before you face the Minotaur, you'll prove your mind is as sharp as your sword.",
			"Memorize the row of letters I show you. Then I will change it, and you must tell me what changed. One mistake and you start over."
		],
		"mock": [
			"Ha! I've seen farmhands with better wits.",
			"Is that all? And you plan to fight a Minotaur?",
			"Wrong again. Maybe stick to swinging that sword.",
			"Come on, hero. My grandmother could do this half asleep."
		]
	}
}


func _apply_trial_profile() -> void:
	if not NPC_PROFILES.has(trial_id):
		return
	var profile: Dictionary = NPC_PROFILES[trial_id]
	_puzzle_use_letters = bool(profile.get("use_letters", false))
	speaker_name = profile["speaker"]
	intro_lines.assign(profile["intro"])
	mock_lines.assign(profile["mock"])
	var path: String = profile["puzzle"]
	if ResourceLoader.exists(path):
		puzzle_scene = load(path) as PackedScene
	else:
		push_error("PuzzleNPC puzzle scene not found: " + path)

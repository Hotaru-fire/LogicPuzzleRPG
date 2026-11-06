extends Control

const DUNGEON_1_SCENE := "res://scenes/maps/dungeon_1.tscn"
const DUNGEON_1_LOAD_DELAY := 5.0

@onready var animation_player = $AnimationPlayer

var transition_in_progress := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func change_scene(scene_path: String):
	if transition_in_progress:
		return

	var tree := get_tree()
	var was_paused := tree.paused
	transition_in_progress = true
	tree.paused = true
	animation_player.play("fade_out")
	await animation_player.animation_finished

	if scene_path == DUNGEON_1_SCENE:
		await tree.create_timer(DUNGEON_1_LOAD_DELAY, true).timeout

	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		push_error(
			"Could not change to scene '%s'. Error: %s"
			% [scene_path, error]
		)
		animation_player.play("fade_in")
		await animation_player.animation_finished
		tree.paused = was_paused
		transition_in_progress = false
		return

	await tree.scene_changed
	animation_player.play("fade_in")
	await animation_player.animation_finished
	tree.paused = was_paused
	transition_in_progress = false

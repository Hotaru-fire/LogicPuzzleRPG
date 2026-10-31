extends Control

@onready var animation_player = $AnimationPlayer


func change_scene(scene_path: String):

	# Fade the screen to black
	animation_player.play("fade_out")

	# Wait until fade_out finishes
	await animation_player.animation_finished

	# Change to the new scene
	get_tree().change_scene_to_file(scene_path)

	# Wait one frame so the new scene can load
	await get_tree().process_frame

	# Fade the screen back in
	animation_player.play("fade_in")

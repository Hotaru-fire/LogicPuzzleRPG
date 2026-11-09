extends Area2D

@export_file("*.tscn") var target_room_path: String
@export var target_spawn_marker: NodePath = ^"RoomEntry"

var player_nearby := false

@onready var prompt: Label = $Label


func _ready() -> void:
	add_to_group("room_door")
	prompt.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if player_nearby and event.is_action_pressed("interact"):
		_travel()


func _travel() -> void:
	if target_room_path.is_empty():
		push_error("Room door has no target room scene assigned!")
		return

	var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager")
	if dungeon_manager == null or not dungeon_manager.has_method("load_floor"):
		push_error("Room door could not find a dungeon manager!")
		return

	dungeon_manager.call(
		"load_floor",
		target_room_path,
		true,
		target_spawn_marker
	)

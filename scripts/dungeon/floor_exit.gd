extends Area2D

var _used := false


func _ready() -> void:
	print("FloorExit ready: ", name,
		" monitoring=", monitoring,
		" mask=", collision_mask,
		" shapes=", get_children().filter(func(c): return c is CollisionShape2D).size())
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("FloorExit touched by: ", body.name,
		" in player group=", body.is_in_group("player"))
	if _used or not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("dungeon_manager")
	if manager == null:
		push_error("FloorExit: no dungeon_manager found.")
		return
	_used = true
	manager.call_deferred("go_to_boss_floor")

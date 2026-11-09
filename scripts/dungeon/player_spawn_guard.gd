extends RefCounted

const POSITION_TOLERANCE := 8.0
const MAX_CORRECTIONS := 2


func ensure_player_at_spawn(
	player: Node2D,
	expected_position: Vector2
) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false

	_place_player(player, expected_position)
	var tree := player.get_tree()

	for correction_index in range(MAX_CORRECTIONS + 1):
		await tree.physics_frame
		if not is_instance_valid(player) or not player.is_inside_tree():
			return false
		if player.global_position.distance_to(expected_position) <= POSITION_TOLERANCE:
			return true
		if correction_index < MAX_CORRECTIONS:
			_place_player(player, expected_position)

	push_error(
		"Player did not remain at the requested spawn position: expected %s, got %s."
		% [expected_position, player.global_position]
	)
	return false


func _place_player(player: Node2D, expected_position: Vector2) -> void:
	var character_body := player as CharacterBody2D
	if character_body != null:
		character_body.velocity = Vector2.ZERO
	player.global_position = expected_position

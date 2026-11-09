extends TileMapLayer

const WALL_COLLISION_LAYER_BIT := 1
const PHYSICS_LAYER_INDEX := 0


func _ready() -> void:
	_ensure_used_wall_tiles_have_collision()
	get_tree().node_added.connect(_on_node_added)

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	_configure_character_bodies(scene_root)


func _ensure_used_wall_tiles_have_collision() -> void:
	if tile_set == null:
		push_error("%s has no TileSet; wall collision could not be configured." % get_path())
		return

	if tile_set.get_physics_layers_count() == 0:
		tile_set.add_physics_layer()

	var physics_layer_bits := tile_set.get_physics_layer_collision_layer(PHYSICS_LAYER_INDEX)
	tile_set.set_physics_layer_collision_layer(
		PHYSICS_LAYER_INDEX,
		physics_layer_bits | WALL_COLLISION_LAYER_BIT
	)

	var collision_changed := false
	for cell in get_used_cells():
		var tile_data := get_cell_tile_data(cell)
		if tile_data == null:
			push_error("WallLayer cell %s has no TileData; collision was not generated." % cell)
			continue

		if _has_valid_collision(tile_data):
			continue

		tile_data.set_collision_polygons_count(PHYSICS_LAYER_INDEX, 1)
		tile_data.set_collision_polygon_points(
			PHYSICS_LAYER_INDEX,
			0,
			_get_full_cell_polygon()
		)
		collision_changed = true

	if collision_changed:
		notify_runtime_tile_data_update()


func _has_valid_collision(tile_data: TileData) -> bool:
	for polygon_index in tile_data.get_collision_polygons_count(PHYSICS_LAYER_INDEX):
		var points := tile_data.get_collision_polygon_points(PHYSICS_LAYER_INDEX, polygon_index)
		if points.size() < 3:
			continue

		var twice_area := 0.0
		for point_index in range(points.size()):
			var current := points[point_index]
			var next := points[(point_index + 1) % points.size()]
			twice_area += current.x * next.y - next.x * current.y

		if not is_zero_approx(twice_area):
			return true

	return false


func _get_full_cell_polygon() -> PackedVector2Array:
	var half_size := Vector2(tile_set.tile_size) * 0.5
	return PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])


func _on_node_added(node: Node) -> void:
	if node is CharacterBody2D:
		call_deferred("_include_wall_collision_mask", node.get_instance_id())


func _configure_character_bodies(node: Node) -> void:
	if node is CharacterBody2D:
		call_deferred("_include_wall_collision_mask", node.get_instance_id())

	for child in node.get_children():
		_configure_character_bodies(child)


func _include_wall_collision_mask(body_instance_id: int) -> void:
	var body := instance_from_id(body_instance_id) as CharacterBody2D
	if is_instance_valid(body):
		body.collision_mask |= WALL_COLLISION_LAYER_BIT

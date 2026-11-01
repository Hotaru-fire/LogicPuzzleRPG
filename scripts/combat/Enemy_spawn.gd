extends Marker2D

# Remembers cleared spawn points for the whole game session,
# even though the overworld scene reloads after every battle.
# (static vars need Godot 4.1+)
static var defeated_spawns := {}
static var defeated_spawns_user_id := -1

@export var enemy_scene: PackedScene
@export var spawn_id := "tutorial_orc"
@export var auto_spawn := true

var enemy = null


func _ready() -> void:
	if spawn_id.is_empty():
		spawn_id = str(get_path())

	var current_user_id := Session.user_id if Session.is_logged_in() else -1
	if defeated_spawns_user_id != current_user_id:
		defeated_spawns.clear()
		defeated_spawns_user_id = current_user_id

	check_return_from_battle()

	if not auto_spawn:
		return

	spawn_enemy()


func _is_defeated() -> bool:
	if Session.cleared_spawns.has(spawn_id):
		defeated_spawns[spawn_id] = true
		return true

	return defeated_spawns.has(spawn_id)


func check_return_from_battle() -> void:
	# If we just came back from a won battle against THIS spawn point,
	# mark it as cleared.
	var current_scene := get_tree().current_scene
	if (
		current_scene == null
		or BattleData.return_scene != current_scene.scene_file_path
	):
		return

	if not BattleData.has_meta("enemy_spawn_id"):
		return

	if not BattleData.enemy_defeated:
		if BattleData.get_meta("enemy_spawn_id") == spawn_id:
			BattleData.remove_meta("enemy_spawn_id")
		return

	if BattleData.get_meta("enemy_spawn_id") == spawn_id:
		defeated_spawns[spawn_id] = true
		var newly_cleared: bool = Session.record_cleared_spawn(spawn_id)
		if newly_cleared and Session.is_logged_in() and not GameAPI.save_progress():
			push_error(
				"Spawn '%s' was cleared, but its progress save could not start."
				% spawn_id
			)
		if spawn_id != "tutorial_orc":
			BattleData.remove_meta("enemy_spawn_id")
		print("Spawn point cleared: ", spawn_id)


func spawn_enemy() -> void:
	if is_instance_valid(enemy) or _is_defeated():
		return

	if enemy_scene == null:
		push_error("EnemySpawn '%s': enemy_scene is not assigned!" % name)
		return

	enemy = enemy_scene.instantiate()
	enemy.set_meta("spawn_id", spawn_id)

	var parent_node := get_parent()

	# Set the position BEFORE adding to the tree so the orc's _ready()
	# records the correct home_position.
	enemy.position = parent_node.to_local(global_position)

	parent_node.add_child.call_deferred(enemy)

	print("Spawned enemy at ", spawn_id)

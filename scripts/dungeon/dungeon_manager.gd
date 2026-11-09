extends Node

@export var enemy_scene: PackedScene

const MINOTAUR_SCENE = preload("res://scenes/enemies/minotaur.tscn")
const PLAYER_SPAWN_GUARD = preload("res://scripts/dungeon/player_spawn_guard.gd")
const DIALOGUE_BOX_SCENE = preload("res://scenes/dialogue/DialogueBox.tscn")
const FIRST_FLOOR := "res://scenes/maps/levels/Floor 1/dungeon_1_floor.tscn"
const MINOTAUR_TRIAL_IDS: Array[StringName] = [
	&"room_a",
	&"room_b",
	&"room_c"
]
const TRIAL_GOLD_REWARD := 50

var enemies_defeated := 0

var active_enemies := 0
var max_active_enemies := 5

var minotaur_spawned := false
var minotaur_instance: CharacterBody2D = null

var current_floor: Node2D
var boss_spawn_point: Marker2D
var enemy_spawn_points: Node
var _loading_floor := false

@onready var floor_holder: Node2D = $"../CurrentFloor"
@onready var dungeon_level_label: Label = $"../MinotaurTrialsLayer/DungeonLevelLabel"
@onready var trial_objective_panel: PanelContainer = get_parent().get_node_or_null(
	"MinotaurTrialsLayer/MarginContainer/MinotaurTrialsPanel"
)


func _ready() -> void:
	print("DungeonManager is ready!")
	add_to_group("dungeon_manager")
	_update_dungeon_level_label()

	var returning_from_battle := BattleData.returning_from_battle
	var floor_to_load := FIRST_FLOOR
	var loading_saved_floor := (
		not returning_from_battle
		and PlayerData.has_save_data
		and PlayerData.is_dungeon_floor_scene(PlayerData.saved_current_scene)
	)
	if returning_from_battle:
		if (
			BattleData.current_floor_path.is_empty()
			or not ResourceLoader.exists(BattleData.current_floor_path)
		):
			push_error(
				"Battle return floor is missing or invalid: "
				+ BattleData.current_floor_path
			)
		else:
			floor_to_load = BattleData.current_floor_path
	elif loading_saved_floor:
		floor_to_load = PlayerData.saved_current_scene

	var spawn_player_at_dungeon_entry := (
		not returning_from_battle and not loading_saved_floor
	)
	await load_floor(floor_to_load, spawn_player_at_dungeon_entry)
	if loading_saved_floor and BattleData.current_floor_path == floor_to_load:
		PlayerData.saved_current_scene = PlayerData.DUNGEON_MAIN_SCENE
	if returning_from_battle:
		_restore_room_enemies_from_battle()
	BattleData.returning_from_battle = false

	enemies_defeated = Session.dungeon_enemies_defeated

	await get_tree().process_frame

	var player = get_parent().get_node_or_null("player")

	if player != null:
		print("Saved return position: ", BattleData.return_position)

		# On a database load, player.gd restores PlayerData.saved_position.
		# Only use BattleData.return_position when a battle supplied it.
		if BattleData.return_position != Vector2.ZERO:
			player.global_position = BattleData.return_position

			print("Restored battle return position: ", player.global_position)

		_sync_priestess_companion(player)
		BattleData.return_scene = ""
		BattleData.return_position = Vector2.ZERO
		call_deferred("_save_dungeon_entry_checkpoint")
	else:
		push_error("DungeonManager could not find the player!")

	# Do not spawn the Minotaur again after its defeat has been saved.
	if PlayerData.saved_boss_completed:
		print("Boss already completed. No Minotaur will be spawned.")
		return

	_update_trial_objective()
	if returning_from_battle:
		print("Returned from battle; keeping room encounters cleared until room re-entry.")
	else:
		_spawn_room_encounters()


func load_floor(
	path: String,
	move_player := true,
	spawn_marker: NodePath = ^"DungeonSpawn"
) -> void:
	if _loading_floor:
		return

	_loading_floor = true
	var floor_scene := load(path) as PackedScene
	if floor_scene == null:
		push_error("Could not load dungeon room scene: " + path)
		_loading_floor = false
		return

	var next_floor := floor_scene.instantiate() as Node2D
	if next_floor == null:
		push_error("Dungeon room scene root must be a Node2D: " + path)
		_loading_floor = false
		return

	if current_floor:
		var previous_floor := current_floor
		previous_floor.queue_free()
		await previous_floor.tree_exited

	current_floor = next_floor
	floor_holder.add_child(current_floor)
	BattleData.current_floor_path = path

	boss_spawn_point = current_floor.get_node_or_null("BossSpawnPoints/BossSpawnPoint")
	enemy_spawn_points = current_floor.get_node_or_null("EnemySpawnPoints")
	_register_trial_npcs()
	_refresh_floor_gate()
	_update_trial_objective()

	# Per-floor state resets (enemies were freed with the old floor)
	active_enemies = 0
	minotaur_spawned = false
	minotaur_instance = null

	var spawn_node := current_floor.get_node_or_null(spawn_marker)
	print(
		"DungeonManager.load_floor path='%s' spawn_marker='%s' found=%s class='%s'."
		% [
			path,
			spawn_marker,
			spawn_node != null,
			spawn_node.get_class() if spawn_node != null else "<none>"
		]
	)
	if move_player:
		var spawn := spawn_node as Node2D
		var player = get_parent().get_node_or_null("player")
		if spawn == null:
			push_error(
				"Dungeon room '%s' has no spawn marker '%s'."
				% [path, spawn_marker]
			)
		elif player == null:
			push_error("DungeonManager could not find the player!")
		else:
			var spawn_guard = PLAYER_SPAWN_GUARD.new()
			await spawn_guard.ensure_player_at_spawn(
				player,
				spawn.global_position
			)
			_sync_priestess_companion(player)
	else:
		var player = get_parent().get_node_or_null("player")
		if player != null:
			_sync_priestess_companion(player)

	_loading_floor = false
	if move_player:
		_spawn_room_encounters()


func _sync_priestess_companion(player: Node2D) -> void:
	var companion := get_tree().get_first_node_in_group("priestess_companion")
	var scene_priestess := get_parent().get_node_or_null("Priestess")
	if (
		companion != null
		and scene_priestess != null
		and scene_priestess != companion
	):
		scene_priestess.queue_free()

	if companion == null:
		companion = scene_priestess
		if companion == null:
			push_error(
				"Dungeon scene is missing its Priestess node. "
				+ "Add the Priestess scene instance to current_level.tscn."
			)
			return
		if not companion.has_method("become_companion"):
			push_error("Dungeon Priestess does not expose become_companion().")
			return

		var dialogue_box := companion.get("dialogue_box") as Control
		if dialogue_box == null:
			dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as Control
			if dialogue_box == null:
				push_error("Could not instantiate the Priestess DialogueBox.")
				return
			companion.set("dialogue_box", dialogue_box)
			companion.add_child(dialogue_box)
		companion.call("become_companion", player, dialogue_box)
		return

	if companion.has_method("become_companion"):
		var dialogue_box := companion.get("dialogue_box") as Control
		if not is_instance_valid(dialogue_box):
			dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as Control
			if dialogue_box == null:
				push_error("Could not instantiate the Priestess DialogueBox.")
				return
			companion.set("dialogue_box", dialogue_box)
			companion.add_child(dialogue_box)
		companion.call("become_companion", player, dialogue_box)
	elif companion.has_method("sync_with_player"):
		companion.call("sync_with_player", player)


func _spawn_room_encounters() -> void:
	if PlayerData.saved_boss_completed:
		print("Boss already completed. No Minotaur will be spawned.")
		return

	if _all_trials_completed():
		spawn_minotaur()
		return

	if enemy_spawn_points == null:
		push_warning("No enemy spawn points found!")
		return

	var spawn_points := enemy_spawn_points.get_children()
	spawn_points.shuffle()
	var spawn_count := mini(spawn_points.size(), max_active_enemies)
	for spawn_index in range(spawn_count):
		var spawn_point := spawn_points[spawn_index] as Node2D
		if spawn_point != null:
			spawn_enemy(spawn_point)


func _save_dungeon_entry_checkpoint() -> void:
	if not GameAPI.save_checkpoint():
		if Session.is_logged_in():
			push_error("Could not start saving the dungeon checkpoint.")
		return

	if not Session.is_logged_in():
		print("Dungeon checkpoint cached for this offline session.")
		return

	var response: Array
	while true:
		response = await GameAPI.response_received
		if str(response[2].get("action", "")) == "save_checkpoint":
			break

	if not bool(response[0]):
		push_error("Dungeon checkpoint save failed: " + str(response[1]))


func spawn_minotaur() -> void:
	if minotaur_spawned or PlayerData.saved_boss_completed:
		return

	if not _all_trials_completed():
		return

	if boss_spawn_point == null:
		push_error("BossSpawnPoints/BossSpawnPoint was not found!")
		return

	minotaur_instance = MINOTAUR_SCENE.instantiate()
	_apply_dungeon_level(minotaur_instance)
	minotaur_instance.position = current_floor.to_local(
		boss_spawn_point.global_position
	)
	current_floor.add_child(minotaur_instance)
	minotaur_spawned = true

	print("Minotaur spawned at: ", minotaur_instance.global_position)


func spawn_enemy(spawn_point: Node2D) -> void:
	if active_enemies >= max_active_enemies:
		return

	if enemy_scene == null:
		push_error("DungeonManager enemy_scene has not been assigned!")
		return

	if enemy_spawn_points == null:
		push_warning("No enemy spawn points found!")
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if enemy == null:
		push_error("DungeonManager could not instantiate enemy_scene as a Node2D.")
		return
	_apply_dungeon_level(enemy)
	enemy.position = current_floor.to_local(spawn_point.global_position)
	current_floor.add_child(enemy)

	active_enemies += 1

	print("Enemy spawned!")
	print("Active enemies: ", active_enemies)


func _apply_dungeon_level(enemy: Node) -> void:
	if enemy.has_method("set_dungeon_level"):
		enemy.call("set_dungeon_level", Session.dungeon_level)


func _update_dungeon_level_label() -> void:
	dungeon_level_label.text = "Dungeon Level: %d / %d" % [
		Session.dungeon_level,
		Session.MAX_DUNGEON_LEVEL
	]


func _rescale_current_floor_enemies() -> void:
	if not is_instance_valid(current_floor):
		return

	for enemy in current_floor.find_children("*", "", true, false):
		_apply_dungeon_level(enemy)


func capture_room_enemies_for_battle(engaged_enemy: Node) -> void:
	BattleData.room_enemy_snapshot.clear()
	BattleData.enemy_instance_id = (
		engaged_enemy.get_instance_id()
		if is_instance_valid(engaged_enemy)
		else 0
	)

	for child in current_floor.get_children():
		if not child.is_in_group("enemies"):
			continue

		if child.scene_file_path.is_empty():
			push_error(
				"Cannot preserve battle enemy '%s': it has no source scene."
				% child.name
			)
			continue

		BattleData.room_enemy_snapshot.append(
			{
				"scene_path": child.scene_file_path,
				"global_position": child.global_position,
				"instance_id": child.get_instance_id(),
				"spawn_id": str(child.get_meta("spawn_id", ""))
			}
		)


func _restore_room_enemies_from_battle() -> void:
	for enemy_state in BattleData.room_enemy_snapshot:
		var instance_id := int(enemy_state.get("instance_id", 0))
		if BattleData.enemy_defeated and instance_id == BattleData.enemy_instance_id:
			continue

		var scene_path := str(enemy_state.get("scene_path", ""))
		var enemy_scene_resource := load(scene_path) as PackedScene
		if enemy_scene_resource == null:
			push_error("Could not reload battle room enemy scene: " + scene_path)
			continue

		var enemy := enemy_scene_resource.instantiate() as Node2D
		if enemy == null:
			push_error("Battle room enemy scene root must be a Node2D: " + scene_path)
			continue
		_apply_dungeon_level(enemy)

		var spawn_id := str(enemy_state.get("spawn_id", ""))
		if not spawn_id.is_empty():
			enemy.set_meta("spawn_id", spawn_id)
		var saved_global_position: Vector2 = enemy_state.get(
			"global_position",
			Vector2.ZERO
		)
		enemy.position = current_floor.to_local(saved_global_position)
		current_floor.add_child(enemy)
		active_enemies += 1

	BattleData.battle_return_grace_until_msec = Time.get_ticks_msec() + 2000
	BattleData.room_enemy_snapshot.clear()
	BattleData.enemy_instance_id = 0
	BattleData.enemy = null


func enemy_defeated(
	exp_reward: int,
	gold_reward: int,
	score_reward: int
) -> void:
	print("DEBUG: enemy_defeated called")
	Session.record_dungeon_enemy_kill(
		exp_reward,
		gold_reward,
		score_reward
	)
	enemies_defeated = Session.dungeon_enemies_defeated
	print("DUNGEON COUNT: ", enemies_defeated)
	print("SESSION DUNGEON COUNT: ", Session.dungeon_enemies_defeated)
	print("LOGGED IN: ", Session.is_logged_in())
	active_enemies = max(active_enemies - 1, 0)

	print("Dungeon kills: ", enemies_defeated)
	print("Active enemies: ", active_enemies)
	print("Global score: ", Session.score)

	if Session.is_logged_in():
		GameAPI.save_progress()


func _register_trial_npcs() -> void:
	for node in current_floor.find_children("*", "", true, false):
		if not node.is_in_group("minotaur_trial"):
			continue

		var trial_id := StringName(str(node.get("trial_id")))
		if not MINOTAUR_TRIAL_IDS.has(trial_id):
			push_error("Unknown Minotaur trial id '%s' on %s." % [trial_id, node.name])
			continue
		if not node.has_signal("trial_completed"):
			push_error("Minotaur trial '%s' has no trial_completed signal." % trial_id)
			continue

		var callback := Callable(self, "_on_trial_completed")
		if not node.is_connected("trial_completed", callback):
			node.connect("trial_completed", callback)
		if node.has_method("set_trial_completed"):
			node.call(
				"set_trial_completed",
				Session.floor1_trials_completed.has(trial_id)
			)


func _on_trial_completed(trial_id: StringName) -> void:
	if not MINOTAUR_TRIAL_IDS.has(trial_id):
		push_error("Cannot count unknown Minotaur trial '%s'." % trial_id)
		return
	if Session.floor1_trials_completed.has(trial_id):
		return

	Session.floor1_trials_completed.append(trial_id)
	Session.dungeon_level = mini(
		Session.dungeon_level + 1,
		Session.MAX_DUNGEON_LEVEL
	)
	_update_dungeon_level_label()
	_rescale_current_floor_enemies()
	Session.record_cleared_spawn("floor1_trial_" + str(trial_id))
	Session.award_gold(TRIAL_GOLD_REWARD)
	print(
		"Minotaur trials completed: ",
		Session.floor1_trials_completed.size(),
		"/",
		MINOTAUR_TRIAL_IDS.size()
	)
	print("Awarded ", TRIAL_GOLD_REWARD, " gold for trial ", trial_id)

	if Session.is_logged_in() and not GameAPI.save_progress():
		push_error("Could not start saving progress after completing a Minotaur trial.")

	_update_trial_objective()
	_refresh_floor_gate()
	if _all_trials_completed():
		spawn_minotaur()


func _all_trials_completed() -> bool:
	for trial_id in MINOTAUR_TRIAL_IDS:
		if not Session.floor1_trials_completed.has(trial_id):
			return false
	return true


func _update_trial_objective() -> void:
	if trial_objective_panel == null:
		push_error("Minotaur trial objective panel was not found.")
		return

	var completed_count := 0
	for trial_index in range(MINOTAUR_TRIAL_IDS.size()):
		var trial_id: StringName = MINOTAUR_TRIAL_IDS[trial_index]
		var completed := Session.floor1_trials_completed.has(trial_id)
		if completed:
			completed_count += 1

		var label := trial_objective_panel.get_node_or_null(
			"VBoxContainer/Trial%dLabel" % (trial_index + 1)
		) as Label
		if label == null:
			push_error("Minotaur objective panel is missing Trial%dLabel." % (trial_index + 1))
			continue

		var room_name := String(trial_id).replace("_", " ").capitalize()
		label.text = "%s Trial %d: %s" % [
			"[x]" if completed else "[ ]",
			trial_index + 1,
			room_name
		]

	var count_label := trial_objective_panel.get_node_or_null(
		"VBoxContainer/ProgressLabel"
	) as Label
	if count_label != null:
		count_label.text = "Progress: %d / %d" % [
			completed_count,
			MINOTAUR_TRIAL_IDS.size()
		]

	trial_objective_panel.show()


func _refresh_floor_gate() -> void:
	if not _all_trials_completed():
		return

	var gate := current_floor.get_node_or_null("Decors/Floor1Gate") as StaticBody2D
	if gate == null:
		return

	gate.hide()
	gate.collision_layer = 0
	gate.collision_mask = 0
	for collision_shape in gate.find_children("*", "CollisionShape2D", true, false):
		collision_shape.set_deferred("disabled", true)

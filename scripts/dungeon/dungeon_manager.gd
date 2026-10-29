extends Node

@export var enemy_scene: PackedScene

const MINOTAUR_SCENE = preload("res://scenes/enemies/minotaur.tscn")

var enemies_defeated := 0
var max_enemies_to_defeat := 10

var active_enemies := 0
var max_active_enemies := 5

var minotaur_spawned := false
var minotaur_instance: CharacterBody2D = null

@onready var count_enemy_label = $"../CanvasLayer/CountEnemyLabel"
@onready var boss_spawn_point: Marker2D = $"../BossSpawnPoints/BossSpawnPoint"


func _ready() -> void:
	print("DungeonManager is ready!")

	enemies_defeated = Session.dungeon_enemies_defeated
	update_enemy_counter()

	await get_tree().process_frame

	var player = get_parent().get_node_or_null("player")

	if player != null:
		print("Saved return position: ", BattleData.return_position)

		# On a database load, player.gd restores PlayerData.saved_position.
		# Only use BattleData.return_position when a battle supplied it.
		if BattleData.return_position != Vector2.ZERO:
			player.global_position = BattleData.return_position

			print("Restored battle return position: ", player.global_position)

		BattleData.return_scene = ""
		BattleData.return_position = Vector2.ZERO
		call_deferred("_save_dungeon_entry_checkpoint")
	else:
		push_error("DungeonManager could not find the player!")

	# Do not spawn the Minotaur again after its defeat has been saved.
	if PlayerData.saved_boss_completed:
		print("Boss already completed. No Minotaur will be spawned.")
		return

	if enemies_defeated >= max_enemies_to_defeat:
		spawn_minotaur()
		return

	for i in range(max_active_enemies):
		spawn_enemy()


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


func update_enemy_counter() -> void:
	if count_enemy_label == null:
		return

	count_enemy_label.text = "Enemies: %d / %d" % [
		enemies_defeated,
		max_enemies_to_defeat
	]

	count_enemy_label.show()


func spawn_minotaur() -> void:
	if minotaur_spawned or PlayerData.saved_boss_completed:
		return

	minotaur_spawned = true

	print("DEBUG: 10 enemies defeated. Spawning Minotaur!")

	if boss_spawn_point == null:
		push_error("BossSpawnPoints/BossSpawnPoint was not found!")
		return

	minotaur_instance = MINOTAUR_SCENE.instantiate()

	get_parent().add_child(minotaur_instance)
	minotaur_instance.global_position = boss_spawn_point.global_position

	print("Minotaur spawned at: ", minotaur_instance.global_position)


func spawn_enemy() -> void:
	if enemies_defeated >= max_enemies_to_defeat:
		return

	if active_enemies >= max_active_enemies:
		return

	if enemy_scene == null:
		push_error("DungeonManager enemy_scene has not been assigned!")
		return

	var spawn_points = $"../EnemySpawnPoints".get_children()

	if spawn_points.is_empty():
		push_warning("No enemy spawn points found!")
		return

	var enemy = enemy_scene.instantiate()
	var spawn_point = spawn_points.pick_random()

	get_parent().add_child.call_deferred(enemy)
	enemy.global_position = spawn_point.global_position

	active_enemies += 1

	print("Enemy spawned!")
	print("Active enemies: ", active_enemies)


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

	print("Dungeon kills: ", enemies_defeated, "/", max_enemies_to_defeat)
	print("Active enemies: ", active_enemies)
	print("Global score: ", Session.score)

	update_enemy_counter()

	if Session.is_logged_in():
		GameAPI.save_progress()

	if enemies_defeated >= max_enemies_to_defeat:
		print("DEBUG: Boss threshold reached!")
		spawn_minotaur()
		return

	spawn_enemy()

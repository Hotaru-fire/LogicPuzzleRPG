
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


# ON LOAD
func _ready():
	print("DungeonManager is ready!")

	enemies_defeated = Session.dungeon_enemies_defeated

	update_enemy_counter()

	# Restore the player's saved dungeon position.
	await get_tree().process_frame

	var player = get_parent().get_node_or_null("player")

	if player != null:
		print("Saved return position: ", BattleData.return_position)

		if BattleData.return_position != Vector2.ZERO:
			player.global_position = BattleData.return_position
			print("Restored player position: ", player.global_position)
	else:
		push_error("DungeonManager could not find the player!")

	# If the player already defeated 10 enemies, spawn the boss.
	if enemies_defeated >= max_enemies_to_defeat:
		spawn_minotaur()
		return

	# Otherwise, spawn the regular dungeon enemies.
	for i in range(max_active_enemies):
		spawn_enemy()


func update_enemy_counter():
	if count_enemy_label == null:
		return

	count_enemy_label.text = "Enemies: %d / %d" % [
		enemies_defeated,
		max_enemies_to_defeat
	]

	count_enemy_label.show()


# SPAWN MINOTAUR BOSS
func spawn_minotaur():
	if minotaur_spawned:
		return

	minotaur_spawned = true

	print("DEBUG: 10 enemies defeated. Spawning Minotaur!")

	if boss_spawn_point == null:
		push_error("BossSpawnPoints/BossSpawnPoint was not found!")
		return

	minotaur_instance = MINOTAUR_SCENE.instantiate()

	# Add the boss to the dungeon scene.
	get_parent().add_child(minotaur_instance)

	# Place the boss at the marker's global position.
	minotaur_instance.global_position = boss_spawn_point.global_position

	print("Minotaur spawned at: ", minotaur_instance.global_position)


# ENEMY SPAWN
func spawn_enemy():
	if enemies_defeated >= max_enemies_to_defeat:
		return

	if active_enemies >= max_active_enemies:
		return

	var enemy = enemy_scene.instantiate()

	var spawn_points = $"../EnemySpawnPoints".get_children()

	if spawn_points.is_empty():
		push_warning("No enemy spawn points found!")
		return

	var spawn_point = spawn_points.pick_random()

	get_parent().add_child.call_deferred(enemy)
	enemy.global_position = spawn_point.global_position

	active_enemies += 1

	print("Enemy spawned!")
	print("Active enemies: ", active_enemies)


# ENEMY DEATH COUNTER
func enemy_defeated():
	print("DEBUG: enemy_defeated called")
	print("DEBUG: Current count = ", enemies_defeated)
	print("DEBUG: Session count = ", Session.dungeon_enemies_defeated)

	enemies_defeated += 1
	Session.dungeon_enemies_defeated = enemies_defeated

	active_enemies = max(active_enemies - 1, 0)

	Session.record_mob_kill(10)

	print("Dungeon kills: ", enemies_defeated, "/", max_enemies_to_defeat)
	print("Active enemies: ", active_enemies)
	print("Global mob kills: ", Session.mobs_defeated)
	print("Global score: ", Session.score)

	update_enemy_counter()

	# Spawn the Minotaur instead of immediately starting the boss battle.
	if enemies_defeated >= max_enemies_to_defeat:
		print("DEBUG: Boss threshold reached!")
		spawn_minotaur()
		return

	# Continue spawning regular enemies until the threshold is reached.
	spawn_enemy()

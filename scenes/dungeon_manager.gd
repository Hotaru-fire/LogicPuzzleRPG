extends Node

@export var enemy_scene: PackedScene

var enemies_defeated := 0
var max_enemies_to_defeat := 10

var active_enemies := 0
var max_active_enemies := 5

#ON LOAD
func _ready():

	for i in range(max_active_enemies):
		spawn_enemy()
		


#ENEMY DEATH COUNTER DEBUG
func enemy_defeated():

	enemies_defeated += 1
	active_enemies -= 1

	print("Enemies defeated: ", enemies_defeated, "/", max_enemies_to_defeat)
	print("Active enemies: ", active_enemies)

	if enemies_defeated < max_enemies_to_defeat:
		spawn_enemy()


# ENEMY SPAWN
func spawn_enemy():

	if enemies_defeated >= max_enemies_to_defeat:
		return

	if active_enemies >= max_active_enemies:
		return

	var enemy = enemy_scene.instantiate()

	var spawn_points = $"../EnemySpawnPoints".get_children()

	var spawn_point = spawn_points.pick_random()

	enemy.global_position = spawn_point.global_position

	print("DungeonManager parent: ", get_parent().name)
	
	get_parent().add_child.call_deferred(enemy)
	
	active_enemies += 1

	print("Enemy spawned!")
	print("Active enemies: ", active_enemies)

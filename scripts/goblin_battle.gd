extends Node2D

const MEMORY_PUZZLE_SCENE = preload("res://scenes/battle/MemoryPuzzle.tscn")

var current_puzzle = null

# ENEMY DATA
var enemy_hp := 20
var enemy_damage := 10

# PLAYER DATA
var player_max_hp := 200
var player_hp := player_max_hp

var player_turn := true

@onready var boss_hp_bar = $CanvasLayer/BossUI/BossHPBar
@onready var player_hp_bar = $CanvasLayer/PlayerUI/PlayerHPBar
@onready var turn_label = $CanvasLayer/TurnLabel
@onready var attack_button = $CanvasLayer/Actions/AttackButton
@onready var boss_sprite = $Boss/AnimatedSprite2D
@onready var boss_ui = $CanvasLayer/BossUI
@onready var player_ui = $CanvasLayer/PlayerUI
@onready var actions = $CanvasLayer/Actions
@onready var dodge_popup = $CanvasLayer/DodgePopup
@onready var dodge_battle = $CanvasLayer/DodgePopup/DodgeBattle



func _ready():
	
	dodge_battle.player_hit.connect(_on_dodge_player_hit)
	
	# Get the Goblin's information
	enemy_hp = BattleData.enemy_hp
	enemy_damage = BattleData.enemy_damage

	print("Battle started!")
	print("Enemy: ", BattleData.enemy_name)
	print("Enemy HP: ", enemy_hp)
	print("Enemy Damage: ", enemy_damage)

	# Set enemy HP bar
	boss_hp_bar.max_value = enemy_hp
	boss_hp_bar.value = enemy_hp

	# Set player HP bar
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

	# Start enemy idle animation
	boss_sprite.play("idle")

	update_turn_ui()


func _on_dodge_player_hit():
	print("Goblin attack hit the player!")

	player_hp -= 10
	player_hp = max(player_hp, 0)

	player_hp_bar.value = player_hp

	if player_hp <= 0:
		player_defeated()


func update_turn_ui():

	if player_turn:

		turn_label.text = "PLAYER TURN"
		attack_button.disabled = false

	else:

		turn_label.text = "ENEMY TURN"
		attack_button.disabled = true


func _on_attack_button_pressed() -> void:

	if not player_turn:
		return

	print("Opening Memory Puzzle")

	attack_button.disabled = true

	boss_ui.visible = false
	player_ui.visible = false
	turn_label.visible = false
	actions.visible = false

	current_puzzle = MEMORY_PUZZLE_SCENE.instantiate()
	add_child(current_puzzle)

	current_puzzle.puzzle_finished.connect(_on_puzzle_finished)


func boss_turn():
	print("ENEMY TURN")
	start_dodge_phase()


func start_dodge_phase():
	print("Starting Goblin dodge phase!")

	attack_button.disabled = true
	actions.visible = false

	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true
	turn_label.text = "DODGE!"

	# Show the entire DodgePopup
	dodge_popup.visible = true

	# Start the dodge battle inside it
	dodge_battle.start_goblin_dodge()

	# Wait until dodge battle finishes
	await dodge_battle.dodge_finished

	# Hide the entire popup
	dodge_popup.visible = false

	# Return to player turn
	turn_label.text = "PLAYER TURN"
	actions.visible = true

	player_turn = true
	update_turn_ui()


func damage_boss(amount):

	enemy_hp -= amount
	enemy_hp = max(enemy_hp, 0)

	boss_hp_bar.value = enemy_hp

	boss_hit_effect()

	print("Enemy took ", amount, " damage")
	print("Enemy HP: ", enemy_hp)

	if enemy_hp <= 0:

		enemy_defeated()


func enemy_defeated():

	print("ENEMY DEFEATED!")

	turn_label.text = "ENEMY DEFEATED!"
	attack_button.disabled = true

	# Stop the enemy animation
	boss_sprite.stop()

	# Remove the defeated enemy from BattleData
	BattleData.enemy_defeated = true

	# Wait a moment before returning
	await get_tree().create_timer(1.0).timeout

	# Return to the dungeon
	get_tree().change_scene_to_file(BattleData.return_scene)


func player_defeated():

	print("PLAYER DEFEATED!")

	turn_label.text = "YOU WERE DEFEATED!"
	attack_button.disabled = true


func boss_hit_effect():

	boss_sprite.modulate = Color(1, 0.2, 0.2)

	await get_tree().create_timer(0.15).timeout

	boss_sprite.modulate = Color.WHITE


func _on_puzzle_finished(success: bool):

	print("Puzzle finished. Success: ", success)

	if success:

		damage_boss(30)

	else:

		print("Puzzle failed. Enemy takes no damage.")


	if current_puzzle:

		current_puzzle.queue_free()
		current_puzzle = null


	# Enemy was defeated
	if enemy_hp <= 0:

		return


	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true
	actions.visible = true

	player_turn = false

	update_turn_ui()

	$BattleTimer.start()

	await $BattleTimer.timeout

	boss_turn()

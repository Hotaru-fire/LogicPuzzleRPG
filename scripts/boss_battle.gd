extends Node2D

const MEMORY_PUZZLE_SCENE = preload("res://scenes/battle/MemoryPuzzle.tscn")

var current_puzzle = null

var boss_max_hp := 500
var boss_hp := boss_max_hp

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

func _ready():
	boss_hp_bar.max_value = boss_max_hp
	boss_hp_bar.value = boss_hp

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	
	boss_sprite.play("idle")
	
	update_turn_ui()


func update_turn_ui():
	if player_turn:
		turn_label.text = "PLAYER TURN"
		attack_button.disabled = false
	else:
		turn_label.text = "BOSS TURN"
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
	print("BOSS TURN")

	boss_sprite.play("attack")

	await boss_sprite.animation_finished

	var damage := 10
	player_hp -= damage

	if player_hp < 0:
		player_hp = 0

	player_hp_bar.value = player_hp

	print("Boss dealt ", damage, " damage")
	print("Player HP: ", player_hp)

	if player_hp <= 0:
		player_defeated()
		return

	boss_sprite.play("idle")

	player_turn = true
	update_turn_ui()

func damage_boss(amount):
	boss_hp -= amount
	boss_hp = max(boss_hp, 0)

	boss_hp_bar.value = boss_hp

	boss_hit_effect()

	print("Boss took ", amount, " damage")
	print("Boss HP: ", boss_hp)

	if boss_hp <= 0:
		boss_defeated()


func boss_defeated():
	print("BOSS DEFEATED!")

	turn_label.text = "BOSS DEFEATED!"
	attack_button.disabled = true


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
		print("Puzzle failed. Boss takes no damage.")

	if current_puzzle:
		current_puzzle.queue_free()
		current_puzzle = null

	if boss_hp <= 0:
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

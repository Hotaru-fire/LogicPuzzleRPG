extends Node2D

const MEMORY_PUZZLE_SCENE = preload("res://scenes/battle/MemoryPuzzle.tscn")

var current_puzzle = null

var boss_max_hp := 500
var boss_hp := boss_max_hp

var player_max_hp := 200
var player_hp := player_max_hp

var player_turn := true
var battle_ended := false
var player_hit_effect_running := false
var boss_hit_effect_running := false

@onready var boss_hp_bar = $CanvasLayer/BossUI/BossHPBar
@onready var player_hp_bar = $CanvasLayer/PlayerUI/PlayerHPBar
@onready var turn_label = $CanvasLayer/TurnLabel
@onready var attack_button = $CanvasLayer/Actions/AttackButton

@onready var boss_sprite: AnimatedSprite2D = $Boss/AnimatedSprite2D
@onready var player_sprite: AnimatedSprite2D = $player/AnimatedSprite2D

@onready var player_name_label: Label = \
	$CanvasLayer/PlayerUI/PlayerNameLabel

@onready var boss_ui = $CanvasLayer/BossUI
@onready var player_ui = $CanvasLayer/PlayerUI
@onready var actions = $CanvasLayer/Actions

@onready var dodge_popup = $CanvasLayer/DodgePopup
@onready var dodge_battle = $CanvasLayer/DodgePopup/DodgeBattle


func _ready():
	dodge_battle.player_hit.connect(_on_dodge_player_hit)

	boss_hp_bar.max_value = boss_max_hp
	boss_hp_bar.value = boss_hp

	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp

	player_name_label.text = Session.username

	boss_sprite.play("idle")
	player_sprite.play("idle_right")

	dodge_popup.visible = false

	update_turn_ui()


func update_turn_ui():
	if battle_ended:
		attack_button.disabled = true
		return

	if player_turn:
		turn_label.text = "PLAYER TURN"
		attack_button.disabled = false
	else:
		turn_label.text = "BOSS TURN"
		attack_button.disabled = true


func _on_attack_button_pressed() -> void:
	if not player_turn or battle_ended:
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


func _on_puzzle_finished(success: bool):
	if battle_ended:
		return

	print("Puzzle finished. Success: ", success)

	if current_puzzle:
		current_puzzle.queue_free()
		current_puzzle = null

	if success:
		# Wait one second before the player attacks.
		await get_tree().create_timer(1.0).timeout

		if battle_ended:
			return

		player_sprite.play("attack_right")

		# Wait for the non-looping attack animation to finish.
		await player_sprite.animation_finished

		if battle_ended:
			return

		player_sprite.play("idle_right")
		damage_boss(30)
	else:
		print("Puzzle failed! Boss takes no damage.")

	if battle_ended:
		return

	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true
	actions.visible = true

	player_turn = false
	update_turn_ui()

	$BattleTimer.start()
	await $BattleTimer.timeout

	if not battle_ended:
		boss_turn()


func damage_boss(amount: int):
	if battle_ended:
		return

	boss_hp = max(boss_hp - amount, 0)
	boss_hp_bar.value = boss_hp

	print("Boss took ", amount, " damage")
	print("Boss HP: ", boss_hp)

	if boss_hp <= 0:
		await boss_defeated()
	else:
		boss_hit_effect()


func boss_hit_effect():
	if boss_hit_effect_running or battle_ended:
		return

	boss_hit_effect_running = true
	boss_sprite.modulate = Color(1.0, 0.2, 0.2)

	await get_tree().create_timer(0.15).timeout

	if is_instance_valid(boss_sprite):
		boss_sprite.modulate = Color.WHITE

	boss_hit_effect_running = false


func boss_turn():
	if battle_ended:
		return

	print("BOSS TURN")
	start_dodge_phase()


func start_dodge_phase():
	if battle_ended:
		return

	attack_button.disabled = true
	actions.visible = false

	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true

	turn_label.text = "DODGE!"

	dodge_popup.visible = true
	dodge_battle.start_boss_dodge()

	await dodge_battle.dodge_finished

	if battle_ended:
		return

	dodge_popup.visible = false

	turn_label.text = "PLAYER TURN"
	actions.visible = true

	player_turn = true
	update_turn_ui()


func _on_dodge_player_hit():
	if battle_ended:
		return

	print("Boss attack hit the player!")

	# Delay the boss's attack animation by one second.
	await get_tree().create_timer(1.0).timeout

	if battle_ended:
		return

	boss_sprite.play("attack")

	# Apply the damage after the attack animation.
	await boss_sprite.animation_finished

	if battle_ended:
		return

	boss_sprite.play("idle")

	player_hp = max(player_hp - 10, 0)
	player_hp_bar.value = player_hp

	player_hit_effect()

	print("Player HP: ", player_hp)

	if player_hp <= 0:
		await player_defeated()


func player_hit_effect():
	if player_hit_effect_running:
		return

	player_hit_effect_running = true

	# Brief red flash when the player takes damage.
	player_sprite.modulate = Color(1.0, 0.15, 0.15)

	await get_tree().create_timer(0.2).timeout

	if is_instance_valid(player_sprite) and player_hp > 0:
		player_sprite.modulate = Color.WHITE

	player_hit_effect_running = false


func boss_defeated():
	if battle_ended:
		return

	battle_ended = true

	print("BOSS DEFEATED!")

	turn_label.text = "BOSS DEFEATED!"
	attack_button.disabled = true
	actions.visible = false

	# Wait one second, then play the boss's hurt animation.
	await get_tree().create_timer(1.0).timeout

	boss_sprite.play("hurt")


func player_defeated():
	if battle_ended:
		return

	battle_ended = true

	print("PLAYER DEFEATED!")

	turn_label.text = "YOU WERE DEFEATED!"
	attack_button.disabled = true
	actions.visible = false

	# Wait one second, then play the player's hurt animation.
	await get_tree().create_timer(1.0).timeout

	player_sprite.modulate = Color.WHITE
	player_sprite.play("hurt")


func load_selected_character():
	match PlayerData.selected_character:
		1:
			player_sprite.sprite_frames = preload("res://resources/player characters/Knight.tres")
		2:
			player_sprite.sprite_frames = preload("res://resources/player characters/Mage.tres")
		3:
			push_warning("Rogue SpriteFrames not created yet. Using Mage.")
			player_sprite.sprite_frames = preload("res://resources/player characters/Mage.tres")
		4:
			player_sprite.sprite_frames = preload("res://resources/player characters/Archer.tres")
		_:
			player_sprite.sprite_frames = preload("res://resources/player characters/Mage.tres")

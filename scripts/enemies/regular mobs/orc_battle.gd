extends Node2D

const MEMORY_PUZZLE_SCENE = preload("res://scenes/battle/MemoryPuzzle.tscn")

var current_puzzle = null

# ENEMY DATA
var enemy_hp := 20
var enemy_damage := 10

# PLAYER DATA
var player_max_hp: int:
	get:
		return PlayerData.current_max_hp
	set(value):
		PlayerData.set_max_hp(value)
var player_hp: int:
	get:
		return PlayerData.current_hp
	set(value):
		PlayerData.set_current_hp(value)

# BATTLE STATE
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
	if not dodge_battle.player_hit.is_connected(_on_dodge_player_hit):
		dodge_battle.player_hit.connect(_on_dodge_player_hit)
	if not PlayerData.health_changed.is_connected(_on_player_health_changed):
		PlayerData.health_changed.connect(_on_player_health_changed)

	load_selected_character()

	# Get the orc's information.
	enemy_hp = BattleData.enemy_hp
	enemy_damage = BattleData.enemy_damage

	print("Orc battle started!")
	print("Enemy: ", BattleData.enemy_name)
	print("Enemy HP: ", enemy_hp)
	print("Enemy Damage: ", enemy_damage)

	boss_hp_bar.max_value = enemy_hp
	boss_hp_bar.value = enemy_hp

	_on_player_health_changed(player_hp, player_max_hp)

	player_name_label.text = Session.username

	boss_sprite.play("idle")
	player_sprite.play("idle_right")

	dodge_popup.visible = false

	update_turn_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F6:
				if not battle_ended:
					print("CHEAT ACTIVATED: INSTANT KILL!")
					await damage_boss(enemy_hp)


func update_turn_ui():
	if battle_ended:
		attack_button.disabled = true
		return

	if player_turn:
		turn_label.text = "PLAYER TURN"
		attack_button.disabled = false
	else:
		turn_label.text = "ENEMY TURN"
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

	if is_instance_valid(current_puzzle):
		current_puzzle.queue_free()
		current_puzzle = null

	if success:
		await get_tree().create_timer(1.0).timeout

		if battle_ended:
			return

		player_sprite.play("attack_right")

		await player_sprite.animation_finished

		if battle_ended:
			return

		player_sprite.play("idle_right")

		await damage_boss(30)

		if battle_ended:
			return
	else:
		print("Puzzle failed! Orc takes no damage.")

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

	enemy_hp = max(enemy_hp - amount, 0)
	boss_hp_bar.value = enemy_hp

	print("Orc took ", amount, " damage")
	print("Orc HP: ", enemy_hp)

	if enemy_hp <= 0:
		await enemy_defeated()
	else:
		await boss_hit_effect()


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

	print("ORC TURN")
	start_dodge_phase()


func start_dodge_phase():
	if battle_ended:
		return

	print("Starting Orc dodge phase!")

	attack_button.disabled = true
	actions.visible = false

	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true
	turn_label.text = "DODGE!"

	dodge_popup.visible = true

	# Orc-specific attack patterns
	dodge_battle.start_orc_dodge()

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

	print("Orc attack hit the player!")

	await get_tree().create_timer(1.0).timeout

	if battle_ended:
		return

	boss_sprite.play("attack")

	await boss_sprite.animation_finished

	if battle_ended:
		return

	boss_sprite.play("idle")

	player_hp = max(player_hp - enemy_damage, 0)

	print("Player HP: ", player_hp)

	await player_hit_effect()

	if player_hp <= 0:
		await player_defeated()
	elif Session.is_logged_in():
		GameAPI.save_progress()


func _on_player_health_changed(current_hp: int, maximum_hp: int) -> void:
	player_hp_bar.max_value = maximum_hp
	player_hp_bar.value = current_hp


func player_hit_effect():
	if player_hit_effect_running or battle_ended:
		return

	player_hit_effect_running = true

	player_sprite.modulate = Color(1.0, 0.15, 0.15)

	await get_tree().create_timer(0.2).timeout

	if is_instance_valid(player_sprite) and player_hp > 0:
		player_sprite.modulate = Color.WHITE

	player_hit_effect_running = false


func enemy_defeated():
	if battle_ended:
		return

	battle_ended = true

	print("ORC DEFEATED!")
	BattleData.enemy_defeated = true

	turn_label.visible = true
	turn_label.text = "ENEMY DEFEATED!"

	attack_button.disabled = true
	actions.visible = false

	boss_sprite.modulate = Color.WHITE

	await get_tree().create_timer(1.0).timeout

	if not is_instance_valid(self):
		return

	if is_instance_valid(boss_sprite):
		if boss_sprite.sprite_frames.has_animation("hurt"):
			boss_sprite.play("hurt")
		else:
			boss_sprite.stop()

	var should_save_progress := false
	var kill_recorded := false
	if BattleData.has_meta("enemy_spawn_id"):
		var spawn_id := str(BattleData.get_meta("enemy_spawn_id", ""))
		if not spawn_id.is_empty():
			should_save_progress = Session.record_cleared_spawn(spawn_id)

	if not BattleData.kill_counted:
		BattleData.kill_counted = true
		kill_recorded = true

		if BattleData.enemy_is_dungeon:
			Session.record_dungeon_enemy_kill(
				BattleData.enemy_exp_reward,
				BattleData.enemy_gold_reward,
				BattleData.enemy_score_reward
			)
			print("DUNGEON KILLS: ", Session.dungeon_enemies_defeated, "/10")
		else:
			Session.record_normal_mob_kill(
				BattleData.enemy_exp_reward,
				BattleData.enemy_gold_reward,
				BattleData.enemy_score_reward
			)
		should_save_progress = true

	if should_save_progress:
		if Session.is_logged_in():
			print("Saving enemy kill and reward data to database...")
			if not GameAPI.save_progress():
				push_error(
					"Could not start saving the enemy kill and cleared spawn."
				)
		elif kill_recorded:
			print("WARNING: Not logged in; kill count was not saved.")
		else:
			print("WARNING: Not logged in; cleared spawn was not saved.")

	await get_tree().create_timer(1.0).timeout

	if not is_instance_valid(self):
		return

	print("Returning to dungeon: ", BattleData.return_scene)

	if not BattleData.return_scene.is_empty():
		get_tree().change_scene_to_file(BattleData.return_scene)
	else:
		push_error("Cannot return to dungeon: BattleData.return_scene is empty!")


func player_defeated():
	if battle_ended:
		return

	battle_ended = true

	print("PLAYER DEFEATED!")

	turn_label.visible = true
	turn_label.text = "YOU WERE DEFEATED!"

	attack_button.disabled = true
	actions.visible = false
	Session.begin_player_death()


func load_selected_character():
	match PlayerData.selected_character:
		1:
			player_sprite.sprite_frames = preload(
				"res://resources/player characters/Knight.tres"
			)
		2:
			player_sprite.sprite_frames = preload(
				"res://resources/player characters/Mage.tres"
			)
		3:
			push_warning("Rogue SpriteFrames not created yet. Using Mage.")
			player_sprite.sprite_frames = preload(
				"res://resources/player characters/Mage.tres"
			)
		4:
			player_sprite.sprite_frames = preload(
				"res://resources/player characters/Archer.tres"
			)
		_:
			player_sprite.sprite_frames = preload(
				"res://resources/player characters/Mage.tres"
			)

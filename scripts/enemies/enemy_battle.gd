extends Node2D

const MEMORY_PUZZLE_SCENE = preload("res://scenes/battle/MemoryPuzzle.tscn")
const ENEMY_SPRITE_FRAMES: Dictionary[String, SpriteFrames] = {
	"goblin": preload("res://resources/mobs/Goblin.tres"),
	"orc": preload("res://resources/mobs/orc.tres"),
	"boss": preload("res://resources/mobs/Minotaur.tres")
}

var current_puzzle = null
var enemy_hp := 20
var enemy_damage := 10
var enemy_type := ""

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

var player_turn := true
var battle_ended := false
var player_hit_effect_running := false
var boss_hit_effect_running := false

@onready var boss_hp_bar: ProgressBar = \
	$CanvasLayer/MarginContainerBoss/BossUI/BossHPBar
@onready var player_hp_bar: ProgressBar = \
	$CanvasLayer/MarginContainerPlayer/PlayerUI/PlayerHPBar
@onready var turn_label: Label = $CanvasLayer/TurnLabel
@onready var attack_button: Button = \
	$CanvasLayer/Actions/HBoxContainer/AttackButton
@onready var enemy_sprite: AnimatedSprite2D = $Enemy/AnimatedSprite2D
@onready var player_sprite: AnimatedSprite2D = $player/AnimatedSprite2D
@onready var enemy_name_label: Label = \
	$CanvasLayer/MarginContainerBoss/BossUI/BossNameLabel
@onready var player_name_label: Label = \
	$CanvasLayer/MarginContainerPlayer/PlayerUI/PlayerNameLabel
@onready var boss_ui: Control = $CanvasLayer/MarginContainerBoss/BossUI
@onready var player_ui: Control = $CanvasLayer/MarginContainerPlayer/PlayerUI
@onready var actions: Control = $CanvasLayer/Actions
@onready var dodge_popup: Control = $CanvasLayer/DodgePopup
@onready var dodge_battle: Control = $CanvasLayer/DodgePopup/DodgeBattle


func _ready() -> void:
	enemy_type = _resolve_enemy_type()
	if not _load_enemy_sprite_frames():
		attack_button.disabled = true
		return

	if not dodge_battle.player_hit.is_connected(_on_dodge_player_hit):
		dodge_battle.player_hit.connect(_on_dodge_player_hit)
	if not PlayerData.health_changed.is_connected(_on_player_health_changed):
		PlayerData.health_changed.connect(_on_player_health_changed)

	enemy_hp = maxi(BattleData.enemy_hp, 1)
	enemy_damage = maxi(BattleData.enemy_damage, 0)
	if (
		enemy_type == "boss"
		and BattleData.enemy == null
		and BattleData.enemy_name.is_empty()
	):
		enemy_hp = 500
	boss_hp_bar.max_value = enemy_hp
	boss_hp_bar.value = enemy_hp
	match enemy_type:
		"goblin":
			enemy_name_label.text = "GOBLIN"
		"orc":
			enemy_name_label.text = "ORC"
		_:
			enemy_name_label.text = (
				BattleData.enemy_name.to_upper()
				if not BattleData.enemy_name.is_empty()
				else enemy_type.to_upper()
			)

	_on_player_health_changed(player_hp, player_max_hp)
	player_name_label.text = Session.username
	load_selected_character()

	enemy_sprite.stop()
	enemy_sprite.frame = 0
	enemy_sprite.frame_progress = 0.0
	if enemy_type in ["goblin", "orc"]:
		enemy_sprite.position = Vector2(975, 270)
		enemy_sprite.scale = Vector2(3, 3)
	_play_enemy_idle()
	player_sprite.play("idle_right")
	dodge_popup.visible = false
	update_turn_ui()


func _resolve_enemy_type() -> String:
	var resolved_type := BattleData.enemy_type.strip_edges().to_lower()
	if not resolved_type.is_empty():
		return resolved_type

	var identity := BattleData.enemy_name.to_lower()
	if identity.contains("orc"):
		return "orc"
	if identity.contains("goblin") or identity.contains("dummy"):
		return "goblin"
	if identity.contains("boss") or identity.contains("minotaur"):
		return "boss"

	if is_instance_valid(BattleData.enemy):
		var scene_path: String = BattleData.enemy.scene_file_path.to_lower()
		if scene_path.contains("orc"):
			return "orc"
		if scene_path.contains("goblin"):
			return "goblin"

	return "boss"


func _load_enemy_sprite_frames() -> bool:
	var frames: SpriteFrames
	if BattleData.enemy_sprite_frames_type == enemy_type:
		frames = BattleData.enemy_sprite_frames
	if frames == null and ENEMY_SPRITE_FRAMES.has(enemy_type):
		frames = ENEMY_SPRITE_FRAMES[enemy_type]
	if frames == null:
		push_error(
			"No SpriteFrames were supplied for enemy type '%s'." % enemy_type
		)
		return false

	enemy_sprite.sprite_frames = frames
	return true


func _play_enemy_idle() -> void:
	if enemy_sprite.sprite_frames == null:
		return

	for animation in [
		&"idle",
		&"default_Idle",
		&"idle_left",
		&"idle_right",
		&"idle_down",
		&"idle_up"
	]:
		if enemy_sprite.sprite_frames.has_animation(animation):
			enemy_sprite.play(animation)
			return

	enemy_sprite.stop()


func _play_enemy_attack() -> void:
	if (
		enemy_sprite.sprite_frames == null
		or not enemy_sprite.sprite_frames.has_animation("attack")
	):
		_play_enemy_idle()
		return

	enemy_sprite.play("attack")
	await enemy_sprite.animation_finished
	if not battle_ended:
		_play_enemy_idle()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F6 and not battle_ended:
			print("CHEAT ACTIVATED: INSTANT KILL!")
			await damage_boss(enemy_hp)


func update_turn_ui() -> void:
	if battle_ended:
		attack_button.disabled = true
		return

	if player_turn:
		turn_label.text = "PLAYER TURN"
		attack_button.disabled = false
	else:
		turn_label.text = "ENEMY TURN" if enemy_type != "boss" else "BOSS TURN"
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
	$CanvasLayer.add_child(current_puzzle)
	current_puzzle.puzzle_finished.connect(_on_puzzle_finished)


func _on_puzzle_finished(success: bool) -> void:
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
		if enemy_type == "boss":
			damage_boss(30)
		else:
			await damage_boss(30)
	else:
		print("Puzzle failed! ", enemy_type.capitalize(), " takes no damage.")

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


func damage_boss(amount: int) -> void:
	if battle_ended:
		return

	enemy_hp = maxi(enemy_hp - amount, 0)
	boss_hp_bar.value = enemy_hp
	print(enemy_type.capitalize(), " took ", amount, " damage")
	print(enemy_type.capitalize(), " HP: ", enemy_hp)

	if enemy_hp <= 0:
		if enemy_type == "boss":
			await boss_defeated()
		else:
			await enemy_defeated()
	elif enemy_type == "boss":
		boss_hit_effect()
	else:
		await boss_hit_effect()


func boss_hit_effect() -> void:
	if boss_hit_effect_running or battle_ended:
		return

	boss_hit_effect_running = true
	enemy_sprite.modulate = Color(1.0, 0.2, 0.2)
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(enemy_sprite):
		enemy_sprite.modulate = Color.WHITE
	boss_hit_effect_running = false


func boss_turn() -> void:
	if battle_ended:
		return

	print(enemy_type.to_upper(), " TURN")
	start_dodge_phase()


func start_dodge_phase() -> void:
	if battle_ended:
		return

	attack_button.disabled = true
	actions.visible = false
	boss_ui.visible = true
	player_ui.visible = true
	turn_label.visible = true
	turn_label.text = "DODGE!"
	dodge_popup.visible = true

	match enemy_type:
		"goblin":
			dodge_battle.start_goblin_dodge()
		"orc":
			dodge_battle.start_orc_dodge()
		_:
			dodge_battle.start_boss_dodge()

	await dodge_battle.dodge_finished
	if battle_ended:
		return

	dodge_popup.visible = false
	turn_label.text = "PLAYER TURN"
	actions.visible = true
	player_turn = true
	update_turn_ui()


func _on_dodge_player_hit() -> void:
	if battle_ended:
		return

	print(enemy_type.capitalize(), " attack hit the player!")
	await get_tree().create_timer(1.0).timeout
	if battle_ended:
		return

	await _play_enemy_attack()
	if battle_ended:
		return

	player_hp = maxi(player_hp - enemy_damage, 0)
	print("Player HP: ", player_hp)
	if enemy_type == "boss":
		player_hit_effect()
	else:
		await player_hit_effect()

	if player_hp <= 0:
		await player_defeated()
	elif Session.is_logged_in() and not GameAPI.save_progress():
		push_error("Could not start saving player HP after an enemy attack.")


func _on_player_health_changed(current_hp: int, maximum_hp: int) -> void:
	player_hp_bar.max_value = maximum_hp
	player_hp_bar.value = current_hp


func player_hit_effect() -> void:
	if player_hit_effect_running:
		return

	player_hit_effect_running = true
	player_sprite.modulate = Color(1.0, 0.15, 0.15)
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(player_sprite) and player_hp > 0:
		player_sprite.modulate = Color.WHITE
	player_hit_effect_running = false


func enemy_defeated() -> void:
	if battle_ended:
		return

	battle_ended = true
	BattleData.enemy_defeated = true
	print(enemy_type.to_upper(), " DEFEATED!")
	turn_label.visible = true
	turn_label.text = "ENEMY DEFEATED!"
	attack_button.disabled = true
	actions.visible = false
	enemy_sprite.modulate = Color.WHITE

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	if is_instance_valid(enemy_sprite):
		if enemy_sprite.sprite_frames.has_animation("hurt"):
			enemy_sprite.play("hurt")
		else:
			enemy_sprite.stop()

	var should_save_progress := false
	var kill_recorded := false
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
			print(
				"DUNGEON KILLS: ",
				Session.dungeon_enemies_defeated,
				"/10"
			)
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
				push_error("Could not start saving the enemy kill and cleared spawn.")
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


func boss_defeated() -> void:
	if battle_ended:
		return

	battle_ended = true
	BattleData.enemy_defeated = true
	BattleData.kill_counted = true
	print("BOSS DEFEATED!")
	turn_label.visible = true
	turn_label.text = "BOSS DEFEATED!"
	attack_button.disabled = true
	actions.visible = false

	PlayerData.saved_boss_completed = true
	PlayerData.saved_hp = player_hp
	PlayerData.saved_current_scene = BattleData.return_scene
	PlayerData.saved_position = BattleData.return_position
	Session.record_boss_kill()

	print("TOTAL BOSSES KILLED: ", Session.bosses_killed)
	print("TOTAL MOBS DEFEATED: ", Session.mobs_defeated)
	print("BOSS COMPLETED: ", PlayerData.saved_boss_completed)
	if Session.is_logged_in():
		print("Saving boss progress to database...")
		if not GameAPI.save_progress():
			push_error("Could not start saving boss completion and rewards.")
	else:
		print("WARNING: Not logged in. Boss progress was not saved.")

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return
	if is_instance_valid(enemy_sprite):
		if enemy_sprite.sprite_frames.has_animation("hurt"):
			enemy_sprite.play("hurt")
		else:
			enemy_sprite.stop()


func player_defeated() -> void:
	if battle_ended:
		return

	battle_ended = true
	print("PLAYER DEFEATED!")
	turn_label.text = "YOU WERE DEFEATED!"
	attack_button.disabled = true
	actions.visible = false
	Session.begin_player_death()


func load_selected_character() -> void:
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

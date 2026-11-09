extends CharacterBody2D

@export var hp := 20

@export var speed := 50.0
@export var return_speed := 70.0
@export var damage := 10
@export var exp_reward := 25
@export var gold_reward := 8
@export var score_reward := 10
@export var attack_cooldown := 1.0
@export var attack_range := 45.0

# How far from its spawn point the orc may chase before giving up
@export var max_chase_distance := 250.0

# BATTLE SCENE
@export var battle_scene: PackedScene
@export var battle_enemy_type := "orc"
var battle_started := false
var death_processed := false

@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var animated_sprite = $EnemySprite

var player = null
var attack_timer := 0.0

var home_position := Vector2.ZERO
var returning_home := false
var dungeon_level := 1
var _base_hp := -1
var _base_damage := -1

var facing_direction := Vector2.DOWN


func set_dungeon_level(level: int) -> void:
	dungeon_level = clampi(level, 1, Session.MAX_DUNGEON_LEVEL)
	if _base_hp < 0:
		_base_hp = hp
	if _base_damage < 0:
		_base_damage = damage
	hp = Session.scale_dungeon_stat(_base_hp, level, 1)
	damage = Session.scale_dungeon_stat(_base_damage, level)


func _ready():
	# Remember where the orc spawned
	home_position = global_position


func _physics_process(delta):

	attack_timer -= delta

	if battle_started:
		return

	# Track the player directly; the tutorial can end beyond the detector's
	# small area, while still within this orc's configured chase radius.
	player = get_tree().get_first_node_in_group("player")

	var distance_from_home = global_position.distance_to(home_position)

	returning_home = (
		player == null
		or player.global_position.distance_to(home_position) > max_chase_distance
	)

	# RETURN HOME
	if returning_home:
		if distance_from_home <= 5.0:
			velocity = Vector2.ZERO
			play_idle_animation()
			move_and_slide()
			return
		return_to_home()
		return

	# CHASE PLAYER
	if player != null:

		var direction = player.global_position - global_position
		var distance = direction.length()

		if distance > 0:
			direction = direction.normalized()

		facing_direction = get_4_direction(direction)
		update_attack_area()

		if distance > attack_range:
			velocity = direction * speed
			play_walk_animation()
			move_and_slide()
		else:
			velocity = Vector2.ZERO
			play_idle_animation()
			start_battle()

	# STATIONARY
	else:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()


func return_to_home():

	var direction = home_position - global_position

	if direction.length() <= 5.0:
		global_position = home_position
		velocity = Vector2.ZERO
		returning_home = false
		play_idle_animation()
		return

	direction = direction.normalized()

	facing_direction = get_4_direction(direction)
	update_attack_area()

	velocity = direction * return_speed

	play_walk_animation()
	move_and_slide()


func get_4_direction(direction: Vector2) -> Vector2:

	if abs(direction.x) > abs(direction.y):
		return Vector2.RIGHT if direction.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if direction.y > 0 else Vector2.UP


func update_attack_area():
	attack_area.position = facing_direction * 30


func play_walk_animation():

	if facing_direction == Vector2.RIGHT:
		animated_sprite.play("walk_right")
	elif facing_direction == Vector2.LEFT:
		animated_sprite.play("walk_left")
	elif facing_direction == Vector2.UP:
		animated_sprite.play("walk_up")
	elif facing_direction == Vector2.DOWN:
		animated_sprite.play("walk_down")


func play_idle_animation():

	if facing_direction == Vector2.RIGHT:
		animated_sprite.play("idle_right")
	elif facing_direction == Vector2.LEFT:
		animated_sprite.play("idle_left")
	elif facing_direction == Vector2.UP:
		animated_sprite.play("idle_up")
	elif facing_direction == Vector2.DOWN:
		animated_sprite.play("idle_down")


func attack_player():

	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown

	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			print("Enemy detected player!")
			start_battle()
			break


func start_battle():

	if battle_started:
		return
	if Time.get_ticks_msec() < BattleData.battle_return_grace_until_msec:
		return

	battle_started = true
	BattleData.enemy_defeated = false
	BattleData.kill_counted = false
	BattleData.enemy_type = battle_enemy_type.strip_edges().to_lower()
	BattleData.enemy_sprite_frames = animated_sprite.sprite_frames
	BattleData.enemy_sprite_frames_type = BattleData.enemy_type
	BattleData.enemy_is_dungeon = (
		get_tree().get_first_node_in_group("dungeon_manager") != null
	)
	BattleData.returning_from_battle = BattleData.enemy_is_dungeon
	if BattleData.enemy_is_dungeon:
		var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager")
		dungeon_manager.call("capture_room_enemies_for_battle", self)

	print("Starting battle with ", name)

	velocity = Vector2.ZERO

	# Save this Orc's information
	BattleData.enemy = self
	BattleData.set_meta("enemy_spawn_id", get_meta("spawn_id", ""))
	BattleData.enemy_name = name
	BattleData.enemy_level = dungeon_level
	BattleData.enemy_hp = hp
	BattleData.enemy_damage = damage
	BattleData.enemy_exp_reward = exp_reward
	BattleData.enemy_gold_reward = gold_reward
	BattleData.enemy_score_reward = score_reward

	if player:
		BattleData.return_position = player.global_position

	BattleData.return_scene = get_tree().current_scene.scene_file_path

	if battle_scene:
		get_tree().change_scene_to_packed(battle_scene)
	else:
		print("ERROR: Battle Scene has not been assigned!")


func flash_red():

	$EnemySprite.modulate = Color.RED

	await get_tree().create_timer(0.15).timeout

	$EnemySprite.modulate = Color.WHITE


func take_damage(_amount):

	if battle_started:
		return

	print("Enemy was hit by player!")
	start_battle()


func die():
	if death_processed:
		return

	death_processed = true
	print("ENEMY DEFEATED!")

	var dungeon_manager = get_tree().get_first_node_in_group("dungeon_manager")

	if dungeon_manager != null:
		dungeon_manager.enemy_defeated(exp_reward, gold_reward, score_reward)
	else:
		Session.record_normal_mob_kill(exp_reward, gold_reward, score_reward)
		if Session.is_logged_in():
			GameAPI.save_progress()

	queue_free()

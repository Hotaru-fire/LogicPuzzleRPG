extends CharacterBody2D

@export var speed := 200.0

@onready var knight = $Knight
@onready var attack_area = $AttackArea
@onready var skill_1_area = $Skill1Area

var last_direction := Vector2.DOWN
var is_attacking := false
var restoring_battle_position := false

# FOOTSTEPS
@onready var footstep_sound = $FootstepSound

var footstep_timer := 0.0
@export var footstep_interval := 0.35

# CHARACTER STATS
@export var max_hp := 200
@export var max_mana := 100

var hp := 200
var mana := 100

@export var attack := 30
@export var defense := 10
@export var strength := 20

var base_attack := 30
var base_defense := 10

@onready var hit_sound = $HitSound
@onready var hurt_sound = $HurtSound

# A KNIGHT'S OATH
var honor := 0
var max_honor := 6
var honor_cooldown := 0.0
var honor_max_timer := 0.0

# SKILL COOLDOWNS
var skill_1_cooldown := 0.0
var skill_2_cooldown := 0.0
var skill_3_cooldown := 0.0

var skill_1_max_cooldown := 3.0
var skill_2_max_cooldown := 15.0
var skill_3_max_cooldown := 30.0

@export var skill_3_bonus_per_honor := 5.0

var skill_3_active := false
var skill_3_duration := 0.0

# SKILL 2
var skill_2_active := false
var skill_2_duration := 0.0
var skill_2_heal_timer := 0.0


func _ready() -> void:
	print("PLAYER SELECTED CHARACTER: ", PlayerData.selected_character)

	match PlayerData.selected_character:
		1:
			knight.sprite_frames = preload("res://resources/player characters/Knight.tres")
		2:
			knight.sprite_frames = preload("res://resources/player characters/Mage.tres")
		3:
			knight.sprite_frames = preload("res://resources/player characters/Mage.tres")
		4:
			knight.sprite_frames = preload("res://resources/player characters/Archer.tres")

	print("SpriteFrames currently loaded: ", knight.sprite_frames.resource_path)
	print("Current animation: ", knight.animation)
	print("Current frame: ", knight.frame)

	if PlayerData.has_save_data:
		if PlayerData.saved_max_hp > 0:
			max_hp = PlayerData.saved_max_hp

		attack = PlayerData.saved_attack
		defense = PlayerData.saved_defense

		hp = clampi(PlayerData.saved_hp, 0, max_hp)

		# Mana is not loaded from the database.
		mana = max_mana

		if not restoring_battle_position:
			global_position = PlayerData.saved_position
	else:
		hp = max_hp
		mana = max_mana

	update_attack_area()


func _physics_process(delta: float) -> void:
	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()

	# FOOTSTEPS
	if direction != Vector2.ZERO and not is_attacking:
		footstep_timer -= delta

		if footstep_timer <= 0:
			footstep_sound.play()
			footstep_timer = footstep_interval
	else:
		footstep_timer = 0.0

	# CANCEL ATTACK IF PLAYER MOVES
	if is_attacking and direction != Vector2.ZERO:
		is_attacking = false
		last_direction = direction
		update_attack_area()

	if is_attacking:
		return

	# NORMAL MOVEMENT
	if direction != Vector2.ZERO:
		last_direction = direction
		update_attack_area()

		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				knight.play("walk_right")
			else:
				knight.play("walk_left")
		else:
			if direction.y > 0:
				knight.play("walk_down")
			else:
				knight.play("walk_up")
	else:
		# IDLE
		if last_direction.x > 0:
			knight.play("idle_right")
		elif last_direction.x < 0:
			knight.play("idle_left")
		elif last_direction.y > 0:
			knight.play("idle_down")
		else:
			knight.play("idle_up")


func update_attack_area() -> void:
	if last_direction.x > 0:
		attack_area.position = Vector2(40, 0)
	elif last_direction.x < 0:
		attack_area.position = Vector2(-40, 0)
	elif last_direction.y > 0:
		attack_area.position = Vector2(0, 40)
	elif last_direction.y < 0:
		attack_area.position = Vector2(0, -40)


func take_damage(amount: int) -> void:
	var actual_damage = max(amount - defense, 1)
	hp -= actual_damage

	flash_red()
	hurt_sound.play()

	print("Player HP: ", hp, "/", max_hp)

	if hp <= 0:
		die()


func flash_red() -> void:
	knight.modulate = Color.RED
	await get_tree().create_timer(0.15).timeout

	if is_instance_valid(knight):
		knight.modulate = Color.WHITE


func heal(amount: int) -> void:
	hp += amount
	hp = min(hp, max_hp)

	flash_green()
	print("Player HP: ", hp, "/", max_hp)


func flash_green() -> void:
	knight.modulate = Color.GREEN
	await get_tree().create_timer(0.15).timeout

	if is_instance_valid(knight):
		knight.modulate = Color.WHITE


func gain_honor() -> void:
	if honor_cooldown > 0:
		return

	if honor >= max_honor:
		return

	honor += 1
	honor_cooldown = 1.0

	print("Honor: ", honor, "/", max_honor)


func use_mana(amount: int) -> bool:
	if mana < amount:
		print("Not enough mana!")
		return false

	mana -= amount
	print("Player Mana: ", mana, "/", max_mana)
	return true


func die() -> void:
	print("Player died!")
	hp = 0

	await get_tree().create_timer(2.0).timeout
	respawn()


func respawn() -> void:
	var respawn_point = get_parent().get_node_or_null("RespawnPoint")

	if respawn_point == null:
		push_error("RespawnPoint was not found!")
		return

	global_position = respawn_point.global_position
	hp = max_hp
	mana = max_mana

	print("Player respawned!")


@onready var stats_panel = $"../CanvasLayer/StatsPanel"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("basic_attack"):
		basic_attack()

	if event.is_action_pressed("open_stats"):
		stats_panel.visible = not stats_panel.visible


func basic_attack() -> void:
	if is_attacking:
		return

	is_attacking = true

	print("Basic attack!")

	if last_direction.x > 0:
		knight.play("attack_right")
	elif last_direction.x < 0:
		knight.play("attack_left")
	elif last_direction.y > 0:
		knight.play("attack_down")
	else:
		knight.play("attack_up")

	var enemies = attack_area.get_overlapping_bodies()

	for enemy in enemies:
		if enemy.is_in_group("enemies"):
			print("Enemy hit!")
			print("Enemy: ", enemy.name)

			# Existing behavior: enemy collision starts its battle.

	var animation_speed = knight.sprite_frames.get_animation_speed(knight.animation)
	var animation_length := 0.1

	if animation_speed > 0:
		animation_length = float(
			knight.sprite_frames.get_frame_count(knight.animation)
		) / animation_speed

	await get_tree().create_timer(animation_length).timeout

	is_attacking = false

	if last_direction.x > 0:
		knight.play("idle_right")
	elif last_direction.x < 0:
		knight.play("idle_left")
	elif last_direction.y > 0:
		knight.play("idle_down")
	else:
		knight.play("idle_up")

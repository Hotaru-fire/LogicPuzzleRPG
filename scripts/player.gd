extends CharacterBody2D

@export var speed := 200.0

@onready var knight = $Knight
@onready var attack_area = $AttackArea
@onready var skill_1_area = $Skill1Area
@onready var golden_aura = $GoldenAura

var last_direction := Vector2.DOWN
var is_attacking := false

# ==========================================
# FOOTSTEPS
# ==========================================

@onready var footstep_sound = $FootstepSound

var footstep_timer := 0.0
@export var footstep_interval := 0.35


# ==========================================
# CHARACTER STATS
# ==========================================

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


# ==========================================
# READY
# ==========================================

func _ready():

	print("PLAYER SELECTED CHARACTER: ", PlayerData.selected_character)

	if PlayerData.selected_character == 1:
		knight.sprite_frames = preload("res://resources/Knight.tres")

	elif PlayerData.selected_character == 4:
		knight.sprite_frames = preload("res://resources/Archer.tres")

	print("SpriteFrames currently loaded: ", knight.sprite_frames.resource_path)
	print("Current animation: ", knight.animation)
	print("Current frame: ", knight.frame)
	
	if PlayerData.has_save_data:

		hp = PlayerData.saved_hp
		mana = PlayerData.saved_mana
		global_position = PlayerData.saved_position

		print("SAVE DATA APPLIED")
		print("HP: ", hp)
		print("Mana: ", mana)
		print("Position: ", global_position)

	else:

		hp = max_hp
		mana = max_mana

	update_attack_area()

	update_attack_area()


# ==========================================
# MOVEMENT
# ==========================================

func _physics_process(delta):

	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()


	# ==========================================
	# FOOTSTEPS
	# ==========================================

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


	# If still attacking, don't play walking/idle animation

	if is_attacking:
		return


	# Normal movement

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


	# Idle

	else:

		if last_direction.x > 0:
			knight.play("idle_right")

		elif last_direction.x < 0:
			knight.play("idle_left")

		elif last_direction.y > 0:
			knight.play("idle_down")

		else:
			knight.play("idle_up")


# ==========================================
# ATTACK AREA DIRECTION
# ==========================================

func update_attack_area():

	if last_direction.x > 0:
		attack_area.position = Vector2(40, 0)

	elif last_direction.x < 0:
		attack_area.position = Vector2(-40, 0)

	elif last_direction.y > 0:
		attack_area.position = Vector2(0, 40)

	elif last_direction.y < 0:
		attack_area.position = Vector2(0, -40)


# ==========================================
# TAKE DAMAGE
# ==========================================

func take_damage(amount):

	var actual_damage = max(amount - defense, 1)

	hp -= actual_damage

	flash_red()
	
	hurt_sound.play()

	print("Player HP: ", hp, "/", max_hp)

	if hp <= 0:
		die()


func flash_red():

	knight.modulate = Color.RED

	await get_tree().create_timer(0.15).timeout

	knight.modulate = Color.WHITE


# ==========================================
# HEAL
# ==========================================

func heal(amount):

	hp += amount

	if hp > max_hp:
		hp = max_hp
		
	flash_green()
	
	print("Player HP: ", hp, "/", max_hp)


func flash_green():

	knight.modulate = Color.GREEN

	await get_tree().create_timer(0.15).timeout

	knight.modulate = Color.WHITE


func gain_honor():

	if honor_cooldown > 0:
		return

	if honor >= max_honor:
		return

	honor += 1

	honor_cooldown = 1.0

	print("Honor: ", honor, "/", max_honor)


# ==========================================
# USE MANA
# ==========================================

func use_mana(amount) -> bool:

	if mana < amount:

		print("Not enough mana!")

		return false

	mana -= amount

	print("Player Mana: ", mana, "/", max_mana)

	return true


# ==========================================
# DEATH
# ==========================================

func die():

	print("Player died!")

	hp = 0

	await get_tree().create_timer(2.0).timeout

	respawn()


# ==========================================
# RESPAWN
# ==========================================

func respawn():

	var respawn_point = get_parent().get_node("RespawnPoint")

	global_position = respawn_point.global_position

	hp = max_hp
	mana = max_mana

	print("Player respawned!")


# ==========================================
# INPUT
# ==========================================

@onready var stats_panel = $"../CanvasLayer/StatsPanel"


func _input(event):

	if event.is_action_pressed("basic_attack"):
		basic_attack()

	if event.is_action_pressed("open_stats"):
		stats_panel.visible = not stats_panel.visible


# ==========================================
# BASIC ATTACK
# ==========================================


func basic_attack():

	if is_attacking:
		return

	is_attacking = true

	print("Basic attack!")

	# Play the correct attack animation

	if last_direction.x > 0:
		knight.play("attack_right")

	elif last_direction.x < 0:
		knight.play("attack_left")

	elif last_direction.y > 0:
		knight.play("attack_down")

	else:
		knight.play("attack_up")


	# Check for enemies inside AttackArea

	var enemies = attack_area.get_overlapping_bodies()

	for enemy in enemies:

		if enemy.is_in_group("enemies"):

			print("Enemy hit!")
			print("Enemy: ", enemy.name)

			# Battle scene will be added later.


	# Wait for the attack animation duration

	var animation_length = knight.sprite_frames.get_frame_count(knight.animation) / knight.sprite_frames.get_animation_speed(knight.animation)

	await get_tree().create_timer(animation_length).timeout


	# Stop attacking

	is_attacking = false


	# Return to idle animation

	if last_direction.x > 0:
		knight.play("idle_right")

	elif last_direction.x < 0:
		knight.play("idle_left")

	elif last_direction.y > 0:
		knight.play("idle_down")

	else:
		knight.play("idle_up")


	# Wait for the animation duration

	var attack_animation_length = knight.sprite_frames.get_frame_count(knight.animation) / knight.sprite_frames.get_animation_speed(knight.animation)

	await get_tree().create_timer(attack_animation_length).timeout


	# Stop attacking

	is_attacking = false


	# Return to idle animation

	if last_direction.x > 0:
		knight.play("idle_right")

	elif last_direction.x < 0:
		knight.play("idle_left")

	elif last_direction.y > 0:
		knight.play("idle_down")

	else:
		knight.play("idle_up")

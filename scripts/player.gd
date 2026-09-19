extends CharacterBody2D

@export var speed := 200.0

@onready var knight = $Knight
@onready var attack_area = $AttackArea

var last_direction := Vector2.DOWN
var is_attacking := false

# Character stats

@export var max_hp := 200
@export var max_mana := 100

var hp := 200
var mana := 100

@export var attack := 30
@export var defense := 10
@export var strength := 20


func _ready():

	if PlayerData.selected_character == 1:
		knight.sprite_frames = preload("res://resources/Knight.tres")

	elif PlayerData.selected_character == 4:
		knight.sprite_frames = preload("res://resources/Archer.tres")

	hp = max_hp
	mana = max_mana

	update_attack_area()


func _physics_process(_delta):

	var direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed
	move_and_slide()


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


# ATTACK AREA DIRECTION

func update_attack_area():

	if last_direction.x > 0:
		attack_area.position = Vector2(40, 0)

	elif last_direction.x < 0:
		attack_area.position = Vector2(-40, 0)

	elif last_direction.y > 0:
		attack_area.position = Vector2(0, 40)

	elif last_direction.y < 0:
		attack_area.position = Vector2(0, -40)


# TAKE DAMAGE

func take_damage(amount):

	var actual_damage = max(amount - defense, 1)

	hp -= actual_damage

	print("Player HP: ", hp, "/", max_hp)

	if hp <= 0:
		die()


# HEAL

func heal(amount):

	hp += amount

	if hp > max_hp:
		hp = max_hp

	print("Player HP: ", hp, "/", max_hp)


# USE MANA

func use_mana(amount) -> bool:

	if mana < amount:

		print("Not enough mana!")

		return false

	mana -= amount

	print("Player Mana: ", mana, "/", max_mana)

	return true


# DEATH

func die():

	print("Player died!")

	hp = 0

	await get_tree().create_timer(2.0).timeout

	respawn()


# RESPAWN

func respawn():

	var respawn_point = get_parent().get_node("RespawnPoint")

	global_position = respawn_point.global_position

	hp = max_hp
	mana = max_mana

	print("Player respawned!")


# INPUT
@onready var stats_panel =$"../CanvasLayer/StatsPanel"
func _input(event):

	if event.is_action_pressed("test_damage"):
		take_damage(20)

	if event.is_action_pressed("basic_attack"):
		basic_attack()

	if event.is_action_pressed("open_stats"):
		stats_panel.visible = not stats_panel.visible

# BASIC ATTACK

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


	# Deal damage

	var enemies = attack_area.get_overlapping_bodies()

	for enemy in enemies:

		if enemy.is_in_group("enemies"):
			enemy.take_damage(attack)


	# Wait for the animation duration

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

var  mana_timer = 0.0


# PASSIVE MANA REGEN
func _process(delta):
	mana_timer += delta
	
	if mana_timer >= 1.0:
		mana_timer = 0.0
		
		if mana < max_mana:
			mana += 5
			
		if mana >= max_mana:
			mana = max_mana
		
		
		

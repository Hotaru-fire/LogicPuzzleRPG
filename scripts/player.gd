extends CharacterBody2D

@export var speed := 200.0

@onready var knight = $Knight
@onready var attack_area = $AttackArea
@onready var skill_1_area = $Skill1Area
@onready var golden_aura = $GoldenAura

var last_direction := Vector2.DOWN
var is_attacking := false

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

# ==========================================
# A KNIGHT'S OATH
# ==========================================

var honor := 0
var max_honor := 6
var honor_cooldown := 0.0
var honor_max_timer := 0.0

# ==========================================
# SKILL COOLDOWNS
# ==========================================

var skill_1_cooldown := 0.0
var skill_2_cooldown := 0.0
var skill_3_cooldown := 0.0

var skill_1_max_cooldown := 3.0
var skill_2_max_cooldown := 15.0
var skill_3_max_cooldown := 30.0

@export var skill_3_bonus_per_honor := 5.0

var skill_3_active := false
var skill_3_duration := 0.0
# ==========================================
# SKILL 2
# ==========================================

var skill_2_active := false
var skill_2_duration := 0.0
var skill_2_heal_timer := 0.0

# ==========================================
# READY
# ==========================================

func _ready():

	if PlayerData.selected_character == 1:
		knight.sprite_frames = preload("res://resources/Knight.tres")

	elif PlayerData.selected_character == 4:
		knight.sprite_frames = preload("res://resources/Archer.tres")

	hp = max_hp
	mana = max_mana

	update_attack_area()


# ==========================================
# MOVEMENT
# ==========================================

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

	if event.is_action_pressed("skill_1"):
		skill_1()

	if event.is_action_pressed("skill_2"):
		skill_2()

	if event.is_action_pressed("skill_3"):
		skill_3()


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

	# Deal damage

	var enemies = attack_area.get_overlapping_bodies()


	for enemy in enemies:

		if enemy.is_in_group("enemies"):
			enemy.take_damage(attack)
			hit_sound.play()
			gain_honor()

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


# ==========================================
# SKILL 1 - R
# ==========================================

func skill_1():

	if skill_1_cooldown > 0:
		print("Skill 1 is on cooldown!")
		return

	skill_1_cooldown = skill_1_max_cooldown

	print("Skill 1 used!")
	print("Cooldown: ", skill_1_cooldown)

	var enemies = skill_1_area.get_overlapping_bodies()

	print("Enemies in Skill 1 area: ", enemies.size())

	for enemy in enemies:

		if enemy.is_in_group("enemies"):
			enemy.take_damage(attack)


# ==========================================
# SKILL 2 - E
# ==========================================

func skill_2():

	if skill_2_cooldown > 0:
		print("Skill 2 is on cooldown!")
		return

	skill_2_cooldown = skill_2_max_cooldown

	skill_2_active = true
	skill_2_duration = 10.0
	skill_2_heal_timer = 0.0

	print("Skill 2 activated!")
	print("Healing duration: ", skill_2_duration)


# ==========================================
# SKILL 3 - Q
# ==========================================

func skill_3():

	if skill_3_cooldown > 0:
		print("Skill 3 is on cooldown!")
		return

	if honor == 0:
		print("Not enough Honor!")
		return

	skill_3_cooldown = skill_3_max_cooldown

	skill_3_active = true
	skill_3_duration = 10.0
	
	golden_aura.visible = true
	
	var bonus_percent = honor * skill_3_bonus_per_honor
	var bonus_multiplier = bonus_percent / 100.0

	attack = base_attack * (1.0 + bonus_multiplier)
	defense = base_defense * (1.0 + bonus_multiplier)

	print("Skill 3 used!")
	print("Honor: ", honor)
	print("Attack: ", attack)
	print("Defense: ", defense)


# ==========================================
# MANA REGEN
# ==========================================

var mana_timer := 0.0


# ==========================================
# PROCESS
# ==========================================

func _process(delta):

	# A Knight's Oath cooldown

	honor_cooldown -= delta

	if honor_cooldown < 0:
		honor_cooldown = 0
		
	# Honor maximum duration

	if honor == max_honor:

		honor_max_timer += delta

		if honor_max_timer >= 3.0:

			honor = 0
			honor_max_timer = 0.0

			print("Honor reset!")

	# Passive mana regen

	mana_timer += delta

	if mana_timer >= 1.0:

		mana_timer = 0.0

		if mana < max_mana:
			mana += 5

		if mana >= max_mana:
			mana = max_mana

	# Skill cooldowns

	if skill_1_cooldown > 0:
		skill_1_cooldown -= delta

	if skill_2_cooldown > 0:
		skill_2_cooldown -= delta

	if skill_3_cooldown > 0:
		skill_3_cooldown -= delta

	skill_1_cooldown = max(skill_1_cooldown, 0)
	skill_2_cooldown = max(skill_2_cooldown, 0)
	skill_3_cooldown = max(skill_3_cooldown, 0)

	# Skill 2 duration and healing

	if skill_2_active:

		skill_2_duration -= delta

		skill_2_heal_timer += delta

		if skill_2_heal_timer >= 1.0:

			skill_2_heal_timer = 0.0

			var heal_amount = defense * 0.5

			heal(heal_amount)

		if skill_2_duration <= 0:

			skill_2_duration = 0
			skill_2_active = false
			skill_2_heal_timer = 0.0

			print("Skill 2 ended!")
			
	if skill_3_active:

		skill_3_duration -= delta

		if skill_3_duration <= 0:

			skill_3_duration = 0
			skill_3_active = false

			attack = base_attack
			defense = base_defense
			
			golden_aura.visible = false
			
			print("Skill 3 ended!")
			print("Attack returned to: ", attack)
			print("Defense returned to: ", defense)

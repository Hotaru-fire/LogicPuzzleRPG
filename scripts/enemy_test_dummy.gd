extends CharacterBody2D

var hp := 500

@export var speed := 50.0
@export var damage := 10
@export var attack_cooldown := 1.0
@export var attack_range := 45.0

@onready var detection_area = $DetectionArea
@onready var attack_area = $AttackArea
@onready var animated_sprite = $EnemySprite

var player = null
var attack_timer := 0.0

var wander_direction := Vector2.ZERO
var wander_timer := 0.0

var facing_direction := Vector2.DOWN


func _physics_process(delta):
	attack_timer -= delta
	wander_timer -= delta

	# Find the player
	var detected_bodies = detection_area.get_overlapping_bodies()

	player = null

	for body in detected_bodies:
		if body.is_in_group("player"):
			player = body
			break


	# =========================
	# CHASE PLAYER
	# =========================
	if player != null:

		var direction = player.global_position - global_position
		var distance = direction.length()

		if distance > 0:
			direction = direction.normalized()

		# Determine which direction the enemy is facing
		facing_direction = get_4_direction(direction)

		# Move the attack area in front of the enemy
		update_attack_area()

		if distance > attack_range:

			velocity = direction * speed

			play_walk_animation()

			move_and_slide()

		else:

			velocity = Vector2.ZERO

			play_idle_animation()

			attack_player()


	# =========================
	# WANDER
	# =========================
	else:
		wander()


# =========================
# WANDER
# =========================

func wander():

	if wander_timer <= 0.0:

		wander_direction = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		).normalized()

		wander_timer = randf_range(1.0, 3.0)


	velocity = wander_direction * speed * 0.5

	if wander_direction != Vector2.ZERO:
		facing_direction = get_4_direction(wander_direction)

	update_attack_area()

	play_walk_animation()

	move_and_slide()


# =========================
# GET 4-DIRECTION FACING
# =========================

func get_4_direction(direction: Vector2) -> Vector2:

	if abs(direction.x) > abs(direction.y):

		if direction.x > 0:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT

	else:

		if direction.y > 0:
			return Vector2.DOWN
		else:
			return Vector2.UP


# =========================
# ATTACK AREA POSITION
# =========================

func update_attack_area():

	attack_area.position = facing_direction * 30


# =========================
# WALK ANIMATION
# =========================

func play_walk_animation():

	if facing_direction == Vector2.RIGHT:

		animated_sprite.play("walk_right")

	elif facing_direction == Vector2.LEFT:

		animated_sprite.play("walk_left")

	elif facing_direction == Vector2.UP:

		animated_sprite.play("walk_up")

	elif facing_direction == Vector2.DOWN:

		animated_sprite.play("walk_down")


# =========================
# IDLE ANIMATION
# =========================

func play_idle_animation():

	if facing_direction == Vector2.RIGHT:

		animated_sprite.play("idle_right")

	elif facing_direction == Vector2.LEFT:

		animated_sprite.play("idle_left")

	elif facing_direction == Vector2.UP:

		animated_sprite.play("idle_up")

	elif facing_direction == Vector2.DOWN:

		animated_sprite.play("idle_down")


# =========================
# ATTACK PLAYER
# =========================

func attack_player():

	if attack_timer > 0.0:
		return

	attack_timer = attack_cooldown

	var nearby_bodies = attack_area.get_overlapping_bodies()

	for body in nearby_bodies:

		if body.is_in_group("player"):

			body.take_damage(damage)

			print("Enemy attacked player!")

			break


# =========================
# TAKE DAMAGE
# =========================
func flash_red():

	$EnemySprite.modulate = Color.RED

	await get_tree().create_timer(0.15).timeout

	$EnemySprite.modulate = Color.WHITE
	
func take_damage(amount):

	hp -= amount

	flash_red()
	
	print("Enemy HP: ", hp, "/ 100")

	if hp <= 0:
		die()


# =========================
# DIE
# =========================

func die():

	print("Enemy defeated!")

	var dungeon_manager = get_tree().get_first_node_in_group("dungeon_manager")

	if dungeon_manager:
		dungeon_manager.enemy_defeated()

	queue_free()

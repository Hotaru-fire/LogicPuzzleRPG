extends CharacterBody2D

@export var speed := 250.0

func _physics_process(_delta):
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1

	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1

	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1

	if direction.length() > 0:
		direction = direction.normalized()

	velocity = direction * speed
	move_and_slide()

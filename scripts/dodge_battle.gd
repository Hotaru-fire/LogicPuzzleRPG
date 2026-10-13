extends Control

signal dodge_finished
signal player_hit

var attacks := []

@export var dodge_duration := 5.0

var dodge_timer := 0.0


func start_goblin_dodge():
	dodge_timer = dodge_duration
	visible = true

	$BattleBox/Player.position = Vector2(425, 140)
	
	print("DODGE BATTLE STARTED!")
	
	pattern_horizontal()
	await pattern_alternating()
	await pattern_center_burst()
	
	while dodge_timer > 0:
		print("Timer: ", dodge_timer)
		$TimeLabel.text = "%.1f" % dodge_timer
		await get_tree().create_timer(0.1).timeout
		dodge_timer -= 0.1
		
	finish_dodge()


func finish_dodge():
	$TimeLabel.text = "0.0"

	print("DODGE BATTLE FINISHED!")

	visible = false

	dodge_finished.emit()

func spawn_attack(start_position: Vector2, direction: Vector2):
	var attack = Area2D.new()

	attack.collision_layer = 2
	attack.collision_mask = 1

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()

	shape.size = Vector2(20, 20)
	collision.shape = shape

	attack.add_child(collision)

	attack.body_entered.connect(_on_attack_body_entered)

	var visual = Polygon2D.new()

	visual.polygon = PackedVector2Array([
		Vector2(-10, -10),
		Vector2(10, -10),
		Vector2(10, 10),
		Vector2(-10, 10)
	])

	attack.add_child(visual)

	$BattleBox/AttackContainer.add_child(attack)

	attack.position = start_position
	attack.set_meta("direction", direction)

	attacks.append(attack)

	print("Attack spawned!")


func _physics_process(delta):
	for attack in attacks:
		if is_instance_valid(attack):
			var direction = attack.get_meta("direction")
			attack.position += direction * 200 * delta



func _on_attack_body_entered(body):
	if body.name == "Player":
		print("HEART HIT!")
		player_hit.emit()

		if get_tree().current_scene.scene_file_path == "res://boss_battle.tscn":
			var boss_sprite = get_tree().current_scene.get_node_or_null("Boss/AnimatedSprite2D")

			if boss_sprite:
				boss_sprite.play("attack")



func pattern_horizontal():
	spawn_attack(Vector2(820, 70), Vector2.LEFT)
	spawn_attack(Vector2(820, 140), Vector2.LEFT)
	spawn_attack(Vector2(820, 210), Vector2.LEFT)


func pattern_alternating():
	spawn_attack(Vector2(820, 70), Vector2.LEFT)
	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(820, 210), Vector2.LEFT)
	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(820, 70), Vector2.LEFT)
	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(820, 210), Vector2.LEFT)


func pattern_center_burst():
	spawn_attack(Vector2(820, 140), Vector2.LEFT)

	await get_tree().create_timer(0.5).timeout

	spawn_attack(Vector2(820, 100), Vector2.LEFT)
	spawn_attack(Vector2(820, 180), Vector2.LEFT)

	await get_tree().create_timer(0.5).timeout

	spawn_attack(Vector2(820, 60), Vector2.LEFT)
	spawn_attack(Vector2(820, 140), Vector2.LEFT)
	spawn_attack(Vector2(820, 220), Vector2.LEFT)



func start_boss_dodge():
	dodge_timer = dodge_duration
	visible = true

	$BattleBox/Player.position = Vector2(425, 140)

	print("BOSS DODGE STARTED!")

	# Start the countdown separately so it runs
	# while the boss attack patterns are playing.
	update_boss_timer()

	while dodge_timer > 0:
		var pattern = randi_range(1, 4)

		match pattern:
			1:
				await pattern_boss_cross()
			2:
				await pattern_boss_rain()
			3:
				await pattern_boss_squeeze()
			4:
				await pattern_boss_aimed()

		if dodge_timer > 0:
			await get_tree().create_timer(0.3).timeout

	finish_dodge()


func update_boss_timer():
	while dodge_timer > 0:
		$TimeLabel.text = "%.1f" % dodge_timer

		await get_tree().create_timer(0.1).timeout

		dodge_timer = maxf(0.0, dodge_timer - 0.1)

	$TimeLabel.text = "0.0"



func pattern_boss_attack():
	spawn_attack(Vector2(820, 140), Vector2.LEFT)

	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(30, 140), Vector2.RIGHT)

	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(425, 30), Vector2.DOWN)

	await get_tree().create_timer(0.4).timeout

	spawn_attack(Vector2(425, 250), Vector2.UP)


func pattern_boss_cross():
	spawn_attack(Vector2(820, 140), Vector2.LEFT)

	await get_tree().create_timer(0.35).timeout
	spawn_attack(Vector2(30, 140), Vector2.RIGHT)

	await get_tree().create_timer(0.35).timeout
	spawn_attack(Vector2(425, 30), Vector2.DOWN)

	await get_tree().create_timer(0.35).timeout
	spawn_attack(Vector2(425, 250), Vector2.UP)


func pattern_boss_rain():
	spawn_attack(Vector2(150, 30), Vector2.DOWN)

	await get_tree().create_timer(0.25).timeout
	spawn_attack(Vector2(350, 30), Vector2.DOWN)

	await get_tree().create_timer(0.25).timeout
	spawn_attack(Vector2(550, 30), Vector2.DOWN)

	await get_tree().create_timer(0.25).timeout
	spawn_attack(Vector2(750, 30), Vector2.DOWN)


func pattern_boss_squeeze():
	spawn_attack(Vector2(30, 70), Vector2.RIGHT)
	spawn_attack(Vector2(820, 210), Vector2.LEFT)

	await get_tree().create_timer(0.6).timeout

	spawn_attack(Vector2(30, 210), Vector2.RIGHT)
	spawn_attack(Vector2(820, 70), Vector2.LEFT)

	await get_tree().create_timer(0.6).timeout

	spawn_attack(Vector2(30, 140), Vector2.RIGHT)
	spawn_attack(Vector2(820, 140), Vector2.LEFT)


func pattern_boss_aimed():
	var heart_position: Vector2 = $BattleBox/Player.position
	var spawn_position := Vector2(820, 140)

	var direction := (heart_position - spawn_position).normalized()

	spawn_attack(spawn_position, direction)

	await get_tree().create_timer(0.7).timeout

	heart_position = $BattleBox/Player.position
	spawn_position = Vector2(820, 140)
	direction = (heart_position - spawn_position).normalized()

	spawn_attack(spawn_position, direction)

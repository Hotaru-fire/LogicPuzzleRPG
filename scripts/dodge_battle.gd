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

	await pattern_boss_attack()

	while dodge_timer > 0:
		print("Timer: ", dodge_timer)
		$TimeLabel.text = "%.1f" % dodge_timer
		await get_tree().create_timer(0.1).timeout
		dodge_timer -= 0.1

	finish_dodge()


func pattern_boss_attack():
	spawn_attack(Vector2(820, 70), Vector2.LEFT)
	spawn_attack(Vector2(820, 140), Vector2.LEFT)
	spawn_attack(Vector2(820, 210), Vector2.LEFT)

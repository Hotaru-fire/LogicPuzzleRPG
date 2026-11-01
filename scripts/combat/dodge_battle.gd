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

func spawn_attack(start_position: Vector2, direction: Vector2, speed := 200.0):
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
	attack.set_meta("speed", speed)

	attacks.append(attack)

	print("Attack spawned!")


func _physics_process(delta):
	for attack in attacks:
		if is_instance_valid(attack):
			var direction = attack.get_meta("direction")
			var speed = attack.get_meta("speed", 200.0)
			attack.position += direction * speed * delta


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


# =========================
# ORC DODGE BATTLE
# =========================

func start_orc_dodge():
	dodge_timer = dodge_duration
	visible = true

	$BattleBox/Player.position = Vector2(425, 140)

	print("ORC DODGE STARTED!")

	# Runs the countdown at the same time as the patterns
	update_boss_timer()

	while dodge_timer > 0:
		var pattern = randi_range(1, 4)

		match pattern:
			1:
				await pattern_orc_slam()
			2:
				await pattern_orc_wall_gap()
			3:
				await pattern_orc_shockwave()
			4:
				await pattern_orc_rage()

		if dodge_timer > 0:
			await get_tree().create_timer(0.5).timeout

	finish_dodge()


# SLAM: heavy, fast drops that land on wherever the heart is standing.
# The last slam adds flankers so you can't just step sideways.
func pattern_orc_slam():
	for i in 3:
		var x: float = $BattleBox/Player.position.x
		spawn_attack(Vector2(x, 30), Vector2.DOWN, 350.0)

		if i == 2:
			spawn_attack(Vector2(x - 70, 30), Vector2.DOWN, 350.0)
			spawn_attack(Vector2(x + 70, 30), Vector2.DOWN, 350.0)

		await get_tree().create_timer(0.6).timeout


# WALL: a slow wall of attacks sweeps in with a random gap to squeeze through.
func pattern_orc_wall_gap():
	var gap := randi_range(0, 6)

	for i in 8:
		if i == gap or i == gap + 1:
			continue

		spawn_attack(Vector2(820, 30 + i * 30), Vector2.LEFT, 150.0)

	await get_tree().create_timer(1.2).timeout


# SHOCKWAVE: two fans of attacks, the second one fills the gaps of the first.
func pattern_orc_shockwave():
	for angle in [-30, -15, 0, 15, 30]:
		var dir = Vector2.LEFT.rotated(deg_to_rad(angle))
		spawn_attack(Vector2(820, 140), dir, 170.0)

	await get_tree().create_timer(0.8).timeout

	for angle in [-22, -7, 7, 22]:
		var dir = Vector2.LEFT.rotated(deg_to_rad(angle))
		spawn_attack(Vector2(820, 140), dir, 170.0)

	await get_tree().create_timer(0.6).timeout


# RAGE: fast attacks from both sides at random heights.
func pattern_orc_rage():
	for i in 5:
		var y_left := randf_range(50.0, 230.0)
		var y_right := randf_range(50.0, 230.0)

		spawn_attack(Vector2(30, y_left), Vector2.RIGHT, 320.0)
		spawn_attack(Vector2(820, y_right), Vector2.LEFT, 320.0)

		await get_tree().create_timer(0.35).timeout

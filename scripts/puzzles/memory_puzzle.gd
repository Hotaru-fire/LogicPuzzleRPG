
extends Control

signal puzzle_finished(success: bool)

var puzzle_success := false
var puzzle_active := false

var symbols = ["★", "◆", "●", "▲", "■"]
var sequence = []
var player_answer = []

var puzzle_time := 10.0
var time_left := 10.0

@export var player_move_speed: float = 200.0

var player_moving_right := false

@onready var symbol_labels = $PuzzleUI/SequenceDisplay/SymbolLabels

@onready var button1 = $PuzzleUI/AnswerArea/Button1
@onready var button2 = $PuzzleUI/AnswerArea/Button2
@onready var button3 = $PuzzleUI/AnswerArea/Button3
@onready var button4 = $PuzzleUI/AnswerArea/Button4
@onready var button5 = $PuzzleUI/AnswerArea/Button5

@onready var answer_area = $PuzzleUI/AnswerArea
@onready var result_label = $PuzzleUI/ResultLabel

@onready var timer_bar = $PuzzleUI/TimerBar
@onready var time_label = $PuzzleUI/TimeLabel
@onready var puzzle_timer: Timer = $PuzzleTimer

@onready var player: Node2D = $player
@onready var player_sprite: AnimatedSprite2D = $player/AnimatedSprite2D


func _ready():
	puzzle_timer.wait_time = puzzle_time
	puzzle_timer.one_shot = true

	if not puzzle_timer.timeout.is_connected(_on_puzzle_timer_timeout):
		puzzle_timer.timeout.connect(_on_puzzle_timer_timeout)

	start_puzzle()


func _process(delta: float) -> void:
	# Update the timer while the player is answering.
	if puzzle_active and not puzzle_timer.is_stopped():
		time_left = puzzle_timer.time_left
		timer_bar.value = time_left
		time_label.text = "Time: " + str(ceili(time_left))

	# Move the player only after a correct answer.
	if player_moving_right:
		player.position.x += player_move_speed * delta

		# Calculate the sprite's displayed width.
		var sprite_width := 0.0

		if player_sprite.sprite_frames != null:
			if player_sprite.sprite_frames.has_animation(player_sprite.animation):
				var texture = player_sprite.sprite_frames.get_frame_texture(
					player_sprite.animation,
					player_sprite.frame
				)

				if texture != null:
					sprite_width = texture.get_size().x * absf(player_sprite.scale.x)

		# Wait until the entire player has passed the right edge.
		var right_edge := get_viewport_rect().size.x

		if player.position.x > right_edge + sprite_width:
			player_moving_right = false
			player.visible = false

			# Tell BossBattle the successful puzzle is finished.
			puzzle_finished.emit(true)


func start_puzzle():
	puzzle_success = false
	puzzle_active = true
	player_moving_right = false
	player_answer.clear()

	result_label.text = ""

	# Keep the position set in MemoryPuzzle.tscn.
	player.visible = true

	# Play the channel animation without moving.
	if player_sprite.sprite_frames != null:
		if player_sprite.sprite_frames.has_animation("channel"):
			player_sprite.play("channel")
		else:
			push_warning("No animation named 'channel' was found.")

	create_random_sequence()
	show_sequence()

	answer_area.visible = false

	# Display the sequence for two seconds.
	await get_tree().create_timer(2.0).timeout

	if not is_inside_tree() or not puzzle_active:
		return

	hide_sequence()
	answer_area.visible = true

	setup_buttons()
	start_countdown()


func create_random_sequence():
	var available_symbols = symbols.duplicate()
	available_symbols.shuffle()

	# Choose four different symbols.
	sequence = available_symbols.slice(0, 4)

	print("New sequence: ", sequence)


func show_sequence():
	symbol_labels.text = " ".join(sequence)
	symbol_labels.visible = true


func hide_sequence():
	symbol_labels.text = ""
	symbol_labels.visible = false


func setup_buttons():
	var buttons = [
		button1,
		button2,
		button3,
		button4,
		button5
	]

	var randomized_symbols = symbols.duplicate()
	randomized_symbols.shuffle()

	for i in range(buttons.size()):
		buttons[i].text = randomized_symbols[i]

		# Remove existing connections to prevent duplicate callbacks.
		for connection in buttons[i].pressed.get_connections():
			buttons[i].pressed.disconnect(connection.callable)

		buttons[i].pressed.connect(
			_on_symbol_pressed.bind(randomized_symbols[i])
		)

		buttons[i].disabled = false


func _on_symbol_pressed(symbol: String):
	if not puzzle_active:
		return

	if player_answer.size() >= sequence.size():
		return

	player_answer.append(symbol)

	print("Player selected: ", symbol)

	var current_index = player_answer.size() - 1

	# Fail immediately if the selected symbol is incorrect.
	if player_answer[current_index] != sequence[current_index]:
		puzzle_failed()
		return

	# All symbols correct: start the player's movement.
	if player_answer.size() == sequence.size():
		puzzle_solved()


func puzzle_solved():
	if not puzzle_active:
		return

	puzzle_success = true
	puzzle_active = false

	puzzle_timer.stop()

	result_label.text = "SUCCESS!"

	print("Puzzle solved!")
	print("Correct sequence: ", sequence)

	disable_buttons()

	# Keep the player visible and the channel animation running.
	player.visible = true
	player_moving_right = true

	# Do not emit puzzle_finished(true) here.
	# It will be emitted after the player leaves the screen.


func puzzle_failed():
	if not puzzle_active:
		return

	puzzle_success = false
	puzzle_active = false

	puzzle_timer.stop()

	# Hide the player immediately on failure.
	player_moving_right = false
	player.visible = false
	player_sprite.stop()

	time_left = 0.0
	timer_bar.value = 0.0
	time_label.text = "Time: 0"

	result_label.text = "FAILED!"

	print("Puzzle failed!")
	print("Correct sequence was: ", sequence)

	disable_buttons()

	# Notify BossBattle immediately about failure.
	puzzle_finished.emit(false)


func disable_buttons():
	button1.disabled = true
	button2.disabled = true
	button3.disabled = true
	button4.disabled = true
	button5.disabled = true


func start_countdown():
	time_left = puzzle_time

	puzzle_timer.wait_time = puzzle_time
	timer_bar.max_value = puzzle_time
	timer_bar.value = time_left

	time_label.text = "Time: " + str(int(time_left))

	puzzle_timer.start()


func _on_puzzle_timer_timeout():
	if puzzle_active:
		puzzle_failed()

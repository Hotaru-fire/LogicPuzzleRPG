extends Control

signal puzzle_finished(success: bool)

var puzzle_success := false

var symbols = ["★", "◆", "●", "▲", "■"]
var sequence = []
var player_answer = []

var puzzle_time := 10.0
var time_left := 10.0

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
@onready var puzzle_timer = $PuzzleTimer


func _ready():
	start_puzzle()


func start_puzzle():
	puzzle_success = false
	player_answer.clear()
	result_label.text = ""

	create_random_sequence()

	show_sequence()

	answer_area.visible = false

	await get_tree().create_timer(2.0).timeout

	hide_sequence()

	answer_area.visible = true

	setup_buttons()
	start_countdown()


func create_random_sequence():
	var available_symbols = symbols.duplicate()
	available_symbols.shuffle()

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

		for connection in buttons[i].pressed.get_connections():
			buttons[i].pressed.disconnect(connection.callable)

		buttons[i].pressed.connect(
			_on_symbol_pressed.bind(randomized_symbols[i])
		)

		buttons[i].disabled = false


func _on_symbol_pressed(symbol: String):
	player_answer.append(symbol)

	print("Player selected: ", symbol)

	var current_index = player_answer.size() - 1

	if player_answer[current_index] != sequence[current_index]:
		puzzle_failed()
		return

	if player_answer.size() == sequence.size():
		puzzle_solved()


func puzzle_solved():
	puzzle_success = true

	puzzle_timer.stop()

	result_label.text = "SUCCESS!"

	print("Puzzle solved!")
	print("Correct sequence: ", sequence)

	disable_buttons()

	puzzle_finished.emit(true)


func puzzle_failed():
	puzzle_success = false

	puzzle_timer.stop()

	result_label.text = "FAILED!"

	print("Puzzle failed!")
	print("Correct sequence was: ", sequence)

	disable_buttons()

	puzzle_finished.emit(false)


func disable_buttons():
	button1.disabled = true
	button2.disabled = true
	button3.disabled = true
	button4.disabled = true
	button5.disabled = true


func start_countdown():
	time_left = puzzle_time

	timer_bar.max_value = puzzle_time
	timer_bar.value = time_left

	time_label.text = "Time: " + str(int(time_left))

	puzzle_timer.start()


func _on_puzzle_timer_timeout():
	time_left -= 0.1

	if time_left < 0:
		time_left = 0

	timer_bar.value = time_left
	time_label.text = "Time: " + str(int(time_left))

	if time_left <= 0:
		puzzle_failed()

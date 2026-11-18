extends Control

signal puzzle_finished(success: bool)

# --- Difficulty settings (change these to tune it) ---
const SEQUENCE_LENGTH_BY_TURN := [3, 4, 4, 4, 5]       # how many buttons light up (3 = easy, 4-5 = harder)
const ALLOW_REPEATS := false      # true = the same button can light up twice
const LIGHT_TIME := 0.6           # how long each button stays lit
const GAP_TIME := 0.3             # pause between lit buttons
const START_DELAY := 0.8          # pause before the sequence starts
const LIGHT_COLOR := Color(2.0, 2.0, 0.6)  # glow color (values above 1 = bright)

var puzzle_success := false
var puzzle_active := false
var turn_number := 1   # set by the battle script before the puzzle starts
var accepting_input := false

var symbols = ["★", "◆", "●", "▲", "■"]
var sequence: Array[int] = []        # button indexes, in the order they light up
var player_answer: Array[int] = []

var puzzle_time := 15.0
var time_left := 15.0

# Puzzle analytics
var puzzle_started_msec: int = 0
var puzzle_elapsed_seconds: float = 0.0
var puzzle_clear_recorded: bool = false

var buttons: Array[Button] = []

@onready var symbol_labels = $PuzzleUI/SequenceDisplay/SymbolLabels

@onready var button1 = $PuzzleUI/AnswerCard/AnswerArea/Button1
@onready var button2 = $PuzzleUI/AnswerCard/AnswerArea/Button2
@onready var button3 = $PuzzleUI/AnswerCard/AnswerArea/Button3
@onready var button4 = $PuzzleUI/AnswerCard/AnswerArea/Button4
@onready var button5 = $PuzzleUI/AnswerCard/AnswerArea/Button5

@onready var answer_area = $PuzzleUI/AnswerCard/AnswerArea
@onready var result_label = $PuzzleUI/ResultLabel

@onready var timer_bar = $PuzzleUI/PanelContainer/MarginContainer/VBoxContainer/TimerBar
@onready var time_label = $PuzzleUI/PanelContainer/MarginContainer/VBoxContainer/TimeLabel
@onready var puzzle_timer: Timer = $PuzzleTimer


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PuzzleUI.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PlayerPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$PlayerPanel/ColorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	buttons = [button1, button2, button3, button4, button5]
	setup_buttons()

	puzzle_timer.wait_time = puzzle_time
	puzzle_timer.one_shot = true

	if not puzzle_timer.timeout.is_connected(_on_puzzle_timer_timeout):
		puzzle_timer.timeout.connect(_on_puzzle_timer_timeout)

	start_puzzle()


func _process(_delta: float) -> void:
	if puzzle_active and not puzzle_timer.is_stopped():
		time_left = puzzle_timer.time_left
		timer_bar.value = time_left
		time_label.text = "Time: " + str(ceili(time_left))


func start_puzzle():
	puzzle_success = false
	puzzle_active = true
	accepting_input = false
	player_answer.clear()
	puzzle_started_msec = 0
	puzzle_elapsed_seconds = 0.0
	puzzle_clear_recorded = false

	# The old "memorize the symbols" display is no longer used.
	symbol_labels.text = ""
	symbol_labels.visible = false

	# Buttons are visible the whole time, but ignore input while lighting up.
	answer_area.visible = true
	time_label.text = "Time: " + str(int(puzzle_time))
	timer_bar.max_value = puzzle_time
	timer_bar.value = puzzle_time

	create_random_sequence()
	await play_sequence()

	if not is_inside_tree() or not puzzle_active:
		return

	result_label.text = "Your turn!"
	accepting_input = true
	start_countdown()


func get_sequence_length() -> int:
	var i := clampi(turn_number - 1, 0, SEQUENCE_LENGTH_BY_TURN.size() - 1)
	return mini(SEQUENCE_LENGTH_BY_TURN[i], buttons.size())


func create_random_sequence():
	sequence.clear()
	var length := get_sequence_length()

	if ALLOW_REPEATS:
		for i in length:
			sequence.append(randi_range(0, buttons.size() - 1))
	else:
		var indexes: Array[int] = []
		for i in buttons.size():
			indexes.append(i)
		indexes.shuffle()
		sequence = indexes.slice(0, length)

	print("Turn ", turn_number, " sequence (button indexes): ", sequence)


func play_sequence():
	result_label.text = "Turn %d: Watch..." % turn_number

	await get_tree().create_timer(START_DELAY).timeout

	for index in sequence:
		if not is_inside_tree() or not puzzle_active:
			return

		light_button(index, LIGHT_TIME)
		await get_tree().create_timer(LIGHT_TIME + GAP_TIME).timeout


# Makes a button glow for a short time, then return to normal.
func light_button(index: int, duration: float) -> void:
	var button := buttons[index]
	button.modulate = LIGHT_COLOR

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(button):
		button.modulate = Color.WHITE


# Buttons keep the same symbol the whole puzzle, so the player can see which one lit up.
func setup_buttons():
	for i in buttons.size():
		buttons[i].text = symbols[i]
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE

		if not buttons[i].pressed.is_connected(_on_button_pressed.bind(i)):
			buttons[i].pressed.connect(_on_button_pressed.bind(i))


func _on_button_pressed(index: int):
	if not puzzle_active or not accepting_input:
		return

	if player_answer.size() >= sequence.size():
		return

	player_answer.append(index)
	print("Player selected: ", symbols[index])

	# Quick flash so the player sees their click register.
	light_button(index, 0.2)

	var current_index = player_answer.size() - 1

	# Fail immediately if the pressed button is incorrect.
	if player_answer[current_index] != sequence[current_index]:
		puzzle_failed()
		return

	# All buttons correct.
	if player_answer.size() == sequence.size():
		puzzle_solved()


func puzzle_solved():
	if not puzzle_active:
		return

	puzzle_success = true
	puzzle_active = false
	accepting_input = false
	puzzle_timer.stop()

	puzzle_elapsed_seconds = (
		float(Time.get_ticks_msec() - puzzle_started_msec) / 1000.0
	)
	print("PUZZLE ANSWER TIME: ", puzzle_elapsed_seconds, " seconds")

	result_label.text = "SUCCESS!"
	disable_buttons()

	# Record analytics only once per successful puzzle.
	if not puzzle_clear_recorded:
		puzzle_clear_recorded = true
		Session.record_puzzle_clear(puzzle_elapsed_seconds)

		if Session.is_logged_in():
			GameAPI.save_progress()

	# Brief pause so "SUCCESS!" is visible before the battle continues.
	await get_tree().create_timer(0.8).timeout

	if not is_inside_tree():
		return

	puzzle_finished.emit(true)


func puzzle_failed():
	if not puzzle_active:
		return

	puzzle_success = false
	puzzle_active = false
	accepting_input = false

	puzzle_timer.stop()

	time_left = 0.0
	timer_bar.value = 0.0
	time_label.text = "Time: 0"

	result_label.text = "FAILED!"

	print("Puzzle failed!")
	print("Correct sequence was: ", sequence)

	disable_buttons()

	# Short pause so "FAILED!" is visible, then notify the battle.
	await get_tree().create_timer(0.8).timeout

	if not is_inside_tree():
		return

	puzzle_finished.emit(false)


func disable_buttons():
	for b in buttons:
		b.disabled = true


func start_countdown():
	time_left = puzzle_time
	puzzle_started_msec = Time.get_ticks_msec()

	puzzle_timer.wait_time = puzzle_time
	timer_bar.max_value = puzzle_time
	timer_bar.value = time_left

	time_label.text = "Time: " + str(int(time_left))

	puzzle_timer.start()


func _on_puzzle_timer_timeout():
	if puzzle_active:
		puzzle_failed()

extends Control

signal puzzle_completed
signal puzzle_closed

const RUNE_COUNT := 6
const SEQUENCE_LENGTH := RUNE_COUNT
const GLOW_SECONDS := 0.55
const GLOW_GAP_SECONDS := 0.25

@export var rune_textures: Array[Texture2D] = [
	preload("res://assets/Runes/Rune1.png"),
	preload("res://assets/Runes/Rune2.png"),
	preload("res://assets/Runes/Rune3.png"),
	preload("res://assets/Runes/Rune4.png"),
	preload("res://assets/Runes/Rune5.png"),
	preload("res://assets/Runes/Rune6.png")
]

var sequence_order: Array[int] = []
var current_sequence_position := 0
var is_completed := false
var _is_running := false
var _is_playing_sequence := false
var _was_tree_paused := false
var _attempt_id := 0
var mock_lines: Array[String] = []

@onready var instruction_label: Label = $PanelContainer/VBoxContainer/InstructionLabel
@onready var sequence_container: HBoxContainer = $PanelContainer/VBoxContainer/SequenceContainer
@onready var answer_container: HBoxContainer = $PanelContainer/VBoxContainer/AnswerContainer
@onready var feedback_label: Label = $PanelContainer/VBoxContainer/FeedbackLabel
@onready var close_button: Button = $PanelContainer/VBoxContainer/CloseButton
@onready var answer_buttons: Array[Button] = [
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton1,
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton2,
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton3,
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton4,
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton5,
	$PanelContainer/VBoxContainer/AnswerContainer/RuneButton6
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close_puzzle)
	for rune_index in range(answer_buttons.size()):
		answer_buttons[rune_index].pressed.connect(
			_on_rune_button_pressed.bind(rune_index)
		)
	if not _validate_configuration():
		set_process_input(false)
		return

	for rune_index in range(RUNE_COUNT):
		var texture := rune_textures[rune_index]
		answer_buttons[rune_index].icon = texture
		answer_buttons[rune_index].texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		answer_buttons[rune_index].tooltip_text = "Rune %d" % (rune_index + 1)

	sequence_container.hide()
	hide()


func start_puzzle() -> void:
	if is_completed:
		_was_tree_paused = get_tree().paused
		get_tree().paused = true
		_is_running = true
		show()
		sequence_container.hide()
		answer_container.hide()
		feedback_label.text = "This rune trial has already been completed."
		return
	if _is_running:
		return
	if not _validate_configuration():
		return

	_attempt_id += 1
	var active_attempt := _attempt_id
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	current_sequence_position = 0
	_generate_sequence()
	_is_running = true
	feedback_label.text = ""
	instruction_label.text = "Watch all six runes glow, then repeat the pattern."
	sequence_container.hide()
	answer_container.show()
	_clear_all_rune_glows()
	for button in answer_buttons:
		button.disabled = true
	show()

	await _play_sequence(active_attempt)
	if not _is_current_attempt(active_attempt):
		return

	instruction_label.text = "Click all six runes in the same order."


func _on_rune_button_pressed(rune_index: int) -> void:
	if (
		not _is_running
		or is_completed
		or _is_playing_sequence
		or not answer_container.visible
	):
		return

	if rune_index != sequence_order[current_sequence_position]:
		current_sequence_position = 0
		feedback_label.text = (
			mock_lines.pick_random()
			if not mock_lines.is_empty()
			else "Wrong rune. Watch the full pattern again, then retry."
		)
		var active_attempt := _attempt_id
		instruction_label.text = "Watch the pattern again."
		await _play_sequence(active_attempt)
		if _is_current_attempt(active_attempt):
			instruction_label.text = "Click all six runes in the same order."
		return

	current_sequence_position += 1
	if current_sequence_position == SEQUENCE_LENGTH:
		is_completed = true
		_is_running = false
		for button in answer_buttons:
			button.disabled = true
		feedback_label.text = "Success! The rune sequence is complete."
		puzzle_completed.emit()
		return

	feedback_label.text = "Correct: %d of %d." % [
		current_sequence_position,
		SEQUENCE_LENGTH
	]


func _generate_sequence() -> void:
	var available_runes: Array[int] = []
	for rune_index in range(RUNE_COUNT):
		available_runes.append(rune_index)

	for index in range(available_runes.size() - 1, 0, -1):
		var swap_index := randi_range(0, index)
		var rune_index := available_runes[index]
		available_runes[index] = available_runes[swap_index]
		available_runes[swap_index] = rune_index

	sequence_order.clear()
	for index in range(SEQUENCE_LENGTH):
		sequence_order.append(available_runes[index])


func _play_sequence(active_attempt: int) -> void:
	_is_playing_sequence = true
	for button in answer_buttons:
		button.disabled = true

	for rune_index in sequence_order:
		if not _is_current_attempt(active_attempt):
			return
		_set_rune_glow(rune_index, true)
		await get_tree().create_timer(GLOW_SECONDS, true).timeout
		if not _is_current_attempt(active_attempt):
			return
		_set_rune_glow(rune_index, false)
		await get_tree().create_timer(GLOW_GAP_SECONDS, true).timeout

	if not _is_current_attempt(active_attempt):
		return
	_is_playing_sequence = false
	for button in answer_buttons:
		button.disabled = false


func _is_current_attempt(active_attempt: int) -> bool:
	return (
		is_inside_tree()
		and active_attempt == _attempt_id
		and _is_running
	)


func _set_rune_glow(rune_index: int, enabled: bool) -> void:
	var button := answer_buttons[rune_index]
	if not enabled:
		_remove_rune_glow(button)
		return

	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.8, 0.2, 0.35)
	glow_style.border_color = Color(1.0, 0.85, 0.3)
	glow_style.set_border_width_all(3)
	glow_style.shadow_color = Color(1.0, 0.75, 0.15, 0.9)
	glow_style.shadow_size = 12
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, glow_style)


func _remove_rune_glow(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.remove_theme_stylebox_override(state)


func _clear_all_rune_glows() -> void:
	for button in answer_buttons:
		_remove_rune_glow(button)


func _close_puzzle() -> void:
	if not visible:
		return

	_is_running = false
	_is_playing_sequence = false
	_attempt_id += 1
	_clear_all_rune_glows()
	hide()
	get_tree().paused = _was_tree_paused
	puzzle_closed.emit()


func _validate_configuration() -> bool:
	if rune_textures.size() != RUNE_COUNT:
		push_error("MissingRunePuzzle requires exactly six rune textures.")
		return false
	for rune_index in range(RUNE_COUNT):
		if rune_textures[rune_index] == null:
			push_error("MissingRunePuzzle rune texture %d is not assigned." % rune_index)
			return false
	return true

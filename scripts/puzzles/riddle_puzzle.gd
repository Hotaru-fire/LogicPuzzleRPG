extends Control

signal puzzle_completed
signal puzzle_closed

const SYMBOLS: Array[Texture2D] = [
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_001.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_002.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_003.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_004.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_005.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_006.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_007.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_008.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_009.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_010.png")
]
const ROUNDS := 3
const SHOW_SECONDS := 4.0
const BLANK_SECONDS := 1.5
const LETTERS: Array[String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]

@export var use_letters := false
var mock_lines: Array[String] = []
var is_completed := false
var _is_running := false
var _was_tree_paused := false
var _attempt_id := 0
var _round := 0
var _original: Array = []
var _spare: Array = []

@onready var _title: Label = %TitleLabel
@onready var _symbols_box: HBoxContainer = %SymbolsLabel
@onready var _question: Label = %QuestionLabel
@onready var _answer_box: GridContainer = %AnswerBox
@onready var _feedback: Label = %FeedbackLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_close_button.pressed.connect(_close_puzzle)
	hide()


func start_puzzle() -> void:
	if _is_running:
		return
	_was_tree_paused = get_tree().paused
	get_tree().paused = true
	_is_running = true
	show()
	if is_completed:
		_title.text = ""
		_clear_symbols()
		_question.text = ""
		_clear_answers()
		_feedback.text = "This trial has already been completed."
		return
	_feedback.text = ""
	_round = 0
	_start_round()


func _start_round() -> void:
	_attempt_id += 1
	var attempt := _attempt_id
	_clear_answers()
	_question.text = ""

	var count := 4 if _round == 0 else 5
	var pool: Array = LETTERS.duplicate() if use_letters else SYMBOLS.duplicate()
	pool.shuffle()
	_original = pool.slice(0, count)
	_spare = pool.slice(count)

	var item_name := "letters" if use_letters else "symbols"
	_title.text = "Round %d of %d: memorize the %s." % [
		_round + 1,
		ROUNDS,
		item_name
	]
	_show_symbols(_original)
	await get_tree().create_timer(SHOW_SECONDS, true).timeout
	if not _is_current(attempt):
		return

	_title.text = "Hold it in your mind..."
	_show_hidden_symbols(_original.size())
	await get_tree().create_timer(BLANK_SECONDS, true).timeout
	if not _is_current(attempt):
		return

	_show_changed_row()


func _show_changed_row() -> void:
	var after: Array = _original.duplicate()
	var correct: Variant
	var item_name := "letter" if use_letters else "symbol"

	match _round:
		0:
			var removed_index := randi_range(0, _original.size() - 1)
			correct = _original[removed_index]
			after.remove_at(removed_index)
			_question.text = "One %s disappeared. Which one?" % item_name
			var options: Array = [correct]
			options.append_array(_spare.slice(0, 3))
			options.shuffle()
			_show_symbol_answers(options, correct)
		1:
			correct = _spare[0]
			after.insert(randi_range(0, after.size()), correct)
			var originals: Array = _original.duplicate()
			originals.shuffle()
			_question.text = "One %s is new. Which one?" % item_name
			var options: Array = [correct]
			options.append_array(originals.slice(0, 3))
			options.shuffle()
			_show_symbol_answers(options, correct)
		_:
			var changed_index := randi_range(0, after.size() - 1)
			after[changed_index] = _spare[0]
			_question.text = "One %s was swapped. Which position changed?" % item_name
			_show_position_answers(after, changed_index)

	_title.text = "Round %d of %d: what changed?" % [_round + 1, ROUNDS]
	_show_symbols(after)


func _show_symbols(symbols: Array) -> void:
	_clear_symbols()
	for symbol in symbols:
		if symbol is String:
			var letter := Label.new()
			letter.text = symbol
			letter.custom_minimum_size = Vector2(48, 48)
			letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			letter.add_theme_font_override(
				"font",
				preload("res://assets/fonts/Nunito/static/Nunito-Black.ttf")
			)
			letter.add_theme_font_size_override("font_size", 34)
			letter.add_theme_color_override("font_color", Color(0.12, 0.12, 0.12))
			_symbols_box.add_child(letter)
			continue

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = symbol as Texture2D
		_symbols_box.add_child(icon)


func _show_hidden_symbols(count: int) -> void:
	_clear_symbols()
	for _index in range(count):
		var placeholder := Label.new()
		placeholder.text = "?"
		placeholder.custom_minimum_size = Vector2(48, 48)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_symbols_box.add_child(placeholder)


func _clear_symbols() -> void:
	for child in _symbols_box.get_children():
		_symbols_box.remove_child(child)
		child.queue_free()


func _show_symbol_answers(options: Array, correct: Variant) -> void:
	for option in options:
		var button := _make_symbol_button(option)
		button.pressed.connect(_on_answer_pressed.bind(option == correct))
		_answer_box.add_child(button)


func _show_position_answers(symbols: Array, correct_position: int) -> void:
	for symbol_index in range(symbols.size()):
		var symbol: Variant = symbols[symbol_index]
		var button := _make_symbol_button(symbol)
		if use_letters:
			button.text += " - Position %d" % (symbol_index + 1)
		else:
			button.text = "Position %d" % (symbol_index + 1)
		button.pressed.connect(
			_on_answer_pressed.bind(symbol_index == correct_position)
		)
		_answer_box.add_child(button)


func _make_symbol_button(symbol: Variant) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 72)
	if symbol is String:
		button.text = symbol
		button.add_theme_font_size_override("font_size", 28)
	else:
		button.icon = symbol as Texture2D
		button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return button


func _clear_answers() -> void:
	for child in _answer_box.get_children():
		child.queue_free()


func _on_answer_pressed(correct: bool) -> void:
	if not _is_running or is_completed:
		return

	if not correct:
		_feedback.text = (
			mock_lines.pick_random()
			if not mock_lines.is_empty()
			else "Wrong. Start again."
		)
		_round = 0
		_start_round()
		return

	_round += 1
	if _round >= ROUNDS:
		is_completed = true
		_attempt_id += 1
		_title.text = ""
		_clear_symbols()
		_question.text = ""
		_clear_answers()
		_feedback.text = "Success! Your memory is sharp."
		puzzle_completed.emit()
		return
	_feedback.text = "Correct!"
	_start_round()


func _is_current(attempt: int) -> bool:
	return is_inside_tree() and attempt == _attempt_id and _is_running


func _close_puzzle() -> void:
	if not visible:
		return
	_is_running = false
	_attempt_id += 1
	hide()
	get_tree().paused = _was_tree_paused
	puzzle_closed.emit()

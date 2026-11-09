extends Control

signal puzzle_completed
signal puzzle_closed

const PAIR_COUNT := 6
const COLUMNS := 4
const MISMATCH_DELAY := 0.9
const SYMBOL_TEXTURES: Array[Texture2D] = [
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_001.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_002.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_003.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_004.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_005.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_006.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_007.png"),
	preload("res://assets/symbols/PNG/Black/Rectangle/runeBlack_rectangle_008.png")
]

var mock_lines: Array[String] = []
var is_completed := false
var _is_running := false
var _was_tree_paused := false
var _locked := false
var _first: Button = null
var _matched := 0
var _attempt_id := 0

@onready var _instruction: Label = %InstructionLabel
@onready var _grid: GridContainer = %CardGrid
@onready var _feedback: Label = %FeedbackLabel
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_grid.columns = COLUMNS
	_instruction.text = "Find all matching rune pairs."
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
		_grid.hide()
		_feedback.text = "This trial has already been completed."
		return
	_grid.show()
	_deal()


func _deal() -> void:
	_attempt_id += 1
	_first = null
	_matched = 0
	_locked = false
	_feedback.text = ""
	for child in _grid.get_children():
		child.queue_free()

	var symbols := SYMBOL_TEXTURES.duplicate()
	symbols.shuffle()
	var deck: Array = []
	for i in range(PAIR_COUNT):
		deck.append(symbols[i])
		deck.append(symbols[i])
	deck.shuffle()

	for symbol in deck:
		var card := Button.new()
		card.text = "?"
		card.custom_minimum_size = Vector2(90, 90)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.set_meta("symbol", symbol)
		card.pressed.connect(_on_card_pressed.bind(card))
		_grid.add_child(card)


func _on_card_pressed(card: Button) -> void:
	if not _is_running or _locked or card.disabled:
		return
	card.text = ""
	card.icon = card.get_meta("symbol") as Texture2D
	card.disabled = true

	if _first == null:
		_first = card
		return

	var first := _first
	_first = null
	_locked = true

	if first.get_meta("symbol") == card.get_meta("symbol"):
		_matched += 1
		_locked = false
		if _matched == PAIR_COUNT:
			is_completed = true
			_feedback.text = "Success! Every pair is found."
			puzzle_completed.emit()
		else:
			_feedback.text = "Match! %d of %d." % [_matched, PAIR_COUNT]
		return

	_feedback.text = (
		mock_lines.pick_random()
		if not mock_lines.is_empty()
		else "No match. Try again."
	)
	var attempt := _attempt_id
	await get_tree().create_timer(MISMATCH_DELAY, true).timeout
	if attempt != _attempt_id or not _is_running:
		return
	first.text = "?"
	first.icon = null
	first.disabled = false
	card.text = "?"
	card.icon = null
	card.disabled = false
	_locked = false


func _close_puzzle() -> void:
	if not visible:
		return
	_is_running = false
	_attempt_id += 1
	hide()
	get_tree().paused = _was_tree_paused
	puzzle_closed.emit()

extends Control

signal dialogue_finished

const CHARS_PER_SECOND := 40.0

@onready var panel: Control = %PanelContainer
@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var text_label = %DialogueText   # works for Label or RichTextLabel
@onready var continue_label: Button = %ContinueButton

var _lines: Array = []
var _index := 0
var _tween: Tween
var _typing := false
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep working while the game is paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()


# lines: Array of Dictionaries, e.g.
# [{"speaker": "Priestess", "text": "Hello!", "portrait": "res://art/priestess.png"}]
func start(lines: Array) -> void:
	if lines.is_empty() or _active:
		return
	_lines = lines
	_index = 0
	_active = true
	panel.show()
	get_tree().paused = true
	_show_line()


func _show_line() -> void:
	var line: Dictionary = _lines[_index]
	name_label.text = line.get("speaker", "")

	if line.has("portrait"):
		portrait.texture = load(line["portrait"])

	var text: String = line.get("text", "")
	text_label.text = text
	text_label.visible_ratio = 0.0
	continue_label.hide()
	_typing = true

	if _tween:
		_tween.kill()
	_tween = create_tween()
	var duration: float = max(text.length() / CHARS_PER_SECOND, 0.05)
	_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_tween.finished.connect(_on_typing_done)


func _on_typing_done() -> void:
	_typing = false
	continue_label.show()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()

	if _typing:
		# First press: finish the current line instantly
		_tween.kill()
		text_label.visible_ratio = 1.0
		_on_typing_done()
	else:
		# Second press: go to the next line, or close
		_index += 1
		if _index >= _lines.size():
			_close()
		else:
			_show_line()


func _close() -> void:
	_active = false
	panel.hide()
	get_tree().paused = false
	dialogue_finished.emit()

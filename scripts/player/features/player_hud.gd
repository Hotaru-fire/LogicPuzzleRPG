extends Control

@export var player_path: NodePath

@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPLabel
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar


func _ready() -> void:
	if not PlayerData.health_changed.is_connected(_on_health_changed):
		PlayerData.health_changed.connect(_on_health_changed)

	update_hp()


func _on_health_changed(_current_hp: int, _maximum_hp: int) -> void:
	update_hp()


func update_hp() -> void:
	if not is_instance_valid(hp_label) or not is_instance_valid(hp_bar):
		return

	hp_bar.max_value = PlayerData.current_max_hp
	hp_bar.value = PlayerData.current_hp
	hp_label.text = "HP: %d / %d" % [
		PlayerData.current_hp,
		PlayerData.current_max_hp
	]

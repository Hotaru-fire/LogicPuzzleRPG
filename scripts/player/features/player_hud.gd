extends Control

@export var player_path: NodePath

@onready var player: Node = get_node_or_null(player_path)
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPLabel
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaLabel
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar


func _ready() -> void:
	if not PlayerData.health_changed.is_connected(_on_health_changed):
		PlayerData.health_changed.connect(_on_health_changed)

	update_hp()
	update_mana()


func _process(_delta: float) -> void:
	update_mana()


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


func update_mana() -> void:
	if not is_instance_valid(player):
		return
	if not is_instance_valid(mana_label) or not is_instance_valid(mana_bar):
		return
	if not ("mana" in player) or not ("max_mana" in player):
		return

	var current_mana := int(player.get("mana"))
	var maximum_mana := maxi(int(player.get("max_mana")), 1)
	mana_bar.max_value = maximum_mana
	mana_bar.value = current_mana
	mana_label.text = "Mana: %d / %d" % [
		current_mana,
		maximum_mana
	]

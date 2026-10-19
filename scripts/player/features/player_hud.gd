extends Control

@export var player_path: NodePath

@onready var player = get_node(player_path)

@onready var hp_label = $MarginContainer/VBoxContainer/HPLabel
@onready var hp_bar = $MarginContainer/VBoxContainer/HPBar

@onready var mana_label = $MarginContainer/VBoxContainer/ManaLabel
@onready var mana_bar = $MarginContainer/VBoxContainer/ManaBar


func _process(_delta):

	if player == null:
		return

	# HP
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp

	hp_label.text = "HP: " + str(player.hp) + " / " + str(player.max_hp)

	# Mana
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana

extends Panel

# connect PATH
@onready var player = $"../../player"
@onready var hp_label = $VBoxContainer/HPLabel
@onready var mana_label = $VBoxContainer/ManaLabel
@onready var attack_label = $VBoxContainer/AttackLabel
@onready var defense_label = $VBoxContainer/DefenseLabel
@onready var strength_label = $VBoxContainer/StrengthLabel

func _ready():
	update_stats()


func update_stats():
	hp_label.text = "HP: " + str(player.hp) + " / " + str(player.max_hp)
	mana_label.text = "MANA: " + str(player.mana) + " / " + str(player.max_mana)
	attack_label.text = "ATTACK: " + str(player.attack)
	defense_label.text = "DEFENSE: " + str(player.defense)
	strength_label = "STRENGTH: " + str(player.strength)

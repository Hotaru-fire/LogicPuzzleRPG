extends Control

@onready var player = $"../../player"

@onready var skill_1_label = $HBoxContainer/Skill1/Label
@onready var skill_2_label = $HBoxContainer/Skill2/Label
@onready var skill_3_label = $HBoxContainer/Skill3/Label


func _process(_delta):

	if player.skill_1_cooldown > 0:
		skill_1_label.text = str(ceil(player.skill_1_cooldown))
	else:
		skill_1_label.text = ""

	if player.skill_2_cooldown > 0:
		skill_2_label.text = str(ceil(player.skill_2_cooldown))
	else:
		skill_2_label.text = ""

	if player.skill_3_cooldown > 0:
		skill_3_label.text = str(ceil(player.skill_3_cooldown))
	else:
		skill_3_label.text = ""

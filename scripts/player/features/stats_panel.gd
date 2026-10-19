extends Panel

# connect PATH
@onready var player = $"../../player"

@onready var hp_label = $VBoxContainer/HPLabel
@onready var mana_label = $VBoxContainer/ManaLabel
@onready var attack_label = $VBoxContainer/AttackLabel
@onready var defense_label = $VBoxContainer/DefenseLabel
@onready var strength_label = $VBoxContainer/StrengthLabel

# Skill labels
@onready var skill_1_label = $VBoxContainer/Skill1Label
@onready var skill_2_label = $VBoxContainer/Skill2Label
@onready var skill_3_label = $VBoxContainer/Skill3Label
@onready var passive_label = $VBoxContainer/PassiveLabel


func _ready():

	update_stats()
	update_skills()


func update_stats():

	hp_label.text = "HP: " + str(player.hp) + " / " + str(player.max_hp)
	mana_label.text = "MANA: " + str(player.mana) + " / " + str(player.max_mana)
	attack_label.text = "ATTACK: " + str(player.attack)
	defense_label.text = "DEFENSE: " + str(player.defense)
	strength_label.text = "STRENGTH: " + str(player.strength)


func update_skills():

	# Skill 1
	skill_1_label.text = "R — Skill 1\n" \
		+ "Deals AoE damage based on Attack.\n" \
		+ "Cooldown: 3 seconds."


	# Skill 2
	skill_2_label.text = "E — Skill 2\n" \
		+ "Continuously heals based on Defense.\n" \
		+ "Duration: 10 seconds.\n" \
		+ "Cooldown: 15 seconds."


	# Skill 3
	skill_3_label.text = "Q — Skill 3\n" \
		+ "Boosts the Knight's stats based on Honor."


	# Passive
	passive_label.text = "Passive — A Knight's Oath\n" \
		+ "Gain 1 Honor every 2 seconds after dealing damage.\n" \
		+ "Maximum Honor: 6."

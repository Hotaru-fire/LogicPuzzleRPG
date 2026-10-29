extends Panel

@onready var header_label: Label = $MarginContainer/MainVBox/HeaderLabel
@onready var level_value: Label = $MarginContainer/MainVBox/OverviewGrid/LevelCard/HBox/StatValue
@onready var gold_value: Label = $MarginContainer/MainVBox/OverviewGrid/GoldCard/HBox/StatValue
@onready var score_value: Label = $MarginContainer/MainVBox/OverviewGrid/ScoreCard/HBox/StatValue
@onready var playtime_value: Label = $MarginContainer/MainVBox/OverviewGrid/PlaytimeCard/HBox/StatValue
@onready var exp_value: Label = $MarginContainer/MainVBox/EXPCard/EXPSection/EXPHeader/EXPValueLabel
@onready var exp_progress: ProgressBar = $MarginContainer/MainVBox/EXPCard/EXPSection/EXPProgressBar
@onready var next_level_label: Label = $MarginContainer/MainVBox/EXPCard/EXPSection/NextLevelLabel
@onready var current_hp_value: Label = $MarginContainer/MainVBox/CombatGrid/CurrentHPCard/CardVBox/StatValue
@onready var max_hp_value: Label = $MarginContainer/MainVBox/CombatGrid/MaxHPCard/CardVBox/StatValue
@onready var attack_value: Label = $MarginContainer/MainVBox/CombatGrid/AttackCard/CardVBox/StatValue
@onready var defense_value: Label = $MarginContainer/MainVBox/CombatGrid/DefenseCard/CardVBox/StatValue
@onready var mobs_value: Label = $MarginContainer/MainVBox/BattleCard/BattleRecordVBox/MobsDefearedRow/StatValueLabel
@onready var dungeon_enemies_value: Label = $MarginContainer/MainVBox/BattleCard/BattleRecordVBox/DungeonEnemiesRow/StatValueLabel
@onready var bosses_value: Label = $MarginContainer/MainVBox/BattleCard/BattleRecordVBox/BossCompletedRow/StatValueLabel


func _ready() -> void:
	if not PlayerData.health_changed.is_connected(_on_health_changed):
		PlayerData.health_changed.connect(_on_health_changed)
	if not Session.stats_changed.is_connected(_on_stats_changed):
		Session.stats_changed.connect(_on_stats_changed)
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

	update_stats()


func _on_health_changed(_current_hp: int, _maximum_hp: int) -> void:
	update_stats()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		update_stats()


func _on_stats_changed() -> void:
	update_stats()


func update_stats() -> void:
	if not is_instance_valid(level_value):
		return

	var playtime := Session.get_playtime_snapshot()
	var playtime_seconds := int(playtime["playtime_seconds"])
	var required_exp := Session.exp_required_for_next_level()

	header_label.text = (
		"PLAYER PROFILE: "
		+ (Session.username if not Session.username.is_empty() else "PLAYER")
	)
	level_value.text = str(Session.level)
	gold_value.text = str(Session.gold)
	score_value.text = str(Session.score)
	playtime_value.text = _format_playtime(playtime_seconds)

	exp_progress.min_value = 0
	exp_progress.max_value = maxi(required_exp, 1)
	exp_progress.value = clampi(Session.player_exp, 0, required_exp)
	exp_value.text = "%d / %d EXP" % [
		Session.player_exp,
		required_exp
	]
	next_level_label.text = "%d EXP TO LEVEL %d" % [
		maxi(required_exp - Session.player_exp, 0),
		Session.level + 1
	]

	current_hp_value.text = str(PlayerData.current_hp)
	max_hp_value.text = str(PlayerData.current_max_hp)
	attack_value.text = str(PlayerData.saved_attack)
	defense_value.text = str(PlayerData.saved_defense)
	mobs_value.text = str(Session.mobs_defeated)
	dungeon_enemies_value.text = str(Session.dungeon_enemies_defeated)
	bosses_value.text = str(Session.bosses_killed)


func _format_playtime(total_seconds: int) -> String:
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

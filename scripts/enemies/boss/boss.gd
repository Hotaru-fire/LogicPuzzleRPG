extends CharacterBody2D

@export var boss_id := "minotaur"
@export var boss_name := "Juhantor, The Bison Guardian"
@export var hp := 500
@export var damage := 10
@export var exp_reward := 100
@export var gold_reward := 50
@export var score_reward := 100

@export var dungeon_scale := Vector2(2.0, 2.0)
@export var battle_scale := Vector2(6, 6)
@export var battle_position := Vector2(924, 182)

@export_multiline var intro_lines: PackedStringArray = [
	"So, you have completed the trials.",
	"No one leaves my labyrinth alive.",
	"Prepare yourself, hero!",
]

@onready var detection_area: Area2D = $DetectionArea
@onready var boss_sprite: AnimatedSprite2D = $AnimatedSprite2D

var battle_started := false
var passive := false
var dungeon_level := 1
var _base_hp := -1
var _base_damage := -1


func get_intro_lines() -> PackedStringArray:
	return intro_lines


func set_dungeon_level(level: int) -> void:
	dungeon_level = clampi(level, 1, Session.MAX_DUNGEON_LEVEL)
	if _base_hp < 0:
		_base_hp = hp
	if _base_damage < 0:
		_base_damage = damage
	hp = Session.scale_dungeon_stat(_base_hp, level, 1)
	damage = Session.scale_dungeon_stat(_base_damage, level)


func set_passive(value: bool) -> void:
	passive = value
	velocity = Vector2.ZERO


func _ready() -> void:
	scale = dungeon_scale
	add_to_group("enemies")

	if boss_sprite.sprite_frames != null:
		if boss_sprite.sprite_frames.has_animation("idle"):
			boss_sprite.play("idle")

	detection_area.body_entered.connect(_on_detection_area_body_entered)


func _on_detection_area_body_entered(body: Node2D) -> void:
	_try_start_battle(body)


func _physics_process(_delta: float) -> void:
	if battle_started or passive:
		return
	for body in detection_area.get_overlapping_bodies():
		_try_start_battle(body)


func _try_start_battle(body: Node2D) -> void:
	if battle_started or passive:
		return
	if not body.is_in_group("player"):
		return
	if Time.get_ticks_msec() < BattleData.battle_return_grace_until_msec:
		return
	start_battle(body)


func start_battle(body: Node2D) -> void:
	if battle_started:
		return
	battle_started = true
	print("Starting boss battle!")

	BattleData.boss_id = boss_id
	BattleData.enemy = self
	BattleData.enemy_name = boss_name
	BattleData.enemy_level = dungeon_level
	BattleData.enemy_type = "boss"
	BattleData.enemy_sprite_frames = boss_sprite.sprite_frames
	BattleData.enemy_sprite_frames_type = BattleData.enemy_type
	BattleData.enemy_hp = hp
	BattleData.enemy_damage = damage
	BattleData.enemy_exp_reward = exp_reward
	BattleData.enemy_gold_reward = gold_reward
	BattleData.enemy_score_reward = score_reward
	BattleData.boss_battle_scale = battle_scale
	BattleData.boss_battle_position = battle_position
	BattleData.enemy_defeated = false
	BattleData.kill_counted = false
	BattleData.enemy_is_dungeon = (
		get_tree().get_first_node_in_group("dungeon_manager") != null
	)
	BattleData.returning_from_battle = BattleData.enemy_is_dungeon
	if BattleData.enemy_is_dungeon:
		var dungeon_manager := get_tree().get_first_node_in_group("dungeon_manager")
		dungeon_manager.call("capture_room_enemies_for_battle", self)
	BattleData.return_position = body.global_position
	BattleData.return_scene = get_tree().current_scene.scene_file_path

	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/battle/enemy_battle.tscn"
	)

extends CharacterBody2D

@onready var detection_area: Area2D = $DetectionArea
@onready var boss_sprite: AnimatedSprite2D = $AnimatedSprite2D

var battle_started := false
@export var hp := 500
@export var damage := 10
var dungeon_level := 1
var _base_hp := -1
var _base_damage := -1


func set_dungeon_level(level: int) -> void:
	dungeon_level = clampi(level, 1, Session.MAX_DUNGEON_LEVEL)
	if _base_hp < 0:
		_base_hp = hp
	if _base_damage < 0:
		_base_damage = damage
	hp = Session.scale_dungeon_stat(_base_hp, level, 1)
	damage = Session.scale_dungeon_stat(_base_damage, level)


func _ready() -> void:
	print("Minotaur is ready!")

	if boss_sprite.sprite_frames != null:
		if boss_sprite.sprite_frames.has_animation("idle"):
			boss_sprite.play("idle")

	detection_area.body_entered.connect(_on_detection_area_body_entered)


func _on_detection_area_body_entered(body: Node2D) -> void:
	print("Something entered Minotaur detection: ", body.name)

	if battle_started:
		return

	if not body.is_in_group("player"):
		print("This body is not in the player group!")
		return

	battle_started = true
	print("Player detected! Starting boss battle!")

	BattleData.enemy = self
	BattleData.enemy_name = name
	BattleData.enemy_level = dungeon_level
	BattleData.enemy_type = "boss"
	BattleData.enemy_sprite_frames = boss_sprite.sprite_frames
	BattleData.enemy_sprite_frames_type = BattleData.enemy_type
	BattleData.enemy_hp = hp
	BattleData.enemy_damage = damage
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

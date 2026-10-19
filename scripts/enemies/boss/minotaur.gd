
extends CharacterBody2D

@onready var detection_area: Area2D = $DetectionArea
@onready var boss_sprite: AnimatedSprite2D = $AnimatedSprite2D

var battle_started := false

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

	get_tree().call_deferred(
	"change_scene_to_file",
	"res://scenes/battle/boss_battle.tscn"
)

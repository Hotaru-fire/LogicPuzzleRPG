extends Node2D

signal hit

@export var speed := 500.0
var has_hit := false


func launch(target: Vector2) -> void:
	rotation = (target - global_position).angle()
	var duration := global_position.distance_to(target) / speed
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, duration)
	tween.finished.connect(_on_arrived)


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _on_arrived() -> void:
	has_hit = true
	hit.emit()  # damage happens now, not after the effect

	if sprite.sprite_frames.has_animation("impact"):
		rotation = 0.0
		sprite.play("impact")
		await sprite.animation_finished
	queue_free()

extends Area2D


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	if body.is_in_group("player"):

		print("Player entered dungeon!")

		SceneTransition.change_scene("res://scenes/dungeon_1.tscn")

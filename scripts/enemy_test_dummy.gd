extends CharacterBody2D

var hp := 100

func take_damage(amount):
	hp -= amount

	print("Enemy HP: ", hp, "/ 100")

	if hp <= 0:
		die()

func die():
	print("Enemy defeated!")
	queue_free()

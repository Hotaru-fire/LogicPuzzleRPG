extends Camera2D

@export var speed: float = 40.0
@export var auto_scroll: bool = true


func _process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0.0 and auto_scroll:
		dir = 1.0
	position.x += dir * speed * delta
	var root := get_parent()
	if root.has_method("set_time"):
		if Input.is_action_just_pressed("ui_up"):
			root.set_time(floor(root._t) + 1.0)
		if Input.is_action_just_pressed("ui_down"):
			root.set_time(floor(root._t) + 3.0)

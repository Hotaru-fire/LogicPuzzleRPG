extends Control

const TIME_OF_DAY: Array[String] = [
	"Dawn",
	"Day",
	"Sunset",
	"Night"
]

@export var time_duration: float = 20.0
@export var transition_duration: float = 3.0

var current_time_index: int = 0
var scrolling_layers: Array[Dictionary] = []


func _ready() -> void:
	# Wait for Control nodes to calculate their sizes.
	await get_tree().process_frame

	# Prepare all four backgrounds.
	for time_name in TIME_OF_DAY:
		var background: Control = get_node(time_name)

		background.visible = false
		background.modulate.a = 1.0

		animate_background(background)

	# Show Dawn first.
	var first_background: Control = get_node("Dawn")
	first_background.visible = true
	first_background.modulate.a = 1.0

	start_time_cycle()


func animate_background(background: Control) -> void:
	animate_layer(background.get_node("Clouds"), 8.0)
	animate_layer(background.get_node("Mountains"), 3.0)
	animate_layer(background.get_node("Hills"), 5.0)
	animate_layer(background.get_node("Fog"), 10.0)
	animate_layer(background.get_node("Trees"), 7.0)
	animate_layer(background.get_node("Foreground"), 12.0)


# Register a pair of images for continuous scrolling to the right.
func animate_layer(layer: Control, speed: float) -> void:
	var layer_a: TextureRect = layer.get_node("LayerA")
	var layer_b: TextureRect = layer.get_node("LayerB")

	var image_width: float = layer_a.size.x

	if image_width <= 0.0:
		push_error("LayerA has an invalid width: " + str(layer.get_path()))
		return

	# Place the second image directly BEFORE (to the left of) the first.
	layer_b.position.x = layer_a.position.x - image_width

	scrolling_layers.append({
		"first": layer_a,
		"second": layer_b,
		"width": image_width,
		"speed": speed,
		"viewport_width": layer.size.x
	})


func _process(delta: float) -> void:
	# Move every registered layer continuously to the right.
	for layer_data in scrolling_layers:
		var first: TextureRect = layer_data["first"]
		var second: TextureRect = layer_data["second"]
		var image_width: float = layer_data["width"]
		var speed: float = layer_data["speed"]
		var viewport_width: float = layer_data["viewport_width"]

		var movement: float = speed * delta

		first.position.x += movement
		second.position.x += movement

		# When the first image leaves the right edge, put it behind the second.
		if first.position.x >= viewport_width:
			first.position.x = second.position.x - image_width

		# When the second image leaves the right edge, put it behind the first.
		if second.position.x >= viewport_width:
			second.position.x = first.position.x - image_width


# Automatically change the time of day at intervals.
func start_time_cycle() -> void:
	while true:
		await get_tree().create_timer(time_duration).timeout
		await change_time_of_day()


# Crossfade between the current and next background.
func change_time_of_day() -> void:
	var old_background: Control = get_node(
		TIME_OF_DAY[current_time_index]
	)

	current_time_index = (
		current_time_index + 1
	) % TIME_OF_DAY.size()

	var new_background: Control = get_node(
		TIME_OF_DAY[current_time_index]
	)

	new_background.visible = true
	new_background.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		old_background,
		"modulate:a",
		0.0,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		new_background,
		"modulate:a",
		1.0,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	old_background.visible = false
	old_background.modulate.a = 1.0

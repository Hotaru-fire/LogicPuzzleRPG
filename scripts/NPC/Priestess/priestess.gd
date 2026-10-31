extends CharacterBody2D

@export var follow_speed: float = 200.0
@export var follow_distance: float = 35.0
@export var interaction_distance: float = 60.0
@export var heal_amount: int = 50

# Drag UI/DialogueBox (the instance of DialogueBox.tscn) into this slot.
# If left empty, the script looks for a node in the group "dialogue_box".
@export var dialogue_box: Control
@export var auto_start_tutorial: bool = false
@export var start_tutorial_on_approach: bool = true
@export var tutorial_start_delay: float = 0.5

const TUTORIAL_LINES: Array = [
	{"speaker": "Priestess", "text": "Welcome, traveler. Let me show you how to survive out here."},
	{"speaker": "Priestess", "text": "Use WASD or the arrow keys to move."},
	{"speaker": "Priestess", "text": "Press Space to attack. Press E to talk to me or interact."},
	{"speaker": "Priestess", "text": "Talk to me any time if you need healing. May the light guide you."},
]

var player: Node2D = null
var player_nearby: bool = false
var dialogue_open: bool = false
var facing_direction: String = "down"

var tutorial_done: bool = false   # TODO: load/save this with your database save
var _tutorial_running: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		push_warning("Priestess could not find a player in the 'player' group.")

	# Fallback: find the dialogue box by group if the Inspector slot is empty.
	if dialogue_box == null:
		dialogue_box = get_tree().get_first_node_in_group("dialogue_box") as Control

	if dialogue_box != null:
		dialogue_box.dialogue_finished.connect(_on_dialogue_box_finished)
	else:
		push_warning("Priestess: dialogue_box is not assigned and no 'dialogue_box' group node was found.")

	play_idle_animation()

	if auto_start_tutorial and not tutorial_done and dialogue_box != null:
		await get_tree().create_timer(tutorial_start_delay).timeout
		start_tutorial()


func _physics_process(_delta: float) -> void:
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance_to_player: float = global_position.distance_to(
		player.global_position
	)

	# Stop moving while the dialogue is open.
	if dialogue_open:
		velocity = Vector2.ZERO
		face_player()
		move_and_slide()
		return

	# Follow the player when they are far enough away.
	if distance_to_player > follow_distance:
		var direction: Vector2 = (
			player.global_position - global_position
		).normalized()

		velocity = direction * follow_speed
		update_facing_from_direction(direction)
		play_walk_animation()
	else:
		velocity = Vector2.ZERO
		play_idle_animation()

	move_and_slide()

	# Allow interaction only when the player is close enough.
	player_nearby = (
		global_position.distance_to(player.global_position)
		<= interaction_distance
	)

	# Start the tutorial the first time she reaches the player.
	if start_tutorial_on_approach and not tutorial_done and player_nearby:
		start_tutorial()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		if player_nearby and not dialogue_open:
			open_dialogue()


func face_player() -> void:
	if player == null:
		return

	var direction: Vector2 = (
		player.global_position - global_position
	)

	update_facing_from_direction(direction)
	play_idle_animation()


func update_facing_from_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			facing_direction = "right"
		else:
			facing_direction = "left"
	else:
		if direction.y > 0.0:
			facing_direction = "down"
		else:
			facing_direction = "up"


func play_idle_animation() -> void:
	var animation_name: String = "idle_" + facing_direction

	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(animation_name):
			if sprite.animation != animation_name:
				sprite.play(animation_name)


func play_walk_animation() -> void:
	var animation_name: String = "walk_" + facing_direction

	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(animation_name):
			if sprite.animation != animation_name:
				sprite.play(animation_name)
		else:
			play_idle_animation()


# ---------------------------------------------------------------------------
# Tutorial (uses the DialogueBox UI)
# ---------------------------------------------------------------------------

func start_tutorial() -> void:
	print("start_tutorial called, dialogue_box = ", dialogue_box)

	if dialogue_box == null or _tutorial_running:
		return

	_tutorial_running = true
	tutorial_done = true
	dialogue_open = true
	velocity = Vector2.ZERO
	face_player()

	# The DialogueBox pauses the tree while it is open.
	dialogue_box.start(TUTORIAL_LINES)


func _on_dialogue_box_finished() -> void:
	if not _tutorial_running:
		return

	_tutorial_running = false
	dialogue_open = false
	play_idle_animation()


# ---------------------------------------------------------------------------
# Interact menu ("Help" replays the controls tutorial in the dialogue box)
# ---------------------------------------------------------------------------

func open_dialogue() -> void:
	dialogue_open = true
	velocity = Vector2.ZERO

	# Face the player without using a talking animation.
	face_player()

	print("Priestess: How may I help you?")
	print("1. Heal me")
	print("2. Help")
	print("3. Never mind")
	print("Press 1, 2, or 3 to choose an option.")


func close_dialogue() -> void:
	dialogue_open = false
	play_idle_animation()


func heal_player() -> void:
	if player == null:
		close_dialogue()
		return

	if not ("hp" in player) or not ("max_hp" in player):
		print("Priestess: I cannot heal you right now.")
		close_dialogue()
		return

	var current_hp: int = int(player.get("hp"))
	var maximum_hp: int = int(player.get("max_hp"))

	if current_hp >= maximum_hp:
		print("Priestess: Your health is already full.")
	else:
		var restored_hp: int = min(
			heal_amount,
			maximum_hp - current_hp
		)

		if player.has_method("heal"):
			player.call("heal", restored_hp)
		else:
			player.set("hp", current_hp + restored_hp)

		print(
			"Priestess: May the light restore you. Restored ",
			restored_hp,
			" HP."
		)

	close_dialogue()


func show_help() -> void:
	# Replay the controls tutorial in the dialogue box.
	if dialogue_box != null:
		start_tutorial()
	else:
		print(
			"Priestess: Stay alert. Explore carefully ",
			"and watch your health."
		)
		close_dialogue()


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_open or _tutorial_running:
		return

	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				heal_player()
				get_viewport().set_input_as_handled()
			KEY_2:
				show_help()
				get_viewport().set_input_as_handled()
			KEY_3:
				close_dialogue()
				get_viewport().set_input_as_handled()

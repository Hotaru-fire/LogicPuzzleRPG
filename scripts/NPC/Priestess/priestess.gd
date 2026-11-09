extends CharacterBody2D

signal walk_completed

const MAIN_MENU_SCENE := "res://scenes/main/MainMenu.tscn"

@export var follow_speed: float = 200.0
@export var follow_distance: float = 220.0
@export var companion_follow_distance: float = 48.0
@export var interaction_distance: float = 60.0
@export var heal_amount: int = 50
@export var dialogue_box: Control
@export var auto_start_tutorial: bool = false
@export var start_tutorial_on_approach: bool = true
@export var tutorial_start_delay: float = 0.5

var player: Node2D
var player_nearby := false
var dialogue_open := false
var tutorial_done := false
var is_companion := false
var facing_direction := "down"
var _walking_to_target := false
var _walk_target := Vector2.ZERO
var _follower: Node2D
var _following_player := false
var _persistent_dialogue_layer: CanvasLayer
var _scene_change_generation := 0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("Priestess could not find a player in the 'player' group.")

	if dialogue_box != null and dialogue_box.has_signal("dialogue_finished"):
		var finished_callback := Callable(self, "_on_dialogue_box_finished")
		if not dialogue_box.is_connected(
			"dialogue_finished",
			finished_callback
		):
			dialogue_box.connect("dialogue_finished", finished_callback)

	play_idle_animation()


func _physics_process(_delta: float) -> void:
	if _following_player:
		var current_scene := get_tree().current_scene
		var in_battle_scene := (
			current_scene != null
			and current_scene.scene_file_path.contains("/battle/")
		)
		if not in_battle_scene:
			var active_player := get_tree().get_first_node_in_group("player") as Node2D
			if (
				active_player != null
				and active_player.is_inside_tree()
				and active_player != player
			):
				sync_with_player(active_player)

	if _following_player and (
		not is_instance_valid(player)
		or not player.is_inside_tree()
	):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if not is_instance_valid(player) or not player.is_inside_tree():
			visible = false
			velocity = Vector2.ZERO
			return
		show()

	if _following_player:
		if not is_instance_valid(player) or dialogue_open:
			velocity = Vector2.ZERO
			play_idle_animation()
			move_and_slide()
			return

		player_nearby = global_position.distance_to(player.global_position) <= (
			interaction_distance
		)
		var follow_direction := player.global_position - global_position
		if follow_direction.length() > follow_distance:
			global_position = player.global_position + Vector2(-32.0, 0.0)
			follow_direction = player.global_position - global_position
		if follow_direction.length() <= companion_follow_distance:
			velocity = Vector2.ZERO
			play_idle_animation()
		else:
			follow_direction = follow_direction.normalized()
			update_facing_from_direction(follow_direction)
			velocity = follow_direction * follow_speed
			play_walk_animation()
		move_and_slide()
		return

	if player != null:
		player_nearby = global_position.distance_to(player.global_position) <= (
			interaction_distance
		)

	if not _walking_to_target or dialogue_open:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	if not is_instance_valid(_follower):
		_walking_to_target = false
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		walk_completed.emit()
		return

	if global_position.distance_to(_walk_target) <= 8.0:
		_walking_to_target = false
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		walk_completed.emit()
		return

	if global_position.distance_to(_follower.global_position) > follow_distance:
		velocity = Vector2.ZERO
		play_idle_animation()
		move_and_slide()
		return

	var direction := (_walk_target - global_position).normalized()
	update_facing_from_direction(direction)
	velocity = direction * follow_speed
	play_walk_animation()
	move_and_slide()


func walk_to(target: Vector2, follower: Node2D) -> void:
	if not is_instance_valid(follower):
		push_error("Priestess.walk_to requires a valid follower.")
		return

	_walk_target = target
	_follower = follower
	_walking_to_target = true


func become_companion(follower: Node2D, active_dialogue_box: Control) -> void:
	if not is_instance_valid(follower):
		push_error("Priestess.become_companion requires a valid player.")
		return

	dialogue_box = active_dialogue_box
	_connect_dialogue_finished()
	is_companion = true
	_walking_to_target = false
	add_to_group("priestess_companion")
	sync_with_player(follower)
	_make_dialogue_persistent()

	var tree := get_tree()
	var scene_changed_callback := Callable(self, "_on_scene_changed")
	if not tree.scene_changed.is_connected(scene_changed_callback):
		tree.scene_changed.connect(scene_changed_callback)

	if get_parent() != tree.root:
		call_deferred("_reparent_to_root")


func _reparent_to_root() -> void:
	if not is_inside_tree():
		return

	var root := get_tree().root
	if get_parent() != root:
		reparent(root, true)
		owner = null


func sync_with_player(follower: Node2D) -> void:
	if not is_instance_valid(follower):
		push_error("Priestess.sync_with_player requires a valid player.")
		return
	if not is_companion:
		return

	player = follower
	velocity = Vector2.ZERO
	dialogue_open = false
	global_position = player.global_position + Vector2(-32.0, 0.0)
	show()
	_following_player = true
	face_toward(player.global_position)


func _make_dialogue_persistent() -> void:
	if not is_instance_valid(dialogue_box):
		push_error("Priestess cannot become a companion without a DialogueBox.")
		return

	var root := get_tree().root
	_persistent_dialogue_layer = root.get_node_or_null(
		"PriestessDialogueLayer"
	) as CanvasLayer
	if _persistent_dialogue_layer == null:
		_persistent_dialogue_layer = CanvasLayer.new()
		_persistent_dialogue_layer.name = "PriestessDialogueLayer"
		_persistent_dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(_persistent_dialogue_layer)
	_persistent_dialogue_layer.layer = 10
	_persistent_dialogue_layer.show()

	call_deferred("_reparent_dialogue_box")


func _reparent_dialogue_box() -> void:
	if (
		not is_instance_valid(dialogue_box)
		or not is_instance_valid(_persistent_dialogue_layer)
	):
		return

	if dialogue_box.get_parent() != _persistent_dialogue_layer:
		dialogue_box.reparent(_persistent_dialogue_layer)
		dialogue_box.owner = null
	dialogue_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_box.position = Vector2.ZERO
	dialogue_box.show()


func _on_scene_changed() -> void:
	_scene_change_generation += 1
	var generation := _scene_change_generation
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.scene_file_path == MAIN_MENU_SCENE:
		if is_instance_valid(_persistent_dialogue_layer):
			_persistent_dialogue_layer.queue_free()
		queue_free()
		return

	for _attempt in range(10):
		await get_tree().process_frame
		if not is_inside_tree() or generation != _scene_change_generation:
			return

		var current_player := get_tree().get_first_node_in_group("player") as Node2D
		if current_player != null and current_player.is_inside_tree():
			sync_with_player(current_player)
			return

	player = null
	velocity = Vector2.ZERO


func face_toward(pos: Vector2) -> void:
	var direction := pos - global_position
	if direction == Vector2.ZERO:
		return
	update_facing_from_direction(direction)
	play_idle_animation()


func face_player() -> void:
	if player != null:
		face_toward(player.global_position)


func update_facing_from_direction(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		facing_direction = "right" if direction.x > 0.0 else "left"
	else:
		facing_direction = "down" if direction.y > 0.0 else "up"


func play_idle_animation() -> void:
	if not is_instance_valid(sprite):
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not is_instance_valid(sprite):
		return

	var animation_name := "idle_" + facing_direction
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(
		animation_name
	):
		if sprite.animation != animation_name:
			sprite.play(animation_name)


func play_walk_animation() -> void:
	if not is_instance_valid(sprite):
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not is_instance_valid(sprite):
		return

	var animation_name := "walk_" + facing_direction
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(
		animation_name
	):
		if sprite.animation != animation_name:
			sprite.play(animation_name)
	else:
		play_idle_animation()


func start_tutorial() -> void:
	var manager := get_tree().get_first_node_in_group("tutorial_manager")
	if manager != null and manager.has_method("start_tutorial"):
		manager.call("start_tutorial")


func _on_dialogue_box_finished() -> void:
	dialogue_open = false
	play_idle_animation()


func open_dialogue() -> void:
	if not is_companion or dialogue_open or _player_at_door():
		return

	dialogue_open = true
	velocity = Vector2.ZERO
	face_player()
	if not is_instance_valid(dialogue_box):
		push_error("Priestess has no valid DialogueBox for interaction.")
		dialogue_open = false
		return
	if not dialogue_box.has_method("start") or not dialogue_box.has_signal(
		"dialogue_finished"
	):
		push_error("Priestess DialogueBox does not expose its dialogue API.")
		dialogue_open = false
		return

	var name_label := dialogue_box.get_node_or_null("%NameLabel") as Label
	if name_label == null:
		push_error("Priestess DialogueBox is missing its name label.")
		dialogue_open = false
		return

	var message := "Your health is already full. Speak with me whenever you need aid."
	var current_hp: int = PlayerData.current_hp
	var maximum_hp: int = PlayerData.current_max_hp
	if current_hp < maximum_hp:
		var restored_hp: int = mini(heal_amount, maximum_hp - current_hp)
		if player.has_method("heal"):
			player.call("heal", restored_hp)
		else:
			PlayerData.set_current_hp(current_hp + restored_hp)
		message = "Of course, hero. May the light restore you. I healed %d HP." % (
			restored_hp
		)

	name_label.text = "Priestess"
	dialogue_box.call("start", [{"speaker": "Priestess", "text": message}])
	await Signal(dialogue_box, "dialogue_finished")
	dialogue_open = false

func _input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("interact")
		and player_nearby
		and is_companion
		and not dialogue_open
		and not _player_at_door()
		and not _trial_interaction_has_priority()
	):
		open_dialogue()


func _player_at_door() -> bool:
	for door in get_tree().get_nodes_in_group("room_door"):
		if door.get("player_nearby"):
			return true
	return false


func _trial_interaction_has_priority() -> bool:
	for trial_npc in get_tree().get_nodes_in_group("minotaur_trial"):
		if (
			trial_npc.has_method("should_prioritize_interaction")
			and trial_npc.call("should_prioritize_interaction")
		):
			return true
	return false


func _connect_dialogue_finished() -> void:
	if not is_instance_valid(dialogue_box):
		return
	if not dialogue_box.has_signal("dialogue_finished"):
		return
	var finished_callback := Callable(self, "_on_dialogue_box_finished")
	if not dialogue_box.is_connected("dialogue_finished", finished_callback):
		dialogue_box.connect("dialogue_finished", finished_callback)

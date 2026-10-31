extends Node

signal health_changed(current_hp: int, maximum_hp: int)

const DEFAULT_MAX_HP := 200

var player_name: String = ""
var selected_character: int = 0

var has_save_data: bool = false
var saved_position: Vector2 = Vector2.ZERO
var saved_hp: int = 0
var saved_mana: int = 0

var saved_max_hp: int = 200
var current_hp: int = DEFAULT_MAX_HP
var current_max_hp: int = DEFAULT_MAX_HP
var saved_attack: int = 30
var saved_defense: int = 10

var saved_current_scene: String = "res://scenes/maps/world.tscn"
var saved_boss_completed: bool = false

var saved_inventory: String = "[]"
var saved_equipment: String = "{}"


func set_health(value: int, maximum: int) -> void:
	var next_maximum := maxi(maximum, 1)
	var next_hp := clampi(value, 0, next_maximum)
	var changed := (
		next_hp != current_hp
		or next_maximum != current_max_hp
	)

	current_max_hp = next_maximum
	current_hp = next_hp
	saved_max_hp = next_maximum
	saved_hp = next_hp

	if changed:
		health_changed.emit(current_hp, current_max_hp)


func set_current_hp(value: int) -> void:
	set_health(value, current_max_hp)


func set_max_hp(value: int) -> void:
	set_health(current_hp, value)


func reset_health() -> void:
	set_health(DEFAULT_MAX_HP, DEFAULT_MAX_HP)

extends Node

var player_name: String = ""
var selected_character: int = 0

var has_save_data: bool = false
var saved_position: Vector2 = Vector2.ZERO
var saved_hp: int = 0
var saved_mana: int = 0

var saved_max_hp: int = 200
var saved_attack: int = 30
var saved_defense: int = 10

var saved_current_scene: String = "res://scenes/maps/world.tscn"
var saved_boss_completed: bool = false

var saved_inventory: String = "[]"
var saved_equipment: String = "{}"

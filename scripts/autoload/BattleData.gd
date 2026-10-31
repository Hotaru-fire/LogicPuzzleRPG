extends Node

var enemy = null
var enemy_name := ""

var enemy_hp := 20
var enemy_damage := 10
var enemy_exp_reward := 25
var enemy_gold_reward := 8
var enemy_score_reward := 10

var enemy_defeated := false
var kill_counted := false
var enemy_is_dungeon := false

var return_position := Vector2.ZERO
var return_scene := ""

extends Node2D

@export_enum("dawn", "day", "sunset", "night") var time_of_day: int = 1
@export var cycle: bool = false
@export var cycle_seconds: float = 40.0

var _t: float = 0.0
var _sets: Array[CanvasItem] = []


func _ready() -> void:
	for n in ["dawn", "day", "sunset", "night"]:
		_sets.append(get_node(n) as CanvasItem)
	_t = float(time_of_day)
	_apply(_t)


func _process(delta: float) -> void:
	if cycle:
		_t = fmod(_t + delta * 4.0 / cycle_seconds, 4.0)
		_apply(_t)


func set_time(value: float) -> void:
	_t = fposmod(value, 4.0)
	_apply(_t)


func _apply(t: float) -> void:
	var a: int = int(floor(t)) % 4
	var b: int = (a + 1) % 4
	var f: float = t - floor(t)
	for i in 4:
		_sets[i].visible = i == a or (i == b and f > 0.0)
		_sets[i].z_index = 0
		_sets[i].modulate.a = 1.0
	_sets[b].z_index = 1
	_sets[b].modulate.a = f

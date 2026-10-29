class_name PartyCamera
extends Camera2D
## Follows player 1 in solo. In co-op it frames both players, zooming out
## as they separate (down to `min_zoom`). Cutscenes can take it over with
## focus_on_node() / focus_on_point() and hand it back with clear_focus().

@export var solo_zoom := 1.5
@export var min_zoom := 0.8
## Extra space around the players when framing both (world pixels).
@export var margin := Vector2(420, 300)
@export var look_up := 80.0

var targets: Array = []
var frame_everyone := false

## While set (a boss fight), the camera frames the players AND this node.
var boss: Node2D = null
@export var boss_min_zoom := 0.62

var _focus_active := false
var _focus_node: Node2D = null
var _focus_point := Vector2.ZERO
var _focus_zoom := -1.0


func focus_on_node(node: Node2D, zoom_level := -1.0) -> void:
	_focus_active = true
	_focus_node = node
	_focus_zoom = zoom_level


func focus_on_point(point: Vector2, zoom_level := -1.0) -> void:
	_focus_active = true
	_focus_node = null
	_focus_point = point
	_focus_zoom = zoom_level


func clear_focus() -> void:
	_focus_active = false
	_focus_node = null


func is_focused() -> bool:
	return _focus_active


func _ready() -> void:
	add_to_group("party_camera")
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	zoom = Vector2(solo_zoom, solo_zoom)
	make_current()


func _process(delta: float) -> void:
	if _focus_active:
		var point := _focus_node.global_position + Vector2(0, -look_up) if is_instance_valid(_focus_node) else _focus_point
		global_position = point
		var fz := _focus_zoom if _focus_zoom > 0.0 else solo_zoom
		zoom = zoom.lerp(Vector2(fz, fz), 1.0 - exp(-3.0 * delta))
		return
	if targets.is_empty():
		return
	var center: Vector2 = targets[0].global_position
	var z := solo_zoom
	if is_instance_valid(boss):
		var bounds := Rect2(boss.global_position, Vector2.ZERO)
		for t in targets:
			bounds = bounds.expand(t.global_position)
		center = bounds.get_center() + Vector2(0, look_up)
		var view := get_viewport_rect().size
		var needed := bounds.size + margin
		z = clampf(minf(view.x / needed.x, view.y / needed.y), boss_min_zoom, solo_zoom)
	elif frame_everyone and targets.size() > 1:
		var bounds := Rect2(center, Vector2.ZERO)
		for t in targets:
			bounds = bounds.expand(t.global_position)
		center = bounds.get_center()
		var view := get_viewport_rect().size
		var needed := bounds.size + margin
		z = clampf(minf(view.x / needed.x, view.y / needed.y), min_zoom, solo_zoom)
	global_position = center + Vector2(0, -look_up)
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-4.0 * delta))

@tool
class_name SightPlatform
extends StaticBody2D
## Platforms that depend on Solar/Lunar sight.
##
## TRUE_PATH - invisible and not solid until sight is open. Hidden truth.
## ILLUSION  - looks solid with sight closed, but you fall right through.
##             With sight open it shows up as a flickering outline.
##
## `for_eye` restricts which eye can see it (&"Solar", &"Lunar", or empty for
## both) — use it for puzzles that force a character swap.

enum Kind { TRUE_PATH, ILLUSION }

@export var kind: Kind = Kind.TRUE_PATH:
	set(value):
		kind = value
		queue_redraw()
@export var size := Vector2(120, 20):
	set(value):
		size = value
		queue_redraw()
@export var for_eye: StringName = &""

var _shape: CollisionShape2D
var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	Sight.changed.connect(_on_sight_changed)
	_on_sight_changed(Sight.active, Sight.eye)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()


func _on_sight_changed(_active: bool, _eye: StringName) -> void:
	var solid := kind == Kind.TRUE_PATH and Sight.can_see(for_eye)
	_shape.set_deferred("disabled", not solid)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	if Engine.is_editor_hint():
		var c := Color(1, 0.8, 0.3) if kind == Kind.TRUE_PATH else Color(0.7, 0.5, 1)
		draw_rect(rect, Color(c, 0.25))
		draw_rect(rect, c, false, 2.0)
		return
	var seen := Sight.can_see(for_eye)
	match kind:
		Kind.TRUE_PATH:
			if seen:
				var glow := Color(1.0, 0.85, 0.45) if Sight.eye == Sight.SOLAR else Color(0.6, 0.75, 1.0)
				draw_rect(rect.grow(3.0), Color(glow, 0.25 + 0.1 * sin(_time * 4.0)))
				draw_rect(rect, Color(glow, 0.85))
		Kind.ILLUSION:
			if seen:
				var a := 0.25 + 0.2 * absf(sin(_time * 11.0))
				draw_rect(rect, Color(0.8, 0.5, 1.0, a), false, 2.0)
			else:
				# Looks exactly like jungle ground: soil with a grassy top.
				draw_rect(rect, Color(0.23, 0.15, 0.13))
				draw_rect(rect, Color(0.42, 0.3, 0.24), false, 3.0)
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color(0.33, 0.68, 0.27))
				draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(0.56, 0.84, 0.36), 2.0)

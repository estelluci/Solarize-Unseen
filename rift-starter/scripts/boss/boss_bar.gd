class_name BossBar
extends CanvasLayer
## Boss health bar along the bottom of the screen: name, health with phase
## notches, the core's current colour, and a one-line hint telling players
## which eye to open.

const SOLAR := Color(1.0, 0.78, 0.3)
const LUNAR := Color(0.65, 0.8, 1.0)

var boss: MawBoss
var _panel: Control
var _name: Label
var _hint: Label
var _shown_hp := 1.0


func _ready() -> void:
	layer = 20
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_bar)
	add_child(_panel)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95))
	_panel.add_child(_name)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_panel.add_child(_hint)
	visible = false


func show_bar(on: bool) -> void:
	visible = on


func _process(delta: float) -> void:
	if not visible or boss == null:
		return
	var view := get_viewport().get_visible_rect().size
	var target := float(boss.hp) / float(boss.max_hp)
	_shown_hp = move_toward(_shown_hp, target, delta * 0.8)
	_name.text = boss.display_name.to_upper() + ("   -   phase %d" % boss.phase)
	_name.position = Vector2(view.x * 0.5 - 300.0, view.y - 96.0)
	_hint.text = boss.hint()
	_hint.position = Vector2(view.x * 0.5 - 300.0, view.y - 40.0)
	var col := SOLAR if boss.core_eye == Sight.SOLAR else LUNAR
	_hint.add_theme_color_override("font_color", col.lightened(0.2) if not boss.shielded else Color(0.85, 0.75, 1.0))
	_panel.queue_redraw()


func _draw_bar() -> void:
	if boss == null:
		return
	var view := get_viewport().get_visible_rect().size
	var rect := Rect2(view.x * 0.5 - 300.0, view.y - 66.0, 600.0, 16.0)
	_panel.draw_rect(rect.grow(3.0), Color(0.05, 0.02, 0.08, 0.85))
	var col := SOLAR if boss.core_eye == Sight.SOLAR else LUNAR
	if boss.shielded:
		col = Color(0.55, 0.45, 0.75)
	var hp_ratio := float(boss.hp) / float(boss.max_hp)
	_panel.draw_rect(Rect2(rect.position, Vector2(rect.size.x * _shown_hp, rect.size.y)), Color(1, 1, 1, 0.35))
	_panel.draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp_ratio, rect.size.y)), col)
	for notch in [1.0 / 3.0, 2.0 / 3.0]:
		var x: float = rect.position.x + rect.size.x * notch
		_panel.draw_line(Vector2(x, rect.position.y - 3), Vector2(x, rect.end.y + 3), Color(1, 1, 1, 0.7), 2.0)

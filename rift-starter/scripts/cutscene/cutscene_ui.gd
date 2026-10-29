class_name CutsceneUI
extends CanvasLayer
## Screen-space pieces of a cutscene: letterbox bars, the fade, and the
## dialogue box with a typewriter effect. Owned by the Cutscenes director.

const BAR_HEIGHT := 70.0
const PANEL_BG := Color(0.05, 0.1, 0.08, 0.92)
const PANEL_EDGE := Color(1.0, 0.8, 0.45, 0.8)

var _top: ColorRect
var _bottom: ColorRect
var _fade: ColorRect
var _panel: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _letterbox := 0.0
var _letterbox_target := 0.0


func _ready() -> void:
	layer = 30
	_top = _bar()
	_bottom = _bar()
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var vbox := VBoxContainer.new()
	_panel.add_child(vbox)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 18)
	_text.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_text.custom_minimum_size = Vector2(0, 52)
	vbox.add_child(_text)
	_hint = Label.new()
	_hint.text = "Space / Enter ▸      Esc: skip"
	_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7, 0.8))
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint)
	_panel.visible = false


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.03, 0.02, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _process(delta: float) -> void:
	_letterbox = move_toward(_letterbox, _letterbox_target, delta * 3.0)
	var view := get_viewport().get_visible_rect().size
	var h := BAR_HEIGHT * _letterbox
	_top.position = Vector2.ZERO
	_top.size = Vector2(view.x, h)
	_bottom.position = Vector2(0, view.y - h)
	_bottom.size = Vector2(view.x, h)
	var w := minf(view.x - 80.0, 900.0)
	_panel.size = Vector2(w, 0)
	_panel.position = Vector2((view.x - w) * 0.5, view.y - h - _panel.size.y - 18.0)


func set_letterbox(on: bool, instant := false) -> void:
	_letterbox_target = 1.0 if on else 0.0
	if instant:
		_letterbox = _letterbox_target


func set_fade(alpha: float) -> void:
	_fade.color.a = clampf(alpha, 0.0, 1.0)


func get_fade() -> float:
	return _fade.color.a


func show_line(speaker: String, color: Color, text: String) -> void:
	_panel.visible = true
	_name.visible = speaker != ""
	_name.text = speaker
	_name.add_theme_color_override("font_color", color)
	_text.text = text
	_text.visible_characters = 0


func set_visible_chars(n: int) -> void:
	_text.visible_characters = n


func line_length() -> int:
	return _text.get_total_character_count()


func hide_line() -> void:
	_panel.visible = false


func is_line_visible() -> bool:
	return _panel.visible


func current_text() -> String:
	return _text.text

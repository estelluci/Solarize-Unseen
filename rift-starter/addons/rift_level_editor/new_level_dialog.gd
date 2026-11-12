@tool
extends ConfirmationDialog
## "New level..." window: name, length, ground style and starting layout.

signal created(path: String, make_main: bool)

const Builder := preload("res://addons/rift_level_editor/level_builder.gd")
const LENGTHS := [["Short (2,000 px)", 2000.0], ["Medium (4,000 px)", 4000.0], ["Long (6,000 px)", 6000.0]]

var _name: LineEdit
var _length: OptionButton
var _style: OptionButton
var _gap: CheckBox
var _main: CheckBox
var _path: Label
var _error: Label
var _retry := false   # reopening after an error keeps what was typed


func _init() -> void:
	title = "New level"
	ok_button_text = "Create level"
	min_size = Vector2i(420, 0)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	add_child(grid)
	_name = LineEdit.new()
	_name.placeholder_text = "e.g. Volcano Climb"
	_name.custom_minimum_size.x = 240
	_name.text_changed.connect(func(_t): _update())
	_row(grid, "Name", _name)
	_length = OptionButton.new()
	for l in LENGTHS:
		_length.add_item(l[0])
	_row(grid, "Length", _length)
	_style = OptionButton.new()
	_style.add_item("Jungle (grass, flowers)")
	_style.add_item("Basalt (dark rock)")
	_style.add_item("Plain (outline only)")
	_row(grid, "Ground", _style)
	_gap = CheckBox.new()
	_gap.text = "Start with a water gap in the middle"
	_row(grid, "Layout", _gap)
	_main = CheckBox.new()
	_main.text = "Play this level when the game starts (F5)"
	_row(grid, "", _main)
	_path = Label.new()
	_path.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_row(grid, "Saved as", _path)
	_error = Label.new()
	_error.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_row(grid, "", _error)
	confirmed.connect(_create)
	about_to_popup.connect(_on_popup)
	register_text_enter(_name)


func _on_popup() -> void:
	if not _retry:
		_name.text = ""
		_error.text = ""
	_retry = false
	_update()
	_name.grab_focus.call_deferred()


func _row(grid: GridContainer, text: String, field: Control) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(field)


func _update() -> void:
	var n := _name.text.strip_edges()
	_path.text = Builder.path_for(n) if n != "" else "-"
	get_ok_button().disabled = n == ""


func _create() -> void:
	var result := Builder.build({
		"name": _name.text,
		"length": LENGTHS[_length.selected][1],
		"style": _style.selected,
		"gap": _gap.button_pressed,
	})
	if result.has("error"):
		_error.text = result.error
		_retry = true
		popup_centered.call_deferred()
		return
	created.emit(result.path, _main.button_pressed)

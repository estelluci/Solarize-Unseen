extends CanvasLayer
## Upgrade menu (U / gamepad Select). Pauses the game, lists every upgrade by
## character with its effect and why it is or isn't available, and buys on
## click / Enter. Built from the Upgrades registry, so new upgrade files show
## up here automatically.

signal opened
signal closed

const BG := Color(0.06, 0.13, 0.1, 0.94)
const GOLD := Color(1.0, 0.82, 0.45)
const LEAF := Color(0.55, 0.85, 0.55)
const MUTED := Color(0.6, 0.66, 0.62)

var is_open := false
var _root: Control
var _title: Label
var _columns: HBoxContainer
var _detail: Label


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	Upgrades.changed.connect(_refresh_if_open)
	GameState.changed.connect(_refresh_if_open)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("upgrades_menu"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or Cutscenes.is_playing:
		return
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_refresh()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	_root.visible = false
	closed.emit()


func _refresh_if_open() -> void:
	if is_open:
		_refresh()


# ---------------------------------------------------------------- building
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = GOLD.darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1080, 560)
	panel.position = Vector2(-540, -280)
	_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_title)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 16)
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_columns)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", LEAF)
	_detail.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(_detail)
	var hint := Label.new()
	hint.text = "Click or Enter to buy  ·  U / Esc to close"
	hint.add_theme_color_override("font_color", MUTED)
	vbox.add_child(hint)


func _refresh() -> void:
	_title.text = "Upgrades  —  Lumen Shards: %d" % GameState.shards
	for c in _columns.get_children():
		c.queue_free()
	var first_button: Button = null
	for group in [[&"mafia", "Mafia"], [&"fairy", "Fairy"], [&"party", "Both"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 6)
		var head := Label.new()
		head.text = group[1]
		head.add_theme_font_size_override("font_size", 18)
		head.add_theme_color_override("font_color", LEAF)
		col.add_child(head)
		for u in Upgrades.list_for(group[0]):
			var b := _make_button(u)
			col.add_child(b)
			if first_button == null and not b.disabled:
				first_button = b
		_columns.add_child(col)
	if first_button:
		first_button.call_deferred("grab_focus")


func _make_button(u: Upgrade) -> Button:
	var st: Array = Upgrades.status(u.id)
	var b := Button.new()
	b.name = String(u.id)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 56)
	var mark := ""
	match st[0]:
		Upgrades.State.OWNED: mark = "[owned] "
		Upgrades.State.LOCKED: mark = "[locked] "
	b.text = "%s%s\n    %s" % [mark, u.display_name, st[1]]
	b.disabled = st[0] != Upgrades.State.AVAILABLE
	b.tooltip_text = u.description
	b.focus_entered.connect(_show_detail.bind(u))
	b.mouse_entered.connect(_show_detail.bind(u))
	b.pressed.connect(func():
		if Upgrades.buy(u.id):
			_refresh())
	return b


func _show_detail(u: Upgrade) -> void:
	_detail.text = "%s — %s\n%s" % [u.display_name, u.description, u.effects_text()]

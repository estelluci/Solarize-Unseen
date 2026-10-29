extends Node
## Global "Solar / Lunar sight" state (autoload named `Sight`).
##
## Story: people from reality can have a Solar eye, people from the fantasy
## realm a Lunar eye. With sight open you can see portals, true paths and
## illusions. Anything that cares listens to `changed`.

signal changed(active: bool, eye: StringName)

const SOLAR := &"Solar"
const LUNAR := &"Lunar"

var active := false
## Which eye the current character has. Set by the player on character swap.
var eye: StringName = SOLAR


func toggle() -> void:
	set_active(not active)


func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	changed.emit(active, eye)


## A character presses their sight key: open *their* eye, or close it if it's
## already the one open. (In co-op, whoever pressed last decides the eye.)
func toggle_eye(value: StringName) -> void:
	if active and eye == value:
		set_active(false)
		return
	eye = value
	active = true
	changed.emit(active, eye)


func set_eye(value: StringName) -> void:
	if value == eye:
		return
	eye = value
	changed.emit(active, eye)


## True when sight is open AND the current eye can see things tagged `for_eye`.
## Pass &"" (empty) for "any eye".
func can_see(for_eye: StringName = &"") -> bool:
	return active and (for_eye == &"" or for_eye == eye)

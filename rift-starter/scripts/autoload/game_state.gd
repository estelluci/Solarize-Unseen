extends Node
## Everything about a playthrough that should survive a save (autoload
## `GameState`): story flags, Lumen Shards and owned upgrades.
##
## Cutscenes, triggers, pickups and the upgrade menu all read and write here,
## so "logic" like "only after the tendril cutscene" is just a flag check.

signal changed
## Short messages for the HUD ("Game saved").
signal notice(text: String)

const DEFAULT_SAVE := "user://save.json"

var flags: Dictionary = {}          ## StringName -> true
var shards := 0
var owned_upgrades: Array[StringName] = []


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		if save_game():
			notice.emit("Game saved")
	elif event.is_action_pressed("quick_load"):
		notice.emit("Game loaded" if load_game() else "No save yet")


# ---------------------------------------------------------------- flags
func set_flag(flag: StringName) -> void:
	if not flags.has(flag):
		flags[flag] = true
		changed.emit()


func clear_flag(flag: StringName) -> void:
	if flags.erase(flag):
		changed.emit()


func has_flag(flag: StringName) -> bool:
	return flags.has(flag)


# ---------------------------------------------------------------- shards
func add_shards(amount: int) -> void:
	shards += amount
	changed.emit()


func spend_shards(amount: int) -> bool:
	if amount > shards:
		return false
	shards -= amount
	changed.emit()
	return true


# ---------------------------------------------------------------- upgrades
## Low level: use Upgrades.buy() / Upgrades.grant() instead, which check rules
## and refresh the characters.
func own_upgrade(upgrade_id: StringName) -> void:
	if not owned_upgrades.has(upgrade_id):
		owned_upgrades.append(upgrade_id)
		changed.emit()


func has_upgrade(upgrade_id: StringName) -> bool:
	return owned_upgrades.has(upgrade_id)


# ---------------------------------------------------------------- save / load
func reset() -> void:
	flags.clear()
	shards = 0
	owned_upgrades.clear()
	changed.emit()


func to_dict() -> Dictionary:
	var f := []
	for k in flags.keys():
		f.append(String(k))
	var u := []
	for k in owned_upgrades:
		u.append(String(k))
	return {"version": 1, "flags": f, "shards": shards, "upgrades": u}


func from_dict(data: Dictionary) -> void:
	flags.clear()
	for f in data.get("flags", []):
		flags[StringName(f)] = true
	shards = int(data.get("shards", 0))
	owned_upgrades.clear()
	for u in data.get("upgrades", []):
		owned_upgrades.append(StringName(u))
	changed.emit()


func save_game(path := DEFAULT_SAVE) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: can't write %s" % path)
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	return true


func load_game(path := DEFAULT_SAVE) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameState: %s is not a valid save" % path)
		return false
	from_dict(parsed)
	# Let upgrades refresh character stats.
	if has_node("/root/Upgrades"):
		get_node("/root/Upgrades").changed.emit()
	return true

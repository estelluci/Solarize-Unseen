extends Node
## Upgrade registry and rules (autoload `Upgrades`).
##
## * Loads every Upgrade resource in res://upgrades/ at startup.
## * Decides what's buyable: not owned, prerequisites owned, story flags set,
##   enough shards.
## * Builds each character's *runtime* profile: the base CharacterProfile with
##   all owned upgrades applied. Gameplay code keeps reading `player.profile`
##   and never needs to know upgrades exist.

signal changed

const UPGRADE_DIR := "res://upgrades/"

enum State { OWNED, AVAILABLE, LOCKED, TOO_EXPENSIVE }

var _by_id: Dictionary = {}       ## StringName -> Upgrade
var _ordered: Array[Upgrade] = []


func _ready() -> void:
	load_all()


func load_all(dir_path := UPGRADE_DIR) -> void:
	_by_id.clear()
	_ordered.clear()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Upgrades: no folder %s" % dir_path)
		return
	for file in dir.get_files():
		# Exported games list "x.tres.remap"; load by the original name.
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res := load(dir_path.path_join(file))
		if res is Upgrade:
			if _by_id.has(res.id):
				push_error("Upgrades: duplicate id '%s' in %s" % [res.id, file])
				continue
			_by_id[res.id] = res
			_ordered.append(res)
	_ordered.sort_custom(func(a: Upgrade, b: Upgrade):
		return a.sort_order < b.sort_order if a.sort_order != b.sort_order else String(a.id) < String(b.id))


func get_upgrade(upgrade_id: StringName) -> Upgrade:
	return _by_id.get(upgrade_id)


func all_upgrades() -> Array[Upgrade]:
	return _ordered


## Upgrades shown under one heading of the menu (&"mafia", &"fairy", &"party").
func list_for(target: StringName) -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	for u in _ordered:
		if u.target == target:
			out.append(u)
	return out


func is_owned(upgrade_id: StringName) -> bool:
	return GameState.has_upgrade(upgrade_id)


## [State, reason] for menus: why can or can't this be bought right now?
func status(upgrade_id: StringName) -> Array:
	var u := get_upgrade(upgrade_id)
	if u == null:
		return [State.LOCKED, "Unknown upgrade"]
	if is_owned(upgrade_id):
		return [State.OWNED, "Owned"]
	var missing := PackedStringArray()
	for req in u.requires:
		if not is_owned(req):
			var r := get_upgrade(req)
			missing.append(r.display_name if r else String(req))
	if not missing.is_empty():
		return [State.LOCKED, "Requires " + ", ".join(missing)]
	for flag in u.requires_flags:
		if not GameState.has_flag(flag):
			return [State.LOCKED, "Not discovered yet"]
	if GameState.shards < u.cost:
		return [State.TOO_EXPENSIVE, "Needs %d shard%s" % [u.cost, "" if u.cost == 1 else "s"]]
	return [State.AVAILABLE, "%d shard%s" % [u.cost, "" if u.cost == 1 else "s"]]


func can_buy(upgrade_id: StringName) -> bool:
	return status(upgrade_id)[0] == State.AVAILABLE


## Spend shards and own the upgrade if every rule allows it.
func buy(upgrade_id: StringName) -> bool:
	if not can_buy(upgrade_id):
		return false
	GameState.spend_shards(get_upgrade(upgrade_id).cost)
	GameState.own_upgrade(upgrade_id)
	changed.emit()
	return true


## Give an upgrade for free (story rewards). Ignores cost and prerequisites.
func grant(upgrade_id: StringName) -> bool:
	if get_upgrade(upgrade_id) == null:
		push_error("Upgrades: unknown upgrade '%s'" % upgrade_id)
		return false
	if is_owned(upgrade_id):
		return false
	GameState.own_upgrade(upgrade_id)
	changed.emit()
	return true


## A fresh copy of `base` with every owned upgrade applied.
func build_profile(base: CharacterProfile) -> CharacterProfile:
	var p: CharacterProfile = base.duplicate()
	p.abilities = base.abilities.duplicate()
	var sets := {}
	var adds := {}
	var muls := {}
	for u in _ordered:
		if not is_owned(u.id) or not u.applies_to(base.id):
			continue
		for m in u.modifiers:
			match m.op:
				StatModifier.Op.SET:
					sets[m.stat] = m.value
				StatModifier.Op.ADD:
					adds[m.stat] = adds.get(m.stat, 0.0) + m.value
				StatModifier.Op.MULTIPLY:
					muls[m.stat] = muls.get(m.stat, 1.0) * m.value
		for a in u.grants_abilities:
			if not p.abilities.has(a):
				p.abilities.append(a)
	var stats := {}
	for s in sets.keys() + adds.keys() + muls.keys():
		stats[s] = true
	for stat in stats.keys():
		var value: float = sets.get(stat, float(p.get(stat)))
		value = (value + adds.get(stat, 0.0)) * muls.get(stat, 1.0)
		if typeof(p.get(stat)) == TYPE_INT:
			p.set(stat, int(roundf(value)))
		else:
			p.set(stat, value)
	return p


## Checks every upgrade file for authoring mistakes. Returns error strings.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var probe := CharacterProfile.new()
	var valid_targets := [&"party", &"mafia", &"fairy"]
	for u in _ordered:
		if u.id == &"":
			errors.append("An upgrade has no id")
		if not valid_targets.has(u.target):
			errors.append("%s: unknown target '%s'" % [u.id, u.target])
		for m in u.modifiers:
			if m == null or not (m.stat in probe):
				errors.append("%s: modifier changes unknown stat '%s'" % [u.id, m.stat if m else "<null>"])
			elif typeof(probe.get(m.stat)) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("%s: stat '%s' is not a number" % [u.id, m.stat])
		for req in u.requires:
			if not _by_id.has(req):
				errors.append("%s: requires missing upgrade '%s'" % [u.id, req])
	# Prerequisite cycles (A needs B needs A) would make both unbuyable.
	for u in _ordered:
		if _has_cycle(u.id, {}):
			errors.append("%s: prerequisite cycle" % u.id)
	return errors


func _has_cycle(upgrade_id: StringName, visiting: Dictionary) -> bool:
	if visiting.has(upgrade_id):
		return true
	var u := get_upgrade(upgrade_id)
	if u == null:
		return false
	visiting[upgrade_id] = true
	for req in u.requires:
		if _has_cycle(req, visiting.duplicate()):
			return true
	return false

class_name Upgrade
extends Resource
## One purchasable upgrade. Each lives in its own file in res://upgrades/ and
## is picked up automatically — adding an upgrade never needs code changes
## unless it grants a brand-new ability.
##
## An upgrade can:
##   * change stats through StatModifiers (numbers in the CharacterProfile),
##   * grant named abilities that code checks with Player.has_ability(),
##   * depend on other upgrades (`requires`) and on story flags
##     (`requires_flags`, set by cutscenes or gameplay).

## Unique id, also used by cutscenes ("give_upgrade wall_jump") and saves.
@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Who benefits: a character id (&"mafia", &"fairy") or &"party" for both.
@export var target: StringName = &"party"
## Cost in Lumen Shards.
@export var cost := 1
## Upgrades that must be owned first.
@export var requires: Array[StringName] = []
## Story flags that must be set first (see GameState).
@export var requires_flags: Array[StringName] = []
@export var modifiers: Array[StatModifier] = []
@export var grants_abilities: Array[StringName] = []
## Order inside the menu (lower first).
@export var sort_order := 0


func applies_to(character_id: StringName) -> bool:
	return target == &"party" or target == character_id


## Human-readable effect list for menus, e.g. "pix_max +40, wall_jump".
func effects_text() -> String:
	var parts := PackedStringArray()
	for m in modifiers:
		parts.append(m.describe())
	for a in grants_abilities:
		parts.append("new ability: %s" % a)
	return ", ".join(parts)

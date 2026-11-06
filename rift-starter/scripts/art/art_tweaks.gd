class_name ArtTweaks
extends Resource
## Per-slot adjustments for drop-in art. Open res://art/art_tweaks.tres,
## add an entry named after the slot (e.g. "mafia_head") and adjust it.

@export var tweaks: Dictionary[StringName, ArtTweak] = {}

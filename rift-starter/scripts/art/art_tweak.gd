class_name ArtTweak
extends Resource
## Optional fine-tuning for one art slot, kept in res://art/art_tweaks.tres.
## You only need this when a drop-in image doesn't line up perfectly.

## Bigger or smaller than the slot's standard size (1 = standard).
@export var scale := 1.0
## Nudge in the image's own pixels (moves with the animation).
@export var offset := Vector2.ZERO
## Extra rotation, in degrees.
@export var rotation_degrees := 0.0
## Mirror the image left-right.
@export var flip_h := false
## Attach point inside the image (0-1 across, 0-1 down). Negative = use the slot's default.
@export var pivot := Vector2(-1, -1)
## Multiply the image's colours (white = unchanged).
@export var tint := Color.WHITE
## UI slots only: border size in pixels that stays unstretched (-1 = default).
@export var nine_slice_margin := -1

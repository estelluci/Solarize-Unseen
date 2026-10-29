class_name RigContext
extends RefCounted
## What the player controller tells the rig every physics frame.
## Rigs only *read* this — gameplay never depends on how a rig draws.

var velocity := Vector2.ZERO
var on_floor := true
var facing := 1            ## 1 = right, -1 = left
var run_speed := 260.0     ## current character's top speed (for normalising)
var aiming := false
var aim_point := Vector2.ZERO  ## global position the arm should reach toward
var gliding := false
var carrying := false          ## this character is holding its partner
var carried := false           ## this character is being held
var grip_point := Vector2.ZERO ## global point the hands reach for while carrying / carried

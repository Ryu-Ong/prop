extends Node2D
var pos:Vector2
var rota:float
var dir: float
var speed = 20

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global_position=pos
	global_rotation=rota
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_position+=Vector2(speed, 0).rotated(dir)
	pass

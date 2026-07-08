extends Node2D


var canHit = true
var baton = preload("res://baton.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func Fire():
	if canHit == true:
		var baton = baton.instantiate()
		baton.dir=rotation
		baton.pos= global_position
		baton.rota=global_rotation
		get_parent().add_child(baton)
		


func _physics_process(delta: float) -> void:
	look_at(get_global_mouse_position())
	if Input.is_action_pressed("Baton"):
		Fire()

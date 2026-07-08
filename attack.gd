extends Node2D

var dir
var pos
var rota

var canHit = true
var baton_scene = preload("res://baton.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Input.is_action_pressed("Baton"):
		print("Baton")
	pass # Replace with function body.


func _physics_process(delta: float) -> void:
	print("running")
	look_at(get_global_mouse_position())
	if Input.is_action_pressed("Baton"):
		Fire()
		print("fire")

func Fire():
	if canHit == true:
		var baton = baton_scene.instantiate()
		print("instantiated")
		baton.dir = rotation
		baton.global_position = global_position
		baton.global_rotation = global_rotation
		get_parent().add_child(baton)
		

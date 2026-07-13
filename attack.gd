extends Node2D

@onready var baton = $Baton
@onready var hitbox = $Baton/CollisionShape2D
var canHit = true



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	baton.visible = false 
	baton.monitoring = false
	hitbox.disabled = true
	if Input.is_action_pressed("Baton"):
		print("Baton")
	pass # Replace with function body.


func _physics_process(delta: float) -> void:

	look_at(get_global_mouse_position())
	if Input.is_action_pressed("Baton"):
		Fire()
		print("fire")

func Fire():
	if canHit:

		canHit = false
		hitbox.disabled = false
		baton.visible = true
		baton.monitoring = true
		await get_tree().create_timer(0.5).timeout
		baton.visible = false
		baton.monitoring = false
		hitbox.disabled = true
		canHit = true
		

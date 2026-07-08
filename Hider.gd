extends CharacterBody2D

const SPEED = 400.0

@onready var camera = $Camera2D

var last_position = Vector2.ZERO

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hider_left", "hider_right", "hider_up", "hider_down")
		velocity = direction * SPEED
		move_and_slide()
	var move_delta = position - last_position
	last_position = position

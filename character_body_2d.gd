extends CharacterBody2D

const SPEED = 500.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

var last_position = Vector2.ZERO

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hunter_left", "hunter_right", "hunter_up", "hunter_down")
		velocity = direction * SPEED
		move_and_slide()
	var move_delta = position - last_position
	last_position = position
	if move_delta.length() < 0.1:
		animated_sprite.play("Security Idle Down")
	elif move_delta.y > 0:
		animated_sprite.play("Security Walk Down")
	elif move_delta.y < 0:
		animated_sprite.play("Security Walk Up")
	elif move_delta.x > 0:
		animated_sprite.play("Security Walk Right")
	elif move_delta.x < 0:
		animated_sprite.play("Security Walk Left")

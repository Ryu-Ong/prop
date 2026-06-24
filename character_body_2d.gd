extends CharacterBody2D

const SPEED = 500.0

@onready var animated_sprite = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	var direction = Input.get_vector("hunter_left", "hunter_right", "hunter_up", "hunter_down")
	velocity = direction * SPEED
	move_and_slide()
	
	if direction == Vector2.ZERO:
		animated_sprite.play("Security Idle Down")
	elif direction.y > 0:
		animated_sprite.play("Security Walk Down")

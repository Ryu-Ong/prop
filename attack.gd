extends Node2D

@onready var baton = $Baton
@onready var hitbox = $Baton/CollisionShape2D

var canHit = true

func _ready() -> void:
	baton.visible = false
	baton.monitoring = false
	hitbox.disabled = true

func _physics_process(delta: float) -> void:
	# only the hunter who owns this controls the attack
	if not is_multiplayer_authority():
		return
	look_at(get_global_mouse_position())
	broadcast_rotation.rpc(rotation)
	if Input.is_action_pressed("Baton"):
		fire.rpc()

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_rotation(rot: float):
	rotation = rot

@rpc("authority", "call_local", "reliable")
func fire():
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

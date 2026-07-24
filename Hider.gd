extends CharacterBody2D

const SPEED = 400.0

@onready var camera = $Camera2D
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D

var prop_textures = {
	
	"Tree": preload("res://props/TestTree.tscn")
	
}

func _ready():
	camera.enabled = is_multiplayer_authority()
	collision_layer = 2
	collision_mask = 1

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		var direction = Input.get_vector("hider_left", "hider_right", "hider_up", "hider_down")
		velocity = direction * SPEED
		move_and_slide()
		broadcast_position.rpc(position)

@rpc("authority", "call_remote", "unreliable_ordered")
func broadcast_position(pos: Vector2):
	position = pos

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not is_multiplayer_authority():
		return
	if area.name == "Baton":
		die.rpc()



func transform(prop: Node):
	var prop_sprite = prop.get_node("Area2D/Sprite2D")
	var prop_collision = prop.get_node("CollisionShape2D")

	sprite.texture = prop_sprite.texture
	sprite.scale = prop_sprite.scale
	collision.shape = prop_collision.shape.duplicate()
	

@rpc("any_peer", "call_local", "reliable")
func die():
	Global.report_death(int(str(name)))

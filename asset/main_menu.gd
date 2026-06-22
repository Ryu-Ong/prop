extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://node_2d.tscn")

func _on_settings_pressed() -> void:
	print("Settings pressed")


func _on_Credits_pressed() -> void:
	print("Credits pressed")


func _on_Exit_pressed() -> void:
	get_tree().quit()

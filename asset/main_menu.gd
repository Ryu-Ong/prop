extends Control

@onready var menu_buttons = $VBoxContainer
@onready var title_label = $Label
@onready var credits = $Credits

func _ready() -> void:
	credits.visible = false

# Swaps between the main menu and the credits panel. The background Panel stays
# visible either way so the artwork never flashes.
func _show_credits(show_it: bool) -> void:
	credits.visible = show_it
	menu_buttons.visible = not show_it
	title_label.visible = not show_it

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://lobby.tscn")

func _on_settings_pressed() -> void:
	print("Settings pressed")

func _on_Credits_pressed() -> void:
	_show_credits(true)

func _on_credits_back_pressed() -> void:
	_show_credits(false)

func _on_Exit_pressed() -> void:
	get_tree().quit()

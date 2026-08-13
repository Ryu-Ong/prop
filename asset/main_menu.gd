extends Control

@onready var menu_buttons = $VBoxContainer
@onready var title_label = $Label
@onready var credits = $Credits
@onready var settings = $Settings
@onready var volume_slider = $Settings/VolumeSlider
@onready var volume_label = $Settings/VolumeLabel

func _ready() -> void:
	credits.visible = false
	settings.visible = false
	# reflect whatever volume is already set, so reopening Settings shows the
	# real value instead of snapping back to 100%
	volume_slider.value = Global.master_volume * 100.0
	_refresh_volume_label()

# Swaps between the main menu and a sub panel. The background Panel stays visible
# either way so the artwork never flashes.
func _show_panel(panel: Control, show_it: bool) -> void:
	panel.visible = show_it
	menu_buttons.visible = not show_it
	title_label.visible = not show_it

func _refresh_volume_label() -> void:
	volume_label.text = "Volume  %d%%" % int(round(volume_slider.value))

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://lobby.tscn")

func _on_settings_pressed() -> void:
	_show_panel(settings, true)

func _on_settings_back_pressed() -> void:
	_show_panel(settings, false)

func _on_volume_changed(value: float) -> void:
	Global.set_master_volume(value / 100.0)
	_refresh_volume_label()

func _on_Credits_pressed() -> void:
	_show_panel(credits, true)

func _on_credits_back_pressed() -> void:
	_show_panel(credits, false)

func _on_Exit_pressed() -> void:
	get_tree().quit()

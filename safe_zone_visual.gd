extends Node2D

# World-space visual for a hider's assigned safe zone.
# Created at runtime by Hider.gd - no .tscn needed.

var radius: float = 160.0
var color: Color = Color(1, 0.82, 0.2)

var _t: float = 0.0

func _ready() -> void:
	z_index = -5

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)

	# translucent fill
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.10 + 0.06 * pulse))
	# solid outer ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color.r, color.g, color.b, 0.95), 4.0, true)
	# pulsing inner ring
	draw_arc(Vector2.ZERO, radius * (0.80 + 0.18 * pulse), 0.0, TAU, 72,
		Color(color.r, color.g, color.b, 0.35), 2.0, true)
	# centre crosshair
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color(color.r, color.g, color.b, 0.9), 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), Color(color.r, color.g, color.b, 0.9), 2.0)

@tool
extends TileMapLayer

func _ready():
	generate_checkerboard()

func generate_checkerboard():
	for x in range(300):
		for y in range(300):
			if (x + y) % 2 == 0:
				set_cell(Vector2i(-150 + x, -150 + y), 0, Vector2i(0, 0))
			else:
				set_cell(Vector2i(-150 + x, -150 + y), 1, Vector2i(0, 0))
				

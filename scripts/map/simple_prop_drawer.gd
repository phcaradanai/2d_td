extends Node2D

# Simple Prop Drawer
# Draws procedural decorations based on theme and type.

func _draw() -> void:
	var theme_id = get_meta("theme_id", "area_grasslands")
	var prop_type = get_meta("prop_type", 0)
	
	match theme_id:
		"area_grasslands":
			_draw_grasslands_prop(prop_type)
		"area_forest":
			_draw_forest_prop(prop_type)
		"area_forest_river":
			_draw_river_prop(prop_type)
		"area_mountain":
			_draw_mountain_prop(prop_type)

func _draw_grasslands_prop(type: int) -> void:
	match type:
		0: # Rock
			_draw_blob(Vector2.ZERO, 8, Color(0.5, 0.45, 0.4))
		1: # Bush
			_draw_blob(Vector2.ZERO, 12, Color(0.2, 0.5, 0.2))
		2: # Flower
			draw_circle(Vector2.ZERO, 3, Color(1, 0.9, 0.2)) # Center
			for i in range(5):
				var ang = i * TAU / 5
				draw_circle(Vector2(cos(ang), sin(ang)) * 4, 3, Color(1, 0.5, 0.7)) # Petals
		3: # Grass clump
			for i in range(3):
				draw_line(Vector2.ZERO, Vector2(-4 + i*4, -8), Color(0.3, 0.6, 0.2), 2.0)

func _draw_forest_prop(type: int) -> void:
	match type:
		0: # Mushroom
			draw_line(Vector2.ZERO, Vector2(0, -6), Color(0.9, 0.8, 0.7), 4.0)
			draw_circle(Vector2(0, -6), 6, Color(0.8, 0.2, 0.2)) # Cap
			draw_circle(Vector2(2, -8), 1, Color.WHITE) # Spot
		1: # Dense Bush
			_draw_blob(Vector2.ZERO, 15, Color(0.1, 0.3, 0.1))
		2: # Root
			draw_polyline([Vector2(-10, 0), Vector2(0, 5), Vector2(10, -5)], Color(0.25, 0.15, 0.05), 3.0)
		3: # Mossy Rock
			_draw_blob(Vector2.ZERO, 10, Color(0.4, 0.4, 0.35))
			draw_circle(Vector2(2, -2), 4, Color(0.2, 0.4, 0.1, 0.5))

func _draw_river_prop(type: int) -> void:
	match type:
		0: # Wet Rock
			_draw_blob(Vector2.ZERO, 10, Color(0.3, 0.35, 0.4))
		1: # Reed
			draw_line(Vector2(0, 0), Vector2(0, -15), Color(0.2, 0.4, 0.1), 2.0)
			draw_rect(Rect2(-2, -18, 4, 6), Color(0.4, 0.2, 0.1)) # Brown top
		2: # Lily Pad
			draw_circle(Vector2.ZERO, 8, Color(0.1, 0.6, 0.3))
			draw_line(Vector2.ZERO, Vector2(8, 0), Color(0.05, 0.1, 0.15), 2.0) # Cutout
		3: # Water Ripples (Static)
			draw_arc(Vector2.ZERO, 10, 0, TAU, 16, Color(1, 1, 1, 0.2), 1.0)

func _draw_mountain_prop(type: int) -> void:
	match type:
		0: # Sharp Stone
			var pts = [Vector2(-8, 0), Vector2(0, -12), Vector2(8, 0)]
			draw_polygon(pts, [Color(0.4, 0.4, 0.45)])
		1: # Pine Shrub
			var pts = [Vector2(-10, 0), Vector2(0, -18), Vector2(10, 0)]
			draw_polygon(pts, [Color(0.05, 0.2, 0.1)])
		2: # Broken Ruin Piece
			draw_rect(Rect2(-6, -6, 12, 12), Color(0.3, 0.3, 0.32))
			draw_rect(Rect2(-6, -6, 12, 12), Color(0.2, 0.2, 0.25), false, 1.5)
		3: # Torch (Static)
			draw_line(Vector2(0, 0), Vector2(0, -10), Color(0.3, 0.2, 0.1), 3.0)
			draw_circle(Vector2(0, -12), 4, Color(1.0, 0.5, 0.2))

func _draw_blob(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius, color)
	draw_circle(pos + Vector2(radius*0.3, -radius*0.2), radius * 0.7, color.lightened(0.1))
	draw_circle(pos + Vector2(-radius*0.4, radius*0.1), radius * 0.6, color.darkened(0.1))

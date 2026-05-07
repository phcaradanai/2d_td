extends Node2D

# Simple Prop Drawer
# Draws procedural sci-fi decorations based on theme and type.

func _draw() -> void:
	var theme_id = get_meta("theme_id", "area_grasslands")
	var prop_type = get_meta("prop_type", 0)
	
	# Unified Sci-Fi Prop System
	# We use the theme_id to pick accent colors, but the shapes are consistent
	var accent_color = Color(0.2, 0.8, 1.0) # Default Cyan
	
	match theme_id:
		"area_grasslands": accent_color = Color(0.2, 0.6, 1.0)
		"area_forest": accent_color = Color(0.0, 1.0, 0.8)
		"area_forest_river": accent_color = Color(0.7, 0.4, 1.0)
		"area_mountain": accent_color = Color(1.0, 0.6, 0.1)

	match prop_type:
		0: # Tech Panel / Plate
			_draw_tech_panel()
		1: # Energy Beacon / Node
			_draw_energy_beacon(accent_color)
		2: # Circuit Trace Hub
			_draw_circuit_hub(accent_color)
		3: # Mechanical Debris / Vent
			_draw_mechanical_vent()

func _draw_tech_panel() -> void:
	var color = Color(0.15, 0.18, 0.22)
	var border = Color(0.3, 0.35, 0.4, 0.5)
	var size = Vector2(16, 12)
	var rect = Rect2(-size/2, size)
	
	draw_rect(rect, color)
	draw_rect(rect, border, false, 1.0)
	
	# Seam line
	draw_line(Vector2(-size.x/2, 0), Vector2(size.x/2, 0), border * 0.7)
	# Corner rivet dots
	for x in [-6, 6]:
		for y in [-4, 4]:
			draw_circle(Vector2(x, y), 1.0, border)

func _draw_energy_beacon(color: Color) -> void:
	# Base
	draw_rect(Rect2(-4, -2, 8, 4), Color(0.2, 0.2, 0.2))
	# Glowing Node
	var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
	var g_color = color
	g_color.a = 0.4 + pulse * 0.4
	
	draw_circle(Vector2(0, -6), 4, Color(0, 0, 0, 0.8))
	draw_circle(Vector2(0, -6), 3, g_color)
	draw_circle(Vector2(0, -6), 1.5, Color.WHITE)
	
	# Small light beam (Static)
	draw_line(Vector2(0, -6), Vector2(0, -12), Color(color.r, color.g, color.b, 0.3), 1.0)

func _draw_circuit_hub(color: Color) -> void:
	var c = Color(color.r, color.g, color.b, 0.3)
	# Center dot
	draw_circle(Vector2.ZERO, 3, c)
	# Branching lines
	draw_line(Vector2.ZERO, Vector2(10, 5), c, 1.0)
	draw_line(Vector2(10, 5), Vector2(15, 5), c, 1.0)
	draw_line(Vector2.ZERO, Vector2(-8, -10), c, 1.0)
	draw_circle(Vector2(15, 5), 1.5, c)

func _draw_mechanical_vent() -> void:
	var color = Color(0.1, 0.1, 0.12)
	var border = Color(0.2, 0.2, 0.25)
	draw_rect(Rect2(-8, -8, 16, 16), color)
	draw_rect(Rect2(-8, -8, 16, 16), border, false, 1.0)
	
	# Slats
	for i in range(3):
		var y = -4 + i * 4
		draw_line(Vector2(-5, y), Vector2(5, y), border, 1.5)

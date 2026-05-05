extends Node2D

var level_manager: Node = null

# Theme Colors
const COLOR_BG = Color(0.02, 0.05, 0.08, 1.0)
const COLOR_BUILDABLE = Color(0.05, 0.1, 0.12, 1.0)
const COLOR_BUILDABLE_BORDER = Color(0.1, 0.2, 0.25, 0.4)
const COLOR_PATH = Color(0.15, 0.08, 0.05, 1.0)
const COLOR_PATH_GLOW = Color(1.0, 0.4, 0.2, 0.15)
const COLOR_PATH_LINE = Color(1.0, 0.3, 0.1, 0.4)
const COLOR_BLOCKED = Color(0.08, 0.08, 0.1, 1.0)
const COLOR_BLOCKED_PATTERN = Color(0.2, 0.2, 0.3, 0.1)
const COLOR_SPAWN = Color(0.2, 1.0, 0.5, 0.3)
const COLOR_BASE = Color(1.0, 0.2, 0.3, 0.3)

func setup(p_level_manager: Node) -> void:
	level_manager = p_level_manager
	queue_redraw()

func _draw() -> void:
	if level_manager == null: return
	
	var gs = level_manager.grid_size
	var cols = level_manager.grid_cols
	var rows = level_manager.grid_rows
	var origin = level_manager.grid_origin
	
	# 1. Draw solid background
	draw_rect(Rect2(origin, Vector2(cols * gs, rows * gs)), COLOR_BG)
	
	# 2. Draw tiles
	for x in range(cols):
		for y in range(rows):
			var cell = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(x * gs, y * gs), Vector2(gs, gs))
			var center = rect.get_center()
			
			if level_manager.is_path_cell(cell):
				_draw_path_tile(rect)
			elif cell in level_manager.decorative_blocked_cells or cell in level_manager.blocked_cells:
				_draw_blocked_tile(rect)
			else:
				_draw_buildable_tile(rect)
				
	# 3. Draw Path Glow (Overlay)
	_draw_path_connection_glow()
				
	# 4. Markers
	_draw_markers(gs)

func _draw_buildable_tile(rect: Rect2) -> void:
	draw_rect(rect, COLOR_BUILDABLE)
	draw_rect(rect, COLOR_BUILDABLE_BORDER, false, 1.0)
	
	# Small corner tick
	var s = 4.0
	var pad = 2.0
	draw_line(rect.position + Vector2(pad, pad), rect.position + Vector2(pad + s, pad), COLOR_BUILDABLE_BORDER)
	draw_line(rect.position + Vector2(pad, pad), rect.position + Vector2(pad, pad + s), COLOR_BUILDABLE_BORDER)

func _draw_path_tile(rect: Rect2) -> void:
	draw_rect(rect, COLOR_PATH)
	# Path tiles don't need individual borders to feel like a continuous road

func _draw_blocked_tile(rect: Rect2) -> void:
	draw_rect(rect, COLOR_BLOCKED)
	# Draw cross-hatch pattern
	var gs = rect.size.x
	var steps = 4
	for i in range(steps + 1):
		var offset = (gs / steps) * i
		draw_line(rect.position + Vector2(offset, 0), rect.position + Vector2(0, offset), COLOR_BLOCKED_PATTERN)
		draw_line(rect.position + Vector2(gs, offset), rect.position + Vector2(offset, gs), COLOR_BLOCKED_PATTERN)

func _draw_path_connection_glow() -> void:
	var points = level_manager.get_path_points()
	if points.size() < 2: return
	
	# Draw glowing spine for the path
	draw_polyline(points, COLOR_PATH_GLOW, 12.0, true)
	draw_polyline(points, COLOR_PATH_LINE, 2.0, true)

func _draw_markers(gs: int) -> void:
	var spawn_pos = level_manager.cell_to_world_center(level_manager.spawn_cell)
	_draw_portal(spawn_pos, gs * 0.35, COLOR_SPAWN)
	
	var base_pos = level_manager.cell_to_world_center(level_manager.base_cell)
	_draw_portal(base_pos, gs * 0.4, COLOR_BASE)

func _draw_portal(pos: Vector2, radius: float, color: Color) -> void:
	# Outer glow
	draw_circle(pos, radius * 1.2, Color(color.r, color.g, color.b, 0.1))
	# Main ring
	draw_arc(pos, radius, 0, TAU, 32, color, 3.0)
	# Inner pulse (subtle)
	draw_circle(pos, radius * 0.4, Color(color.r, color.g, color.b, 0.2))
	# Corner brackets
	var s = radius * 0.5
	for i in range(4):
		var ang = i * PI/2 + PI/4
		var corner = pos + Vector2(cos(ang), sin(ang)) * radius * 1.4
		draw_arc(corner, radius * 0.3, ang + PI, ang + PI + PI/2, 8, color, 1.5)

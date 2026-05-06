extends Node2D

@export var valid_color: Color = Color(0.2, 1.0, 0.4, 0.6)
@export var invalid_color: Color = Color(1.0, 0.2, 0.2, 0.6)
@export var valid_range_fill: Color = Color(0.2, 1.0, 0.4, 0.15)
@export var valid_range_outline: Color = Color(0.2, 1.0, 0.4, 0.8)
@export var invalid_range_fill: Color = Color(1.0, 0.2, 0.2, 0.15)
@export var invalid_range_outline: Color = Color(1.0, 0.2, 0.2, 0.8)

@export var footprint_fill: Color = Color(1.0, 1.0, 1.0, 0.2)
@export var footprint_outline: Color = Color(1.0, 1.0, 1.0, 0.6)

@export var grid_color: Color = Color(1.0, 1.0, 1.0, 0.08)
@export var blocked_color: Color = Color(1.0, 0.1, 0.1, 0.15)

var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12

var hover_cell: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var hover_range: float = 0.0
var hover_footprint: float = 20.0
var buildable_cells: Array = []
var blocked_cells: Array = []
var is_active: bool = false
var invalid_reason: String = ""

@export var buildable_tile_color: Color = Color(0.2, 0.8, 1.0, 0.1)
@export var buildable_outline_color: Color = Color(0.2, 0.8, 1.0, 0.3)

@onready var reason_label: Label = get_node_or_null("ReasonLabel")

func setup(size: int, cols: int, rows: int) -> void:
	grid_size = size
	grid_cols = cols
	grid_rows = rows
	queue_redraw()

func set_blocked_cells(cells: Array) -> void:
	blocked_cells = cells
	queue_redraw()

func set_buildable_cells(cells: Array) -> void:
	buildable_cells = cells
	queue_redraw()

func update_preview(cell: Vector2i, valid: bool, active: bool, range_val: float = 0.0, reason: String = "", footprint: float = 20.0) -> void:
	hover_cell = cell
	is_hover_valid = valid
	is_active = active
	hover_range = range_val
	invalid_reason = reason
	hover_footprint = footprint
	
	if reason_label:
		if is_active and not is_hover_valid and reason != "":
			reason_label.text = reason
			reason_label.show()
			reason_label.position = Vector2(hover_cell.x * grid_size, hover_cell.y * grid_size - 25)
		else:
			reason_label.hide()
			
	queue_redraw()

func _draw() -> void:
	if not is_active: return
	
	# 1. Buildable Foundations (Blueprint style)
	if not buildable_cells.is_empty():
		for cell in buildable_cells:
			var rect = Rect2(cell.x * grid_size + 2, cell.y * grid_size + 2, grid_size - 4, grid_size - 4)
			draw_rect(rect, buildable_tile_color)
			# Small corner accents for foundations
			_draw_brackets(Rect2(cell.x * grid_size, cell.y * grid_size, grid_size, grid_size), buildable_outline_color)
	
	# 2. Blocked Cells Tint (if buildable cells exist, otherwise path/blocked)
	if not buildable_cells.is_empty():
		# All non-buildable are effectively blocked
		for x in range(grid_cols):
			for y in range(grid_rows):
				var cell = Vector2i(x, y)
				if not cell in buildable_cells:
					var rect = Rect2(cell.x * grid_size, cell.y * grid_size, grid_size, grid_size)
					draw_rect(rect, blocked_color)
	else:
		for cell in blocked_cells:
			var rect = Rect2(cell.x * grid_size, cell.y * grid_size, grid_size, grid_size)
			draw_rect(rect, blocked_color)

	# 3. Subtle tactical grid
	var grid_alpha_color = Color(grid_color.r, grid_color.g, grid_color.b, 0.03)
	for x in range(grid_cols + 1):
		draw_line(Vector2(x * grid_size, 0), Vector2(x * grid_size, grid_rows * grid_size), grid_alpha_color)
	for y in range(grid_rows + 1):
		draw_line(Vector2(0, y * grid_size), Vector2(grid_cols * grid_size, y * grid_size), grid_alpha_color)
	
	# 2. Hover preview
	if hover_cell.x >= 0 and hover_cell.x < grid_cols and hover_cell.y >= 0 and hover_cell.y < grid_rows:
		var center = Vector2(hover_cell.x * grid_size + grid_size / 2.0, hover_cell.y * grid_size + grid_size / 2.0)
		var rect = Rect2(hover_cell.x * grid_size, hover_cell.y * grid_size, grid_size, grid_size)
		var color = valid_color if is_hover_valid else invalid_color
		
		# Range Guide (behind)
		if hover_range > 0:
			var fill_color = valid_range_fill if is_hover_valid else invalid_range_fill
			var outline_color = valid_range_outline if is_hover_valid else invalid_range_outline
			var visual_range = hover_range / global_scale.x
			draw_circle(center, visual_range, fill_color)
			draw_arc(center, visual_range, 0, TAU, 64, outline_color, 1.5)
		
		# Tower Footprint / Base (more solid)
		if hover_footprint > 0:
			var f_fill = Color(footprint_fill.r, footprint_fill.g, footprint_fill.b, 0.3)
			var f_outline = footprint_outline
			if not is_hover_valid:
				f_fill = Color(1.0, 0.2, 0.2, 0.3)
				f_outline = Color(1.0, 0.2, 0.2, 0.8)
			
			var visual_f = hover_footprint / global_scale.x
			draw_circle(center, visual_f, f_fill)
			draw_arc(center, visual_f, 0, TAU, 32, f_outline, 2.0)
		
		# Cell Highlight + Brackets
		draw_rect(rect, Color(color.r, color.g, color.b, 0.15))
		_draw_brackets(rect, color)
		
		# Ghost tower (simplified shape)
		if is_hover_valid:
			draw_arc(center, grid_size * 0.25, 0, TAU, 32, color, 3.0)
			draw_circle(center, grid_size * 0.1, color)
		else:
			# X or warning shape
			var s = grid_size * 0.2
			draw_line(center + Vector2(-s, -s), center + Vector2(s, s), color, 3.0)
			draw_line(center + Vector2(s, -s), center + Vector2(-s, s), color, 3.0)

func _draw_brackets(rect: Rect2, color: Color) -> void:
	var s = 10.0
	var p = 2.0
	# TL
	draw_line(rect.position + Vector2(p, p), rect.position + Vector2(p + s, p), color, 2.0)
	draw_line(rect.position + Vector2(p, p), rect.position + Vector2(p, p + s), color, 2.0)
	# TR
	draw_line(rect.position + Vector2(rect.size.x - p, p), rect.position + Vector2(rect.size.x - p - s, p), color, 2.0)
	draw_line(rect.position + Vector2(rect.size.x - p, p), rect.position + Vector2(rect.size.x - p, p + s), color, 2.0)
	# BL
	draw_line(rect.position + Vector2(p, rect.size.y - p), rect.position + Vector2(p + s, rect.size.y - p), color, 2.0)
	draw_line(rect.position + Vector2(p, rect.size.y - p), rect.position + Vector2(p, rect.size.y - p - s), color, 2.0)
	# BR
	draw_line(rect.position + Vector2(rect.size.x - p, rect.size.y - p), rect.position + Vector2(rect.size.x - p - s, rect.size.y - p), color, 2.0)
	draw_line(rect.position + Vector2(rect.size.x - p, rect.size.y - p), rect.position + Vector2(rect.size.x - p, rect.size.y - p - s), color, 2.0)

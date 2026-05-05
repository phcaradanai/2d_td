extends Node2D

@export var valid_color: Color = Color(0.1, 1.0, 0.2, 0.4)
@export var invalid_color: Color = Color(1.0, 0.1, 0.1, 0.4)
@export var valid_range_fill: Color = Color(0.1, 1.0, 0.2, 0.12)
@export var valid_range_outline: Color = Color(0.1, 1.0, 0.2, 0.6)
@export var invalid_range_fill: Color = Color(1.0, 0.1, 0.1, 0.12)
@export var invalid_range_outline: Color = Color(1.0, 0.1, 0.1, 0.6)

@export var grid_color: Color = Color(1.0, 1.0, 1.0, 0.05)
@export var blocked_color: Color = Color(1.0, 0.0, 0.0, 0.2)

var grid_size: int = 64
var grid_cols: int = 20
var grid_rows: int = 12

var hover_cell: Vector2i = Vector2i(-1, -1)
var is_hover_valid: bool = false
var hover_range: float = 0.0
var blocked_cells: Array = []
var is_active: bool = false
var invalid_reason: String = ""

@onready var reason_label: Label = get_node_or_null("ReasonLabel")

func setup(size: int, cols: int, rows: int) -> void:
	grid_size = size
	grid_cols = cols
	grid_rows = rows
	queue_redraw()

func set_blocked_cells(cells: Array) -> void:
	blocked_cells = cells
	queue_redraw()

func update_preview(cell: Vector2i, valid: bool, active: bool, range_val: float = 0.0, reason: String = "") -> void:
	hover_cell = cell
	is_hover_valid = valid
	is_active = active
	hover_range = range_val
	invalid_reason = reason
	
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
	
	# 1. Subtle tactical grid
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
			# STANDARD: Draw world-unit range circle by compensating for GLOBAL scale
			var visual_range = hover_range / global_scale.x
			draw_circle(center, visual_range, fill_color)
			draw_arc(center, visual_range, 0, TAU, 64, outline_color, 1.5)
		
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

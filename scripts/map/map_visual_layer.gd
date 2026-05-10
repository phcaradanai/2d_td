extends Node2D

# Map Visual Layer
# Responsible for rendering the environment based on AreaTheme.

var level_manager: Node = null
var current_theme: Resource = null
var prop_container: Node2D = null
var active_preview_paths: Array[String] = []
var preview_timer: float = 0.0
var preview_alpha: float = 0.0
var preview_target_alpha: float = 0.0
var show_path_overlays: bool = true

const PREVIEW_FADE_SPEED := 6.0
const PATH_EDGE_CYAN := Color(0.2, 0.9, 1.0, 1.0)
const PATH_EDGE_BLUE := Color(0.1, 0.5, 1.0, 1.0)
const PATH_INNER_AMBER := Color(1.0, 0.7, 0.2, 1.0)
const PATH_METAL_DARK := Color(0.01, 0.02, 0.03, 1.0)
const PATH_METAL_MID := Color(0.05, 0.08, 0.12, 1.0)
const PATH_METAL_HIGHLIGHT := Color(0.16, 0.22, 0.28, 1.0)
const ROUTE_ARROW_SPEED := 0.0
const ROUTE_CHEVRON_LENGTH := 22.0
const ROUTE_CHEVRON_HALF_WIDTH := 9.0
const ROUTE_CHEVRON_PAIR_OFFSET := 16.0
const ROUTE_CHEVRON_SPACING := 248.0
const ROUTE_CHEVRON_START_OFFSET := 112.0
const ROUTE_ARROW_ENTRY_BUFFER := 86.0
const ROUTE_ARROW_EXIT_BUFFER := 92.0
const ROUTE_ARROW_DANGER := Color(1.0, 0.22, 0.10, 1.0)
const ROUTE_ARROW_HOT := Color(1.0, 0.62, 0.18, 1.0)
const ROUTE_GROOVE_DARK := Color(0.0, 0.0, 0.0, 0.46)
const ROUTE_GROOVE_FILL := Color(0.12, 0.05, 0.03, 0.84)

func setup(p_level_manager: Node) -> void:
	level_manager = p_level_manager
	current_theme = level_manager.current_theme
	
	if prop_container == null:
		prop_container = Node2D.new()
		prop_container.name = "PropContainer"
		add_child(prop_container)
	
	_clear_props()
	_generate_decorations()
	queue_redraw()

func set_preview_paths(paths: Array) -> void:
	var normalized_paths: Array[String] = []
	if level_manager:
		for path_id in paths:
			var normalized = str(path_id)
			if level_manager.multi_paths.has(normalized) and not normalized_paths.has(normalized):
				normalized_paths.append(normalized)
	if normalized_paths.is_empty():
		preview_target_alpha = 0.0
	else:
		active_preview_paths = normalized_paths
		preview_target_alpha = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	preview_timer += delta
	preview_alpha = move_toward(preview_alpha, preview_target_alpha, PREVIEW_FADE_SPEED * delta)
	if preview_alpha <= 0.001 and preview_target_alpha <= 0.0:
		active_preview_paths.clear()
	if _should_use_tile_roads() or preview_alpha > 0.001 or not active_preview_paths.is_empty():
		queue_redraw()

func _clear_props() -> void:
	for child in prop_container.get_children():
		child.queue_free()

func _generate_decorations() -> void:
	if current_theme == null or level_manager == null: return
	
	# Use deterministic random seed based on level name
	var seed_val = level_manager.level_id.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var gs = level_manager.grid_size
	var cols = level_manager.grid_cols
	var rows = level_manager.grid_rows
	var visual_road_cells: Dictionary = {}
	if _should_use_tile_roads():
		visual_road_cells = _collect_visual_road_cells()
	
	for x in range(cols):
		for y in range(rows):
			var cell = Vector2i(x, y)
			
			# In full_non_path mode decorations are visual-only and do not block tower placement.
			# For wide tile roads, avoid spawning props on the visual road shoulders too.
			if level_manager.is_path_cell(cell): continue
			if visual_road_cells.has(_road_cell_key(cell)): continue
			if level_manager.buildable_mode != "full_non_path" and not level_manager.buildable_cells.is_empty() and cell in level_manager.buildable_cells: continue
			
			# Roll for prop
			if rng.randf() < current_theme.prop_density:
				_spawn_simple_prop(cell, rng)

func _spawn_simple_prop(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var pos = level_manager.cell_to_world_center(cell)
	var prop = Node2D.new()
	prop.position = pos + Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
	prop.rotation = rng.randf_range(0, TAU)
	prop.scale = Vector2.ONE * rng.randf_range(0.8, 1.2)
	
	# Instead of scenes (which we don't have), we draw a simple procedural prop
	var prop_drawer = Node2D.new()
	prop_drawer.set_script(load("res://scripts/map/simple_prop_drawer.gd"))
	prop_drawer.set_meta("theme_id", current_theme.theme_id)
	prop_drawer.set_meta("prop_type", rng.randi_range(0, 3)) # 0: rock, 1: bush, 2: flower, 3: grass clump
	prop.add_child(prop_drawer)
	
	prop_container.add_child(prop)

func _draw() -> void:
	if level_manager == null or current_theme == null: return
	
	var gs = level_manager.grid_size
	var cols = level_manager.grid_cols
	var rows = level_manager.grid_rows
	var origin = level_manager.grid_origin
	
	# 1. Base Ground (Expansive)
	# Draw a huge rectangle to ensure we cover the entire possible view area
	# even when the camera is zoomed or centered in a large viewport.
	var huge_rect = Rect2(origin - Vector2(5000, 5000), Vector2(10000, 10000))
	draw_rect(huge_rect, current_theme.color_bg)
	
	# Draw a slightly darker or textured border for the actual grid bounds if desired
	# But for now, just let the huge rect handle the fill.
	
	# 2. Grid (Subtle)
	if current_theme.color_grid.a > 0:
		for x in range(cols + 1):
			draw_line(origin + Vector2(x * gs, 0), origin + Vector2(x * gs, rows * gs), current_theme.color_grid)
		for y in range(rows + 1):
			draw_line(origin + Vector2(0, y * gs), origin + Vector2(cols * gs, y * gs), current_theme.color_grid)
	
	# 3. Path Base (Thicker for organic feel)
	_draw_all_paths_base()
	
	# 4. Special Tiles (Foundations / Blockers)
	for x in range(cols):
		for y in range(rows):
			var cell = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(x * gs, y * gs), Vector2(gs, gs))
			
			if level_manager.buildable_mode != "full_non_path" and not level_manager.buildable_cells.is_empty() and cell in level_manager.buildable_cells:
				_draw_foundation_tile(rect)
			elif cell in level_manager.blocked_cells or cell in level_manager.decorative_blocked_cells:
				_draw_blocked_tile(rect)

	# 5. Path Glow & Lines
	_draw_path_overlays()
	
	# 6. Markers (Spawn / Base)
	_draw_markers(gs)

func _draw_foundation_tile(rect: Rect2) -> void:
	var color = current_theme.color_buildable
	var border = Color(color.r, color.g, color.b, 0.4)
	
	# Pulse logic for buildable tiles
	var pulse = 0.5 + sin(preview_timer * 3.0) * 0.15
	var build_glow = Color(0.2, 0.8, 1.0, 0.05 * pulse)
	
	# Clean Sci-Fi Plate
	draw_rect(rect, color)
	draw_rect(rect, build_glow) # Subtle fill pulse
	draw_rect(rect.grow(-2), border, false, 1.0)
	
	# Technical Grid overlay
	var g_color = Color(0.2, 0.9, 1.0, 0.04)
	for i in range(1, 4):
		var dx = rect.size.x / 4.0 * i
		var dy = rect.size.y / 4.0 * i
		draw_line(rect.position + Vector2(dx, 4), rect.position + Vector2(dx, rect.size.y - 4), g_color)
		draw_line(rect.position + Vector2(4, dy), rect.position + Vector2(rect.size.x - 4, dy), g_color)

	# Corner Accents (Small Cyan L-shapes)
	var s = 8.0
	var p = rect.position + Vector2(2, 2)
	var e = rect.end - Vector2(2, 2)
	var acc = Color(0.2, 0.9, 1.0, 0.6 * pulse) # Pulsing accents
	
	draw_polyline([p + Vector2(s, 0), p, p + Vector2(0, s)], acc, 2.0)
	draw_polyline([e - Vector2(s, 0), e, e - Vector2(0, s)], acc, 2.0)
	
	# Center Detail
	draw_circle(rect.get_center(), 2.0, Color(0.2, 0.9, 1.0, 0.2))

func _draw_blocked_tile(rect: Rect2) -> void:
	var color = current_theme.color_blocked
	draw_rect(rect, color)
	
	# Hazard / Industrial Pattern
	var steps = 4
	var p_color = Color(0.0, 0.0, 0.0, 0.4)
	var accent = Color(1, 1, 1, 0.03)
	
	for i in range(steps * 2):
		var offset = (rect.size.x / steps) * i
		draw_line(rect.position + Vector2(offset, 0), rect.position + Vector2(offset - rect.size.x, rect.size.y), p_color, 4.0)
	
	# Border to separate from ground
	draw_rect(rect, Color(0, 0, 0, 0.2), false, 1.0)
	draw_rect(rect.grow(-4), accent, false, 1.0)

func _draw_all_paths_base() -> void:
	if _should_use_tile_roads():
		_draw_tile_road_system()
		return
	_draw_polyline_paths_base()

func _draw_polyline_paths_base() -> void:
	var gs = level_manager.grid_size
	
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		# Dark metal trench and restrained neon edges.
		draw_polyline(points, Color(0.0, 0.0, 0.0, 0.26), gs * 0.86, true)
		draw_polyline(points, PATH_METAL_DARK, gs * 0.72, true)
		draw_polyline(points, PATH_METAL_MID, gs * 0.56, true)
		draw_polyline(points, Color(0.0, 0.0, 0.0, 0.30), gs * 0.38, true)
		
		var outer_glow := _with_alpha(PATH_EDGE_CYAN, 0.16)
		var edge_cyan := _with_alpha(PATH_EDGE_CYAN, 0.58)
		var edge_blue := _with_alpha(PATH_EDGE_BLUE, 0.30)
		var amber := _with_alpha(PATH_INNER_AMBER, 0.32)
		
		draw_polyline(points, outer_glow, gs * 0.78, true)
		draw_polyline(points, edge_blue, gs * 0.66, true)
		draw_polyline(points, edge_cyan, gs * 0.62, true)
		draw_polyline(points, PATH_METAL_DARK, gs * 0.50, true)
		draw_polyline(points, amber, 3.0, true)
		
		var circuit_color := _with_alpha(PATH_EDGE_CYAN, 0.14)
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			var dir = (p2 - p1).normalized()
			var perp = Vector2(-dir.y, dir.x)
			var d = p1.distance_to(p2)
			
			for step in range(18, int(d), 56):
				var base = p1 + dir * step
				draw_line(base - perp * gs * 0.18, base + perp * gs * 0.18, circuit_color, 1.0)
				draw_line(base - perp * gs * 0.28, base - perp * gs * 0.18, amber, 1.0)
				draw_line(base + perp * gs * 0.18, base + perp * gs * 0.28, edge_cyan, 1.0)

func _should_use_tile_roads() -> bool:
	if level_manager == null:
		return false
	return str(level_manager.level_data.get("road_visual_style", "")) == "sci_fi_tile"

func _collect_visual_road_cells() -> Dictionary:
	var out: Dictionary = {}
	if level_manager == null:
		return out
	var width: int = min(3, max(1, int(level_manager.level_data.get("road_visual_width_cells", 1))))
	for p_id in level_manager.multi_paths:
		var cells: Array = level_manager.multi_paths[p_id]
		for i in range(cells.size()):
			var center_cell = cells[i]
			if center_cell is Vector2i:
				_add_visual_road_cell_segment_footprint(out, center_cell, cells, i, width)
	var extra_cells = level_manager.level_data.get("road_visual_extra_cells", [])
	if extra_cells is Array:
		for item in extra_cells:
			if item is Array and item.size() >= 2:
				var c := Vector2i(int(item[0]), int(item[1]))
				_add_road_cell_if_inside(out, c)
	return out

func _add_visual_road_cell_footprint(out: Dictionary, center_cell: Vector2i, half_width: int) -> void:
	# Backward-compatible helper. Width is clamped by callers; avoid accidental 5+ cell roads.
	var width: int = min(3, half_width * 2 + 1)
	_add_visual_road_cell_segment_footprint(out, center_cell, [center_cell], 0, width)

func _add_visual_road_cell_segment_footprint(out: Dictionary, center_cell: Vector2i, cells: Array, index: int, width: int) -> void:
	_add_road_cell_if_inside(out, center_cell)
	if width <= 1:
		return

	var dirs: Array[Vector2i] = []
	if index > 0 and cells[index - 1] is Vector2i:
		var prev_cell: Vector2i = cells[index - 1]
		var prev_dir: Vector2i = center_cell - prev_cell
		if prev_dir != Vector2i.ZERO:
			dirs.append(Vector2i(signi(prev_dir.x), signi(prev_dir.y)))
	if index < cells.size() - 1 and cells[index + 1] is Vector2i:
		var next_cell: Vector2i = cells[index + 1]
		var next_dir: Vector2i = next_cell - center_cell
		if next_dir != Vector2i.ZERO:
			dirs.append(Vector2i(signi(next_dir.x), signi(next_dir.y)))
	if dirs.is_empty():
		dirs.append(Vector2i.RIGHT)

	for dir in dirs:
		var perp := Vector2i(-dir.y, dir.x)
		if perp == Vector2i.ZERO:
			continue
		_add_road_cell_if_inside(out, center_cell + perp)
		_add_road_cell_if_inside(out, center_cell - perp)

func _add_road_cell_if_inside(out: Dictionary, road_cell: Vector2i) -> void:
	if road_cell.x < 0 or road_cell.x >= level_manager.grid_cols or road_cell.y < 0 or road_cell.y >= level_manager.grid_rows:
		return
	out[_road_cell_key(road_cell)] = road_cell

func signi(v: int) -> int:
	if v > 0:
		return 1
	if v < 0:
		return -1
	return 0


func _road_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _draw_tile_road_system() -> void:
	var road_cells: Dictionary = _collect_visual_road_cells()
	var gs: float = float(level_manager.grid_size)
	var origin: Vector2 = level_manager.grid_origin
	var accent: Color = _tile_road_accent_color()
	var keys: Array = road_cells.keys()
	keys.sort()

	# Soft grounding shadow under the whole modular road footprint.
	for key in keys:
		var cell = road_cells[key]
		var rect: Rect2 = Rect2(origin + Vector2(cell.x * gs, cell.y * gs), Vector2(gs, gs))
		draw_rect(rect.grow(3.0), Color(0.0, 0.0, 0.0, 0.26))

	for key in keys:
		var cell = road_cells[key]
		_draw_sci_fi_road_cell(cell, road_cells, accent)

	_draw_tile_road_roundabouts(accent)
	_draw_tile_road_energy_nodes(road_cells, accent)

func _tile_road_accent_color() -> Color:
	if current_theme == null:
		return PATH_EDGE_CYAN
	var c: Color = current_theme.color_path_line
	c.a = 1.0
	return c

func _draw_sci_fi_road_cell(cell: Vector2i, road_cells: Dictionary, accent: Color) -> void:
	var gs: float = float(level_manager.grid_size)
	var pos: Vector2 = level_manager.grid_origin + Vector2(cell.x * gs, cell.y * gs)
	var rect: Rect2 = Rect2(pos, Vector2(gs, gs))
	var frame: Rect2 = rect.grow(-4.0)
	var shell: Rect2 = rect.grow(-7.0)
	var plate: Rect2 = rect.grow(-10.0)
	var core: Rect2 = rect.grow(-14.0)
	var is_main: bool = _is_main_path_cell(cell)
	var bevel_color: Color = Color(0.16, 0.20, 0.25, 1.0) if is_main else Color(0.12, 0.16, 0.20, 1.0)
	var seam_color: Color = Color(0.0, 0.0, 0.0, 0.40)
	var edge_glow: Color = _with_alpha(accent, 0.18 if is_main else 0.12)
	var edge_main: Color = _with_alpha(accent, 0.84 if is_main else 0.76)
	var edge_core: Color = _with_alpha(Color.WHITE, 0.26 if is_main else 0.18)
	var top_accent: Color = _with_alpha(ROUTE_ARROW_DANGER if is_main else accent, 0.14 if is_main else 0.06)
	var bottom_spec: Color = _with_alpha(Color.WHITE, 0.04 if is_main else 0.025)

	# Material / shadow base.
	draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(rect, Color(0.03, 0.04, 0.05, 0.96))
	draw_rect(frame, Color(0.10, 0.13, 0.17, 1.0) if is_main else Color(0.08, 0.11, 0.14, 1.0))
	draw_rect(shell, PATH_METAL_DARK)
	draw_rect(plate, PATH_METAL_MID if is_main else Color(0.04, 0.06, 0.09, 1.0))
	draw_rect(core, Color(0.03, 0.05, 0.08, 1.0) if is_main else Color(0.025, 0.035, 0.055, 1.0))

	# Bevel / material shading.
	draw_line(frame.position, Vector2(frame.end.x, frame.position.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.68 if is_main else 0.42), 2.0)
	draw_line(frame.position, Vector2(frame.position.x, frame.end.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.52 if is_main else 0.34), 2.0)
	draw_line(Vector2(frame.position.x, frame.end.y), frame.end, Color(0.0, 0.0, 0.0, 0.42), 2.0)
	draw_line(Vector2(frame.end.x, frame.position.y), frame.end, Color(0.0, 0.0, 0.0, 0.54), 2.0)
	draw_rect(shell, bevel_color, false, 1.2)
	draw_rect(plate, Color(0.0, 0.0, 0.0, 0.42), false, 1.0)

	# Plate seams and subtle paneling.
	var cx: float = rect.position.x + gs * 0.5
	var cy: float = rect.position.y + gs * 0.5
	draw_line(Vector2(rect.position.x + 12.0, cy), Vector2(rect.end.x - 12.0, cy), seam_color, 1.0)
	draw_line(Vector2(cx, rect.position.y + 12.0), Vector2(cx, rect.end.y - 12.0), seam_color, 1.0)
	if is_main:
		draw_line(rect.position + Vector2(14.0, 16.0), rect.position + Vector2(gs * 0.36, 16.0), top_accent, 1.0)
		draw_line(rect.end - Vector2(14.0, 16.0), rect.end - Vector2(gs * 0.36, 16.0), top_accent, 1.0)
		draw_line(rect.position + Vector2(16.0, gs - 16.0), rect.position + Vector2(gs * 0.30, gs - 16.0), bottom_spec, 1.0)
	else:
		draw_line(rect.position + Vector2(16.0, 16.0), rect.position + Vector2(gs * 0.28, 16.0), _with_alpha(accent, 0.045), 0.8)
		draw_line(rect.end - Vector2(16.0, 16.0), rect.end - Vector2(gs * 0.28, 16.0), _with_alpha(accent, 0.045), 0.8)

	# Soft top-left highlight and lower shadow to fake metallic material.
	draw_rect(Rect2(core.position + Vector2(2.0, 2.0), Vector2(core.size.x - 4.0, max(8.0, core.size.y * 0.22))), Color(1.0, 1.0, 1.0, 0.035 if is_main else 0.025))
	draw_rect(Rect2(core.position + Vector2(2.0, core.size.y * 0.68), Vector2(core.size.x - 4.0, core.size.y * 0.22)), Color(0.0, 0.0, 0.0, 0.07))

	# Neon edge only on the outside of the road mass.
	var north: bool = not road_cells.has(_road_cell_key(cell + Vector2i(0, -1)))
	var south: bool = not road_cells.has(_road_cell_key(cell + Vector2i(0, 1)))
	var west: bool = not road_cells.has(_road_cell_key(cell + Vector2i(-1, 0)))
	var east: bool = not road_cells.has(_road_cell_key(cell + Vector2i(1, 0)))
	var inset: float = 7.0
	if north:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.end.x - inset, rect.position.y + inset), edge_glow, edge_main, edge_core)
	if south:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.end.y - inset), Vector2(rect.end.x - inset, rect.end.y - inset), edge_glow, edge_main, edge_core)
	if west:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.position.x + inset, rect.end.y - inset), edge_glow, edge_main, edge_core)
	if east:
		_draw_neon_edge(Vector2(rect.end.x - inset, rect.position.y + inset), Vector2(rect.end.x - inset, rect.end.y - inset), edge_glow, edge_main, edge_core)

	if is_main:
		_draw_lane_panel_overlay(cell, rect)

	# Small corner bolts.
	for corner in [rect.position + Vector2(13.0, 13.0), Vector2(rect.end.x - 13.0, rect.position.y + 13.0), rect.end - Vector2(13.0, 13.0), Vector2(rect.position.x + 13.0, rect.end.y - 13.0)]:
		draw_circle(corner, 1.8, Color(0.0, 0.0, 0.0, 0.70))
		draw_circle(corner, 0.9, _with_alpha(accent, 0.36 if is_main else 0.22))

func _is_main_path_cell(cell: Vector2i) -> bool:
	if level_manager == null:
		return false
	for p_id in level_manager.multi_paths:
		var cells: Array = level_manager.multi_paths[p_id]
		for c in cells:
			if c is Vector2i and c == cell:
				return true
	return false

func _get_path_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if level_manager == null:
		return dirs
	for p_id in level_manager.multi_paths:
		var cells: Array = level_manager.multi_paths[p_id]
		for i in range(cells.size()):
			if not (cells[i] is Vector2i) or cells[i] != cell:
				continue
			if i > 0 and cells[i - 1] is Vector2i:
				var prev_dir: Vector2i = cells[i] - cells[i - 1]
				prev_dir = Vector2i(signi(prev_dir.x), signi(prev_dir.y))
				if prev_dir != Vector2i.ZERO and not dirs.has(prev_dir):
					dirs.append(prev_dir)
			if i < cells.size() - 1 and cells[i + 1] is Vector2i:
				var next_dir: Vector2i = cells[i + 1] - cells[i]
				next_dir = Vector2i(signi(next_dir.x), signi(next_dir.y))
				if next_dir != Vector2i.ZERO and not dirs.has(next_dir):
					dirs.append(next_dir)
	return dirs

func _draw_lane_panel_overlay(cell: Vector2i, rect: Rect2) -> void:
	var dirs: Array[Vector2i] = _get_path_neighbors(cell)
	var has_h: bool = false
	var has_v: bool = false
	for d in dirs:
		if d.x != 0:
			has_h = true
		if d.y != 0:
			has_v = true
	var lane_fill := Color(0.10, 0.11, 0.13, 0.96)
	var lane_shadow := Color(0.0, 0.0, 0.0, 0.46)
	var lane_border := Color(0.20, 0.18, 0.18, 0.55)
	var warm := _with_alpha(ROUTE_ARROW_DANGER, 0.52)
	var hot := _with_alpha(ROUTE_ARROW_HOT, 0.44)
	var spec := _with_alpha(Color.WHITE, 0.05)
	if has_h:
		var h_rect := Rect2(rect.position + Vector2(2.0, rect.size.y * 0.30), Vector2(rect.size.x - 4.0, rect.size.y * 0.40))
		draw_rect(h_rect.grow(2.0), lane_shadow)
		draw_rect(h_rect, lane_fill)
		draw_rect(h_rect, lane_border, false, 1.0)
		draw_line(h_rect.position + Vector2(2.0, 2.0), Vector2(h_rect.end.x - 2.0, h_rect.position.y + 2.0), warm, 1.2)
		draw_line(Vector2(h_rect.position.x + 2.0, h_rect.end.y - 2.0), h_rect.end - Vector2(2.0, 2.0), warm, 1.2)
		draw_line(h_rect.position + Vector2(4.0, h_rect.size.y * 0.5), Vector2(h_rect.end.x - 4.0, h_rect.position.y + h_rect.size.y * 0.5), Color(0.0, 0.0, 0.0, 0.25), 1.0)
		draw_line(h_rect.position + Vector2(6.0, 4.0), Vector2(h_rect.end.x - 10.0, h_rect.position.y + 4.0), spec, 0.8)
		for x in range(int(h_rect.position.x + 10.0), int(h_rect.end.x - 10.0), 12):
			draw_line(Vector2(float(x), h_rect.position.y + 5.0), Vector2(float(x + 4), h_rect.position.y + 5.0), hot, 0.8)
			draw_line(Vector2(float(x), h_rect.end.y - 5.0), Vector2(float(x + 4), h_rect.end.y - 5.0), hot, 0.8)
	if has_v:
		var v_rect := Rect2(rect.position + Vector2(rect.size.x * 0.30, 2.0), Vector2(rect.size.x * 0.40, rect.size.y - 4.0))
		draw_rect(v_rect.grow(2.0), lane_shadow)
		draw_rect(v_rect, lane_fill)
		draw_rect(v_rect, lane_border, false, 1.0)
		draw_line(v_rect.position + Vector2(2.0, 2.0), Vector2(v_rect.position.x + 2.0, v_rect.end.y - 2.0), warm, 1.2)
		draw_line(Vector2(v_rect.end.x - 2.0, v_rect.position.y + 2.0), v_rect.end - Vector2(2.0, 2.0), warm, 1.2)
		draw_line(v_rect.position + Vector2(v_rect.size.x * 0.5, 4.0), Vector2(v_rect.position.x + v_rect.size.x * 0.5, v_rect.end.y - 4.0), Color(0.0, 0.0, 0.0, 0.25), 1.0)
		draw_line(v_rect.position + Vector2(4.0, 6.0), Vector2(v_rect.position.x + 4.0, v_rect.end.y - 10.0), spec, 0.8)
		for y in range(int(v_rect.position.y + 10.0), int(v_rect.end.y - 10.0), 12):
			draw_line(Vector2(v_rect.position.x + 5.0, float(y)), Vector2(v_rect.position.x + 5.0, float(y + 4)), hot, 0.8)
			draw_line(Vector2(v_rect.end.x - 5.0, float(y)), Vector2(v_rect.end.x - 5.0, float(y + 4)), hot, 0.8)

func _draw_neon_edge(a: Vector2, b: Vector2, glow: Color, main: Color, core: Color) -> void:
	draw_line(a, b, glow, 7.0)
	draw_line(a, b, main, 2.6)
	draw_line(a, b, core, 1.0)

func _draw_tile_road_roundabouts(accent: Color) -> void:
	var hubs = level_manager.level_data.get("road_visual_roundabout_cells", [])
	if not (hubs is Array):
		return
	var gs: float = float(level_manager.grid_size)
	for item in hubs:
		if not (item is Array) or item.size() < 2:
			continue
		var cell: Vector2i = Vector2i(int(item[0]), int(item[1]))
		var center: Vector2 = level_manager.cell_to_world_center(cell)
		var radius: float = gs * 1.45
		var inner_radius: float = gs * 0.64
		# Cover the square tile joins with a clean circular mechanical hub.
		draw_circle(center, radius + 5.0, Color(0.0, 0.0, 0.0, 0.30))
		draw_circle(center, radius, PATH_METAL_DARK)
		draw_circle(center, radius * 0.86, PATH_METAL_MID)
		draw_circle(center, inner_radius, PATH_METAL_DARK)
		draw_arc(center, radius * 0.96, 0.0, TAU, 64, _with_alpha(accent, 0.22), 9.0)
		draw_arc(center, radius * 0.96, 0.0, TAU, 64, _with_alpha(accent, 0.78), 2.5)
		draw_arc(center, inner_radius, 0.0, TAU, 48, _with_alpha(accent, 0.58), 2.0)
		for i in range(8):
			var a: float = float(i) * TAU / 8.0
			var p1: Vector2 = center + Vector2(cos(a), sin(a)) * inner_radius
			var p2: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.82
			draw_line(p1, p2, Color(0.0, 0.0, 0.0, 0.28), 1.0)
			var node_pos: Vector2 = center + Vector2(cos(a), sin(a)) * radius * 0.72
			draw_circle(node_pos, 3.0, Color(0.0, 0.0, 0.0, 0.65))
			draw_circle(node_pos, 1.8, _with_alpha(accent, 0.85))
		draw_circle(center, gs * 0.20, _with_alpha(accent, 0.18))
		draw_circle(center, gs * 0.08, _with_alpha(Color.WHITE, 0.70))

func _draw_tile_road_energy_nodes(_road_cells: Dictionary, accent: Color) -> void:
	var nodes = level_manager.level_data.get("road_visual_node_cells", [])
	if not (nodes is Array):
		return
	var gs: float = float(level_manager.grid_size)
	var pulse: float = 0.5 + sin(preview_timer * 3.2) * 0.5
	for item in nodes:
		if not (item is Array) or item.size() < 2:
			continue
		var cell: Vector2i = Vector2i(int(item[0]), int(item[1]))
		var pos: Vector2 = level_manager.cell_to_world_center(cell)
		var r: float = gs * 0.19
		draw_circle(pos, r * 1.9, _with_alpha(accent, 0.08 + pulse * 0.08))
		draw_circle(pos, r, Color(0.02, 0.04, 0.06, 1.0))
		draw_arc(pos, r * 1.15, 0.0, TAU, 24, _with_alpha(accent, 0.65), 2.0)
		draw_circle(pos, r * 0.46, _with_alpha(accent, 0.80))
		draw_circle(pos, r * 0.18, _with_alpha(Color.WHITE, 0.85))

func _draw_path_overlays() -> void:
	if not show_path_overlays:
		return
	if _should_use_tile_roads():
		if _should_show_tile_route_arrow():
			_draw_tile_route_flow_arrow()
		return

	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2:
			continue

		draw_polyline(points, _with_alpha(PATH_EDGE_CYAN, 0.12), current_theme.path_glow_width, true)
		draw_polyline(points, _with_alpha(PATH_EDGE_CYAN, 0.42), 2.0, true)
		draw_polyline(points, _with_alpha(PATH_INNER_AMBER, 0.22), 1.0, true)

	if preview_alpha > 0.01:
		_draw_preview_pulses()

func _draw_tile_route_flow_arrow() -> void:
	var path_id: String = "default"
	if preview_alpha > 0.01 and not active_preview_paths.is_empty():
		path_id = active_preview_paths[0]
	var points = level_manager.get_path_points_for_id(path_id)
	if points.size() < 2:
		return

	_draw_embedded_lane_strip(points)
	var pulse: float = 0.97 + sin(preview_timer * 2.0) * 0.03
	for spec in _get_manual_chevron_specs(path_id):
		_draw_manual_chevron_from_spec(spec, pulse)

	var start_pos: Vector2 = points[0]
	var end_pos: Vector2 = points[points.size() - 1]
	draw_circle(start_pos, 2.5, _with_alpha(ROUTE_ARROW_DANGER, 0.10))
	draw_circle(end_pos, 2.5, _with_alpha(ROUTE_ARROW_HOT, 0.10))

func _get_manual_chevron_specs(path_id: String) -> Array:
	var manual = level_manager.level_data.get("road_visual_manual_chevrons", null)
	if manual is Dictionary and manual.has(path_id):
		var path_specs = manual[path_id]
		if path_specs is Array:
			return path_specs
	elif manual is Array:
		return manual

	# Fallback layout tuned to resemble the reference screenshot.
	var cells: Array = []
	if level_manager.multi_paths.has(path_id):
		cells = level_manager.multi_paths[path_id]
	if cells.is_empty():
		return []
	var specs: Array = []
	# Long straight: 4 evenly-spaced chevrons.
	for idx in [1, 4, 8, 12]:
		if idx >= 0 and idx < cells.size() and cells[idx] is Vector2i:
			specs.append({"cell": cells[idx], "dir": "right", "offset": 0.0})
	# Upper-right approach to the core: 2 chevrons.
	var added: int = 0
	for idx in range(cells.size() - 1, -1, -1):
		if not (cells[idx] is Vector2i):
			continue
		var cell: Vector2i = cells[idx]
		if cell.y >= cells[0].y:
			continue
		var dirs: Array[Vector2i] = _get_path_neighbors(cell)
		for d in dirs:
			if d.x > 0:
				specs.append({"cell": cell, "dir": "right", "offset": 0.0})
				added += 1
				break
		if added >= 2:
			break
	return specs

func _draw_manual_chevron_from_spec(spec: Variant, pulse: float) -> void:
	if not (spec is Dictionary):
		return
	if not spec.has("cell"):
		return
	var cell: Vector2i = spec["cell"]
	var dir: Vector2 = Vector2.RIGHT
	if spec.has("dir"):
		var dv = spec["dir"]
		if dv is Vector2:
			dir = dv.normalized()
		elif dv is Vector2i:
			dir = Vector2(dv.x, dv.y).normalized()
		elif dv is String:
			match String(dv).to_lower():
				"right", "east": dir = Vector2.RIGHT
				"left", "west": dir = Vector2.LEFT
				"up", "north": dir = Vector2.UP
				"down", "south": dir = Vector2.DOWN
	var offset_t: float = float(spec.get("offset", 0.0))
	var pos: Vector2 = level_manager.cell_to_world_center(cell) + dir * offset_t * float(level_manager.grid_size)
	_draw_embedded_lane_chevron(pos, dir, pulse)

func _draw_embedded_lane_strip(points: Array) -> void:
	var shadow: Color = ROUTE_GROOVE_DARK
	var fill: Color = ROUTE_GROOVE_FILL
	var warm_edge: Color = _with_alpha(ROUTE_ARROW_DANGER, 0.11)
	var hot_core: Color = _with_alpha(ROUTE_ARROW_HOT, 0.09)
	var spec: Color = _with_alpha(Color.WHITE, 0.045)

	draw_polyline(points, shadow, 16.0, true)
	draw_polyline(points, fill, 11.5, true)
	draw_polyline(points, warm_edge, 5.0, true)
	draw_polyline(points, hot_core, 1.6, true)
	draw_polyline(points, spec, 0.8, true)

func _draw_embedded_lane_chevron(pos: Vector2, dir: Vector2, fade: float = 1.0) -> void:
	var glow_color: Color = _with_alpha(ROUTE_ARROW_DANGER, 0.18 * fade)
	var hot_color: Color = _with_alpha(ROUTE_ARROW_HOT, 0.62 * fade)
	var main_color: Color = _with_alpha(ROUTE_ARROW_DANGER, 0.92 * fade)
	var core_color: Color = _with_alpha(Color.WHITE, 0.16 * fade)
	var length: float = ROUTE_CHEVRON_LENGTH
	var half_width: float = ROUTE_CHEVRON_HALF_WIDTH
	var pair_offset: float = ROUTE_CHEVRON_PAIR_OFFSET
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	for offset in [-pair_offset * 0.5, pair_offset * 0.5]:
		var center: Vector2 = pos + dir * offset
		var back: Vector2 = center - dir * (length * 0.5)
		var tip: Vector2 = center + dir * (length * 0.5)
		var left: Vector2 = back + perp * half_width
		var right: Vector2 = back - perp * half_width
		draw_line(left, tip, glow_color, 8.0)
		draw_line(right, tip, glow_color, 8.0)
		draw_line(left, tip, hot_color, 4.0)
		draw_line(right, tip, hot_color, 4.0)
		draw_line(left, tip, main_color, 1.8)
		draw_line(right, tip, main_color, 1.8)
		draw_line(left.lerp(tip, 0.64), tip, core_color, 0.9)
		draw_line(right.lerp(tip, 0.64), tip, core_color, 0.9)

func _should_show_tile_route_arrow() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return true
	var wave_manager = scene.get_node_or_null("WaveManager")
	if wave_manager == null:
		return true
	if bool(wave_manager.get("is_wave_running")):
		return false
	if bool(wave_manager.get("is_spawning")):
		return false
	return true

func _polyline_total_length(points: Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _sample_polyline(points: Array, distance_along: float) -> Array:
	if points.size() == 0:
		return [Vector2.ZERO, Vector2.RIGHT]
	if points.size() == 1:
		return [points[0], Vector2.RIGHT]

	var remaining: float = max(distance_along, 0.0)
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg_len: float = a.distance_to(b)
		if seg_len <= 0.001:
			continue
		if remaining <= seg_len:
			var dir: Vector2 = (b - a).normalized()
			return [a.lerp(b, remaining / seg_len), dir]
		remaining -= seg_len

	var last_a: Vector2 = points[points.size() - 2]
	var last_b: Vector2 = points[points.size() - 1]
	var last_dir: Vector2 = (last_b - last_a).normalized()
	if last_dir.length() <= 0.001:
		last_dir = Vector2.RIGHT
	return [last_b, last_dir]
func _draw_preview_pulses() -> void:
	var time = preview_timer
	var gs = level_manager.grid_size
	
	for path_idx in range(active_preview_paths.size()):
		var p_id = active_preview_paths[path_idx]
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		var lane_phase = float(path_idx) * 0.35
		var pulse = 0.75 + sin((time + lane_phase) * 4.0) * 0.15
		var alpha = preview_alpha * pulse
		var preview_cyan := _with_alpha(PATH_EDGE_CYAN, 0.54 * alpha)
		var preview_glow := _with_alpha(PATH_EDGE_CYAN, 0.18 * alpha)
		var preview_amber := _with_alpha(PATH_INNER_AMBER, 0.32 * alpha)
		
		draw_polyline(points, preview_glow, gs * 0.74, true)
		draw_polyline(points, preview_cyan, gs * 0.58, true)
		draw_polyline(points, PATH_METAL_DARK, gs * 0.48, true)
		draw_polyline(points, preview_amber, 4.0, true)
		
		for pt in points:
			var node_size = 8.0 + sin((time + lane_phase) * 5.0 + pt.x) * 2.0
			draw_arc(pt, node_size, 0, TAU, 6, _with_alpha(PATH_EDGE_CYAN, 0.34 * preview_alpha), 1.4)
			draw_circle(pt, 2.0, _with_alpha(PATH_EDGE_CYAN, 0.50 * preview_alpha))
		
		for i in range(points.size() - 1):
			var p1 = points[i]
			var p2 = points[i+1]
			var dist = p1.distance_to(p2)
			if dist <= 0.0: continue
			var dir = (p2 - p1).normalized()
			
			var arrow_spacing = 92.0
			var offset = fmod((time + lane_phase) * 125.0, arrow_spacing)
			
			var d = offset
			while d < dist:
				var pos = p1 + dir * d
				var edge_fade = min(d, dist - d) / 30.0 # Increased fade distance
				var a_color = _with_alpha(PATH_EDGE_CYAN, 0.85 * preview_alpha * clamp(edge_fade, 0.0, 1.0))
				
				_draw_chevron(pos, dir, a_color)
				d += arrow_spacing

func _draw_markers(gs: int) -> void:
	var font = Control.new().get_theme_font("font")
	var font_size = 14
	var drawn_base_positions = []
	
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.is_empty(): continue
		
		var spawn_pos = points[0]
		var label = "A" if str(p_id) == "default" else ""
		var active_spawn = active_preview_paths.has(str(p_id)) and preview_alpha > 0.01
		var portal_radius := gs * (0.55 if str(p_id) == "default" else 0.40)
		_draw_spawn_portal(spawn_pos, portal_radius, current_theme.color_spawn, active_spawn)
		if label != "":
			var label_color = current_theme.color_spawn
			label_color.a = 1.0 if active_spawn else 0.55
			draw_string(font, spawn_pos + Vector2(-8, -gs * 0.7), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, label_color)
		
		var base_pos = points[points.size() - 1]
		var is_duplicate = false
		for pos in drawn_base_positions:
			if pos.distance_to(base_pos) < 5.0:
				is_duplicate = true
				break
		
		if not is_duplicate:
			_draw_energy_core(base_pos, gs * 0.6, current_theme.color_base, _preview_has_base_at(base_pos))
			draw_string(font, base_pos + Vector2(-15, gs * 0.85), "CORE", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, current_theme.color_base)
			drawn_base_positions.append(base_pos)

func _draw_spawn_portal(pos: Vector2, radius: float, color: Color, active: bool = false) -> void:
	var time = preview_timer * 2.0
	var active_boost = preview_alpha if active else 0.0
	var ring_color = color
	ring_color.a = lerp(0.45, 0.95, active_boost)
	var active_cyan = _with_alpha(PATH_EDGE_CYAN, 0.38 * active_boost)
	
	# Tech Ring Base
	draw_arc(pos, radius * 1.1, 0, TAU, 32, Color(0.1, 0.1, 0.1, 0.8), 6.0)
	draw_arc(pos, radius * 1.1, 0, TAU, 32, ring_color, 2.0 + active_boost)
	
	if active:
		var s_pulse = (sin(time * 4.0) + 1.0) * 0.5
		draw_arc(pos, radius * (1.1 + s_pulse * 0.2), 0, TAU, 32, _with_alpha(color, 0.3 * preview_alpha), 4.0)
	
	# Outer Frame (Square)
	var s_size = radius * 1.3
	draw_rect(Rect2(pos.x - s_size, pos.y - s_size, s_size * 2, s_size * 2), Color(0.2, 0.2, 0.2, 0.4), false, 2.0)
	
	# Rotating Emitters
	for i in range(4):
		var ang = time + (i * TAU / 4)
		var e_pos = pos + Vector2(cos(ang), sin(ang)) * radius
		draw_circle(e_pos, 5, Color.BLACK)
		draw_circle(e_pos, 4, ring_color)
		draw_circle(e_pos, 2, Color.WHITE)
		
		# Energy Beam to center
		draw_line(e_pos, pos, Color(color.r, color.g, color.b, 0.25 + active_boost * 0.3), 1.5)
	
	# Center Warp Effect (Octagon)
	var pts = PackedVector2Array()
	var sides = 8
	var rot = -time * 0.4
	for i in range(sides):
		var a = rot + (i * TAU / sides)
		pts.append(pos + Vector2(cos(a), sin(a)) * radius * 0.7)
	
	draw_colored_polygon(pts, Color(0.02, 0.02, 0.05, 0.95))
	draw_polyline(pts + PackedVector2Array([pts[0]]), ring_color, 2.5)
	
	# Core Pulse
	var pulse = (sin(time * 3.0) + 1.0) * 0.5
	draw_circle(pos, radius * (0.4 + active_boost * 0.15) * pulse, Color(color.r, color.g, color.b, 0.5 + active_boost * 0.3))
	draw_circle(pos, 4.0, Color.WHITE)

func _draw_energy_core(pos: Vector2, radius: float, color: Color, active: bool = false) -> void:
	var time = preview_timer
	var active_boost = preview_alpha if active else 0.0
	
	# Containment Field (Shield)
	var shield_pulse = 1.0 + sin(time * 2.0) * 0.05
	draw_arc(pos, radius * 1.4, 0, TAU, 48, _with_alpha(PATH_EDGE_CYAN, 0.15 + active_boost * 0.1), 1.5)
	
	# Hexagonal Containment
	var base_pts = PackedVector2Array()
	for i in range(6):
		var a = (i * TAU / 6)
		base_pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	
	draw_colored_polygon(base_pts, Color(0.05, 0.08, 0.12, 0.95))
	draw_polyline(base_pts + PackedVector2Array([base_pts[0]]), _with_alpha(PATH_EDGE_CYAN, 0.4 + active_boost * 0.3), 3.0)
	
	# Technical details on hex corners
	for p in base_pts:
		draw_circle(p, 4, Color.BLACK)
		draw_circle(p, 2.5, _with_alpha(PATH_EDGE_CYAN, 0.8))
	
	# Inner Spinning Core
	var core_pts = PackedVector2Array()
	var rot = time * 2.5
	for i in range(3):
		var a = rot + (i * TAU / 3)
		core_pts.append(pos + Vector2(cos(a), sin(a)) * radius * 0.75)
	
	draw_colored_polygon(core_pts, color)
	draw_polyline(core_pts + PackedVector2Array([core_pts[0]]), Color.WHITE, 2.5)
	
	# Pulsing Glow
	var pulse = (sin(time * 6.0) + 1.0) * 0.5
	draw_circle(pos, radius * 0.35, Color.WHITE)
	draw_arc(pos, radius * (0.45 + pulse * (0.25 + active_boost * 0.1)), 0, TAU, 32, Color(color.r, color.g, color.b, 0.5 + active_boost * 0.3), 2.0 + active_boost)
	
	# Orbiting Nodes
	for i in range(3):
		var ang = -time * 2.0 + (i * TAU / 3)
		var n_pos = pos + Vector2(cos(ang), sin(ang)) * radius * 1.25
		draw_line(pos, n_pos, _with_alpha(color, 0.2), 1.0)
		draw_circle(n_pos, 4, Color.BLACK)
		draw_circle(n_pos, 3, color)
		draw_circle(n_pos, 1.5, Color.WHITE)

func _draw_chevron(pos: Vector2, dir: Vector2, color: Color) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var tip = pos + dir * 14.0
	var back = pos - dir * 6.0
	
	# Glow layer
	draw_polyline([back + perp * 10.0, tip, back - perp * 10.0], _with_alpha(color, color.a * 0.2), 6.0, true)
	# Main line
	draw_polyline([back + perp * 8.0, tip, back - perp * 8.0], color, 3.5, true)
	# High contrast center
	draw_polyline([back + perp * 8.0, tip, back - perp * 8.0], _with_alpha(Color.WHITE, color.a * 0.6), 1.0, true)

func _preview_has_base_at(base_pos: Vector2) -> bool:
	if preview_alpha <= 0.01:
		return false
	for p_id in active_preview_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() > 0 and points[points.size() - 1].distance_to(base_pos) < 5.0:
			return true
	return false

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))

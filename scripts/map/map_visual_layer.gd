extends Node2D

# Map Visual Layer (FALLBACK RENDERER)
# MazeMapRenderer handles primary map drawing. This layer now only provides
# minimal fallback rendering: dark background, faint grid, and spawn/base markers.
# All complex tile road / path / overlay drawing has been removed.

const PERFORMANCE_MODE := true  # Disables expensive tile details for stable 60 FPS

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
const GUIDANCE_EDGE_CYAN := Color(0.18, 0.92, 1.0, 1.0)
const GUIDANCE_EDGE_BLUE := Color(0.05, 0.34, 0.72, 1.0)
const GUIDANCE_CENTER_RED := Color(1.0, 0.23, 0.09, 1.0)
const GUIDANCE_CENTER_AMBER := Color(1.0, 0.58, 0.12, 1.0)
const GUIDE_CRACK_BASE     := Color(0.22, 0.08, 0.02, 0.72)
const GUIDE_CRACK_GLOW     := Color(1.0,  0.38, 0.10, 0.18)
const GUIDE_CHEVRON_SHADOW := Color(0.0,  0.0,  0.0,  0.55)

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
	set_process(false)  # Map is static — re-enable only when preview paths are fading

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
	set_process(true)  # Re-enable fade animation
	queue_redraw()

func _process(delta: float) -> void:
	preview_timer += delta
	var prev_alpha := preview_alpha
	preview_alpha = move_toward(preview_alpha, preview_target_alpha, PREVIEW_FADE_SPEED * delta)
	if preview_alpha <= 0.001 and preview_target_alpha <= 0.0:
		active_preview_paths.clear()
		set_process(false)  # Nothing animating — stop processing until next preview
		return
	if absf(preview_alpha - prev_alpha) > 0.001 or not active_preview_paths.is_empty():
		queue_redraw()

func _clear_props() -> void:
	for child in prop_container.get_children():
		child.queue_free()

func _generate_decorations() -> void:
	if PERFORMANCE_MODE: return  # Props disabled for performance
	if current_theme == null or level_manager == null: return
	
	# Use deterministic random seed based on level name
	var seed_val = level_manager.level_id.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
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
	
	# 1. Dark background fill — covers entire viewable area
	var huge_rect = Rect2(origin - Vector2(5000, 5000), Vector2(10000, 10000))
	draw_rect(huge_rect, current_theme.color_bg)
	
	# 2. Subtle grid lines
	if current_theme.color_grid.a > 0:
		for x in range(cols + 1):
			draw_line(origin + Vector2(x * gs, 0), origin + Vector2(x * gs, rows * gs), current_theme.color_grid)
		for y in range(rows + 1):
			draw_line(origin + Vector2(0, y * gs), origin + Vector2(cols * gs, y * gs), current_theme.color_grid)
	
	# 3. Spawn and base markers only (MazeMapRenderer handles all path/tile drawing)
	_draw_markers(gs)

func _draw_foundation_tile(rect: Rect2) -> void:
	var color = current_theme.color_buildable
	var border = Color(color.r, color.g, color.b, 0.4)
	if PERFORMANCE_MODE:
		draw_rect(rect, color)
		draw_rect(rect.grow(-2), border, false, 1.0)
		return
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
	draw_polyline(PackedVector2Array([p + Vector2(s, 0), p, p + Vector2(0, s)]), acc, 2.0)
	draw_polyline(PackedVector2Array([e - Vector2(s, 0), e, e - Vector2(0, s)]), acc, 2.0)
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
	return str(level_manager.level_data.get("road_visual_style", "sci_fi_tile")) == "sci_fi_tile"

func _uses_guidance_lane() -> bool:
	if level_manager == null:
		return false
	return bool(level_manager.level_data.get("road_visual_guidance_lane", true))

func _is_guidance_path_id(path_id: String) -> bool:
	return _uses_guidance_lane() and path_id == "default"

func _is_guidance_cell(cell: Vector2i) -> bool:
	if not _uses_guidance_lane() or level_manager == null:
		return false
	if not level_manager.multi_paths.has("default"):
		return false
	var cells: Array = level_manager.multi_paths["default"]
	for c in cells:
		if c is Vector2i and c == cell:
			return true
	return false

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
		if _is_guidance_cell(cell):
			_draw_guide_lane_cell(cell, road_cells, accent)
		else:
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
	if PERFORMANCE_MODE:
		_draw_cheap_build_tile(cell, road_cells, accent)
		return
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
	var guidance := _is_guidance_cell(cell)
	var edge_accent := GUIDANCE_EDGE_CYAN if guidance else accent
	var edge_glow: Color = _with_alpha(GUIDANCE_EDGE_BLUE if guidance else edge_accent, 0.34 if guidance and is_main else 0.18 if is_main else 0.12)
	var edge_main: Color = _with_alpha(edge_accent, 0.96 if guidance and is_main else 0.84 if is_main else 0.76)
	var edge_core: Color = _with_alpha(Color.WHITE, 0.36 if guidance and is_main else 0.26 if is_main else 0.18)
	var top_accent: Color = _with_alpha(ROUTE_ARROW_DANGER if is_main else accent, 0.18 if is_main else 0.06)
	var bottom_spec: Color = _with_alpha(Color.WHITE, 0.04 if is_main else 0.025)

	# Material / shadow base.
	draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(rect, Color(0.022, 0.028, 0.038, 0.98))
	draw_rect(frame, Color(0.082, 0.105, 0.14, 1.0) if is_main else Color(0.07, 0.09, 0.12, 1.0))
	draw_rect(shell, PATH_METAL_DARK)
	draw_rect(plate, PATH_METAL_MID if is_main else Color(0.035, 0.052, 0.078, 1.0))
	draw_rect(core, Color(0.024, 0.04, 0.062, 1.0) if is_main else Color(0.02, 0.03, 0.05, 1.0))

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
	draw_rect(Rect2(core.position + Vector2(2.0, 2.0), Vector2(core.size.x - 4.0, max(8.0, core.size.y * 0.22))), Color(1.0, 1.0, 1.0, 0.045 if is_main else 0.028))
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

	if is_main and guidance:
		_draw_lane_panel_overlay(cell, rect)
		_draw_guidance_lane_wear(cell, rect)

	# Small corner bolts.
	for corner in [rect.position + Vector2(13.0, 13.0), Vector2(rect.end.x - 13.0, rect.position.y + 13.0), rect.end - Vector2(13.0, 13.0), Vector2(rect.position.x + 13.0, rect.end.y - 13.0)]:
		draw_circle(corner, 1.8, Color(0.0, 0.0, 0.0, 0.70))
		draw_circle(corner, 0.9, _with_alpha(accent, 0.36 if is_main else 0.22))

func _draw_cheap_build_tile(cell: Vector2i, road_cells: Dictionary, accent: Color) -> void:
	var gs := float(level_manager.grid_size)
	var pos: Vector2 = level_manager.grid_origin + Vector2(cell.x * gs, cell.y * gs)
	var rect := Rect2(pos, Vector2(gs, gs))
	var inset := rect.grow(-6.0)
	draw_rect(rect, Color(0.02, 0.03, 0.05, 1.0))
	draw_rect(inset, Color(0.07, 0.09, 0.12, 1.0))
	# Thin cyan border on outer edges only
	var north := not road_cells.has(_road_cell_key(cell + Vector2i(0, -1)))
	var south := not road_cells.has(_road_cell_key(cell + Vector2i(0, 1)))
	var west  := not road_cells.has(_road_cell_key(cell + Vector2i(-1, 0)))
	var east  := not road_cells.has(_road_cell_key(cell + Vector2i(1, 0)))
	var ec := _with_alpha(accent, 0.7)
	var i := 6.0
	if north: draw_line(Vector2(pos.x + i, pos.y + i), Vector2(pos.x + gs - i, pos.y + i), ec, 1.0)
	if south: draw_line(Vector2(pos.x + i, pos.y + gs - i), Vector2(pos.x + gs - i, pos.y + gs - i), ec, 1.0)
	if west:  draw_line(Vector2(pos.x + i, pos.y + i), Vector2(pos.x + i, pos.y + gs - i), ec, 1.0)
	if east:  draw_line(Vector2(pos.x + gs - i, pos.y + i), Vector2(pos.x + gs - i, pos.y + gs - i), ec, 1.0)

func _draw_guide_lane_cell(cell: Vector2i, road_cells: Dictionary, _accent: Color) -> void:
	if PERFORMANCE_MODE:
		_draw_cheap_guide_tile(cell, road_cells)
		return
	var gs: float = float(level_manager.grid_size)
	var pos: Vector2 = level_manager.grid_origin + Vector2(cell.x * gs, cell.y * gs)
	var rect: Rect2 = Rect2(pos, Vector2(gs, gs))
	var frame: Rect2 = rect.grow(-4.0)
	var shell: Rect2 = rect.grow(-7.0)
	var plate: Rect2 = rect.grow(-10.0)
	var core: Rect2 = rect.grow(-14.0)
	var bevel_color: Color = Color(0.20, 0.16, 0.12, 1.0)
	var seam_color: Color = Color(0.0, 0.0, 0.0, 0.40)

	# Material / shadow base — warmer than normal tile, darker core
	draw_rect(rect.grow(2.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(rect, Color(0.022, 0.028, 0.038, 0.98))
	draw_rect(frame, Color(0.082, 0.105, 0.14, 1.0))
	draw_rect(shell, PATH_METAL_DARK)
	draw_rect(plate, PATH_METAL_MID)
	# Core filled with warm dark groove color instead of blue-dark
	draw_rect(core, Color(0.038, 0.018, 0.010, 0.98))

	# Bevel / material shading — identical to regular tile
	draw_line(frame.position, Vector2(frame.end.x, frame.position.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.68), 2.0)
	draw_line(frame.position, Vector2(frame.position.x, frame.end.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.52), 2.0)
	draw_line(Vector2(frame.position.x, frame.end.y), frame.end, Color(0.0, 0.0, 0.0, 0.42), 2.0)
	draw_line(Vector2(frame.end.x, frame.position.y), frame.end, Color(0.0, 0.0, 0.0, 0.54), 2.0)
	draw_rect(shell, bevel_color, false, 1.2)
	draw_rect(plate, Color(0.0, 0.0, 0.0, 0.42), false, 1.0)

	# Guide tile border — orange-red panel frame, makes guide tiles immediately distinct
	draw_rect(shell, _with_alpha(GUIDANCE_CENTER_RED, 0.22), false, 3.5)
	draw_rect(shell, _with_alpha(GUIDANCE_CENTER_RED, 0.76), false, 1.4)
	draw_rect(shell.grow(-1.5), _with_alpha(GUIDANCE_CENTER_AMBER, 0.28), false, 0.8)

	# Plate seams
	var cx: float = rect.position.x + gs * 0.5
	var cy: float = rect.position.y + gs * 0.5
	draw_line(Vector2(rect.position.x + 12.0, cy), Vector2(rect.end.x - 12.0, cy), seam_color, 1.0)
	draw_line(Vector2(cx, rect.position.y + 12.0), Vector2(cx, rect.end.y - 12.0), seam_color, 1.0)
	var top_accent: Color = _with_alpha(ROUTE_ARROW_DANGER, 0.18)
	var bottom_spec: Color = _with_alpha(Color.WHITE, 0.04)
	draw_line(rect.position + Vector2(14.0, 16.0), rect.position + Vector2(gs * 0.36, 16.0), top_accent, 1.0)
	draw_line(rect.end - Vector2(14.0, 16.0), rect.end - Vector2(gs * 0.36, 16.0), top_accent, 1.0)
	draw_line(rect.position + Vector2(16.0, gs - 16.0), rect.position + Vector2(gs * 0.30, gs - 16.0), bottom_spec, 1.0)

	# Metallic highlight and shadow on core area
	draw_rect(Rect2(core.position + Vector2(2.0, 2.0), Vector2(core.size.x - 4.0, max(8.0, core.size.y * 0.22))), Color(1.0, 1.0, 1.0, 0.045))
	draw_rect(Rect2(core.position + Vector2(2.0, core.size.y * 0.68), Vector2(core.size.x - 4.0, core.size.y * 0.22)), Color(0.0, 0.0, 0.0, 0.07))
	draw_line(core.position + Vector2(3.0, 3.0), Vector2(core.end.x - 3.0, core.position.y + 3.0), _with_alpha(Color.WHITE, 0.08), 0.8)

	# Neon edge only on outer boundary — orange-red, contrasting with normal tile cyan edges
	var north: bool = not road_cells.has(_road_cell_key(cell + Vector2i(0, -1)))
	var south: bool = not road_cells.has(_road_cell_key(cell + Vector2i(0, 1)))
	var west: bool = not road_cells.has(_road_cell_key(cell + Vector2i(-1, 0)))
	var east: bool = not road_cells.has(_road_cell_key(cell + Vector2i(1, 0)))
	var inset: float = 7.0
	var edge_glow: Color = _with_alpha(GUIDANCE_CENTER_RED, 0.24)
	var edge_main: Color = _with_alpha(GUIDANCE_CENTER_RED, 0.90)
	var edge_core: Color = _with_alpha(GUIDANCE_CENTER_AMBER, 0.58)
	if north:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.end.x - inset, rect.position.y + inset), edge_glow, edge_main, edge_core)
	if south:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.end.y - inset), Vector2(rect.end.x - inset, rect.end.y - inset), edge_glow, edge_main, edge_core)
	if west:
		_draw_neon_edge(Vector2(rect.position.x + inset, rect.position.y + inset), Vector2(rect.position.x + inset, rect.end.y - inset), edge_glow, edge_main, edge_core)
	if east:
		_draw_neon_edge(Vector2(rect.end.x - inset, rect.position.y + inset), Vector2(rect.end.x - inset, rect.end.y - inset), edge_glow, edge_main, edge_core)

	# Per-tile embedded cracks
	_draw_tile_cracks(rect, cell)

	# Chevrons only at corners or every 3rd tile — keeps lane clean, not repetitive
	var exit_dir: Vector2i = _get_guidance_exit_dir(cell)
	var cell_idx: int = _get_guidance_cell_index(cell)
	if exit_dir != Vector2i.ZERO and (_is_guidance_corner(cell) or (cell_idx >= 0 and cell_idx % 3 == 1)):
		_draw_embedded_chevron(rect, exit_dir)

	# Corner bolts — orange-red accent reinforces guide tile identity
	for corner in [rect.position + Vector2(13.0, 13.0), Vector2(rect.end.x - 13.0, rect.position.y + 13.0), rect.end - Vector2(13.0, 13.0), Vector2(rect.position.x + 13.0, rect.end.y - 13.0)]:
		draw_circle(corner, 1.8, Color(0.0, 0.0, 0.0, 0.70))
		draw_circle(corner, 0.9, _with_alpha(GUIDANCE_CENTER_RED, 0.42))

func _draw_cheap_guide_tile(cell: Vector2i, _road_cells: Dictionary) -> void:
	var gs: float = float(level_manager.grid_size)
	var pos: Vector2 = level_manager.grid_origin + Vector2(cell.x * gs, cell.y * gs)
	var rect := Rect2(pos, Vector2(gs, gs))
	var inset := rect.grow(-5.0)
	draw_rect(rect, Color(0.06, 0.03, 0.01, 1.0))
	draw_rect(inset, Color(0.10, 0.06, 0.03, 1.0))
	draw_rect(inset, Color(0.85, 0.28, 0.08, 0.75), false, 1.2)
	# Sparse chevron: only every 6 cells to keep path readable without overdrawing
	var cell_idx: int = _get_guidance_cell_index(cell)
	var exit_dir: Vector2i = _get_guidance_exit_dir(cell)
	if exit_dir != Vector2i.ZERO and (_is_guidance_corner(cell) or (cell_idx >= 0 and cell_idx % 6 == 0)):
		_draw_cheap_chevron(rect, exit_dir)

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
	var guidance := _is_guidance_cell(cell)
	var lane_fill := Color(0.078, 0.082, 0.095, 0.99) if guidance else Color(0.10, 0.11, 0.13, 0.96)
	var lane_shadow := Color(0.0, 0.0, 0.0, 0.56) if guidance else Color(0.0, 0.0, 0.0, 0.46)
	var lane_border := _with_alpha(GUIDANCE_CENTER_RED, 0.74) if guidance else Color(0.20, 0.18, 0.18, 0.55)
	var warm := _with_alpha(GUIDANCE_CENTER_RED, 0.82 if guidance else 0.52)
	var hot := _with_alpha(GUIDANCE_CENTER_AMBER, 0.66 if guidance else 0.44)
	var spec := _with_alpha(Color.WHITE, 0.10 if guidance else 0.05)
	if has_h:
		var h_rect := Rect2(rect.position + Vector2(2.0, rect.size.y * 0.30), Vector2(rect.size.x - 4.0, rect.size.y * 0.40))
		draw_rect(h_rect.grow(2.0), lane_shadow)
		draw_rect(h_rect, lane_fill)
		draw_rect(h_rect, lane_border, false, 1.0)
		draw_line(h_rect.position + Vector2(2.0, 2.0), Vector2(h_rect.end.x - 2.0, h_rect.position.y + 2.0), warm, 1.2)
		draw_line(Vector2(h_rect.position.x + 2.0, h_rect.end.y - 2.0), h_rect.end - Vector2(2.0, 2.0), warm, 1.2)
		draw_line(h_rect.position + Vector2(4.0, h_rect.size.y * 0.5), Vector2(h_rect.end.x - 4.0, h_rect.position.y + h_rect.size.y * 0.5), Color(0.0, 0.0, 0.0, 0.25), 1.0)
		draw_line(h_rect.position + Vector2(6.0, 4.0), Vector2(h_rect.end.x - 10.0, h_rect.position.y + 4.0), spec, 0.8)
		for x in range(int(h_rect.position.x + 10.0), int(h_rect.end.x - 10.0), 14):
			draw_line(Vector2(float(x), h_rect.position.y + 5.0), Vector2(float(x + 4), h_rect.position.y + 5.0), hot, 0.8)
			draw_line(Vector2(float(x), h_rect.end.y - 5.0), Vector2(float(x + 4), h_rect.end.y - 5.0), hot, 0.8)
		if guidance:
			draw_line(h_rect.position + Vector2(10.0, h_rect.size.y * 0.5 - 3.0), Vector2(h_rect.end.x - 10.0, h_rect.position.y + h_rect.size.y * 0.5 - 3.0), Color(0.0, 0.0, 0.0, 0.22), 0.8)
			draw_line(h_rect.position + Vector2(10.0, h_rect.size.y * 0.5 + 3.0), Vector2(h_rect.end.x - 10.0, h_rect.position.y + h_rect.size.y * 0.5 + 3.0), Color(0.0, 0.0, 0.0, 0.22), 0.8)
	if has_v:
		var v_rect := Rect2(rect.position + Vector2(rect.size.x * 0.30, 2.0), Vector2(rect.size.x * 0.40, rect.size.y - 4.0))
		draw_rect(v_rect.grow(2.0), lane_shadow)
		draw_rect(v_rect, lane_fill)
		draw_rect(v_rect, lane_border, false, 1.0)
		draw_line(v_rect.position + Vector2(2.0, 2.0), Vector2(v_rect.position.x + 2.0, v_rect.end.y - 2.0), warm, 1.2)
		draw_line(Vector2(v_rect.end.x - 2.0, v_rect.position.y + 2.0), v_rect.end - Vector2(2.0, 2.0), warm, 1.2)
		draw_line(v_rect.position + Vector2(v_rect.size.x * 0.5, 4.0), Vector2(v_rect.position.x + v_rect.size.x * 0.5, v_rect.end.y - 4.0), Color(0.0, 0.0, 0.0, 0.25), 1.0)
		draw_line(v_rect.position + Vector2(4.0, 6.0), Vector2(v_rect.position.x + 4.0, v_rect.end.y - 10.0), spec, 0.8)
		for y in range(int(v_rect.position.y + 10.0), int(v_rect.end.y - 10.0), 14):
			draw_line(Vector2(v_rect.position.x + 5.0, float(y)), Vector2(v_rect.position.x + 5.0, float(y + 4)), hot, 0.8)
			draw_line(Vector2(v_rect.end.x - 5.0, float(y)), Vector2(v_rect.end.x - 5.0, float(y + 4)), hot, 0.8)
		if guidance:
			draw_line(v_rect.position + Vector2(v_rect.size.x * 0.5 - 3.0, 10.0), Vector2(v_rect.position.x + v_rect.size.x * 0.5 - 3.0, v_rect.end.y - 10.0), Color(0.0, 0.0, 0.0, 0.22), 0.8)
			draw_line(v_rect.position + Vector2(v_rect.size.x * 0.5 + 3.0, 10.0), Vector2(v_rect.position.x + v_rect.size.x * 0.5 + 3.0, v_rect.end.y - 10.0), Color(0.0, 0.0, 0.0, 0.22), 0.8)

func _draw_guidance_lane_wear(cell: Vector2i, rect: Rect2) -> void:
	var dirs: Array[Vector2i] = _get_path_neighbors(cell)
	var center := rect.get_center()
	var gs := rect.size.x
	var scratch := Color(1.0, 1.0, 1.0, 0.038)
	var grime := Color(0.0, 0.0, 0.0, 0.18)
	var spark := _with_alpha(GUIDANCE_CENTER_AMBER, 0.16)
	var has_h := false
	var has_v := false
	for d in dirs:
		if d.x != 0:
			has_h = true
		if d.y != 0:
			has_v = true
	if has_h:
		for i in range(3):
			var x: float = rect.position.x + 14.0 + float((cell.x * 17 + i * 19) % int(max(1.0, gs - 28.0)))
			var y: float = center.y + float([-8.0, 4.0, 10.0][i])
			draw_line(Vector2(x, y), Vector2(min(rect.end.x - 10.0, x + 12.0), y + 1.0), scratch, 0.8)
		for i in range(2):
			var x2: float = rect.position.x + 18.0 + float((cell.x * 23 + i * 15) % int(max(1.0, gs - 36.0)))
			draw_circle(Vector2(x2, center.y + (6.0 if i % 2 == 0 else -6.0)), 1.2, spark)
		draw_line(rect.position + Vector2(12.0, center.y - 13.0), Vector2(rect.end.x - 12.0, center.y - 13.0), grime, 0.8)
		draw_line(rect.position + Vector2(12.0, center.y + 13.0), Vector2(rect.end.x - 12.0, center.y + 13.0), grime, 0.8)
	if has_v:
		for i in range(3):
			var x: float = center.x + float([-8.0, 4.0, 10.0][i])
			var y: float = rect.position.y + 14.0 + float((cell.y * 17 + i * 19) % int(max(1.0, gs - 28.0)))
			draw_line(Vector2(x, y), Vector2(x + 1.0, min(rect.end.y - 10.0, y + 12.0)), scratch, 0.8)
		for i in range(2):
			var y2: float = rect.position.y + 18.0 + float((cell.y * 23 + i * 15) % int(max(1.0, gs - 36.0)))
			draw_circle(Vector2(center.x + (6.0 if i % 2 == 0 else -6.0), y2), 1.2, spark)
		draw_line(rect.position + Vector2(center.x - 13.0 - rect.position.x, 12.0), Vector2(center.x - 13.0, rect.end.y - 12.0), grime, 0.8)
		draw_line(rect.position + Vector2(center.x + 13.0 - rect.position.x, 12.0), Vector2(center.x + 13.0, rect.end.y - 12.0), grime, 0.8)

func _draw_tile_cracks(rect: Rect2, cell: Vector2i) -> void:
	var padding: float = 14.0
	var inner: Rect2 = rect.grow(-padding)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var h: int = cell.x * 7919 + cell.y * 6271
	var num_cracks: int = 2 + abs(h % 4)
	for i in range(num_cracks):
		var hi: int = h + i * 1337
		var t1: float = float(abs(hi * 31) % 100) / 100.0
		var t2: float = float(abs((hi * 47 + 13) % 100)) / 100.0
		var start_pos: Vector2 = Vector2(
			inner.position.x + t1 * inner.size.x,
			inner.position.y + t2 * inner.size.y
		)
		var angle: float = float(abs(hi * 53) % 628) / 100.0
		var length: float = 6.0 + float(abs(hi * 29) % 12)
		var end_pos: Vector2 = Vector2(
			start_pos.x + cos(angle) * length,
			start_pos.y + sin(angle) * length
		)
		end_pos.x = clamp(end_pos.x, inner.position.x, inner.end.x)
		end_pos.y = clamp(end_pos.y, inner.position.y, inner.end.y)
		draw_line(start_pos, end_pos, GUIDE_CRACK_BASE, 1.2)
		draw_line(start_pos, end_pos, GUIDE_CRACK_GLOW, 0.6)

func _draw_embedded_chevron(rect: Rect2, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var direction: Vector2 = Vector2(float(dir.x), float(dir.y)).normalized()
	var perp: Vector2 = Vector2(-direction.y, direction.x)
	var center: Vector2 = rect.get_center()
	var arm_len: float   = rect.size.x * 0.22
	var arm_width: float = rect.size.x * 0.155
	var back: Vector2  = center - direction * arm_len
	var tip: Vector2   = center + direction * arm_len
	var left: Vector2  = back + perp * arm_width
	var right: Vector2 = back - perp * arm_width
	var shadow_off: Vector2 = Vector2(1.2, 1.2)
	draw_line(left + shadow_off,  tip + shadow_off, GUIDE_CHEVRON_SHADOW, 2.8)
	draw_line(right + shadow_off, tip + shadow_off, GUIDE_CHEVRON_SHADOW, 2.8)
	draw_line(left,  tip, _with_alpha(GUIDANCE_CENTER_RED,   0.14), 5.5)
	draw_line(right, tip, _with_alpha(GUIDANCE_CENTER_RED,   0.14), 5.5)
	draw_line(left,  tip, _with_alpha(GUIDANCE_CENTER_RED,   0.82), 1.8)
	draw_line(right, tip, _with_alpha(GUIDANCE_CENTER_RED,   0.82), 1.8)
	draw_line(left.lerp(tip, 0.45),  tip, _with_alpha(GUIDANCE_CENTER_AMBER, 0.52), 0.8)
	draw_line(right.lerp(tip, 0.45), tip, _with_alpha(GUIDANCE_CENTER_AMBER, 0.52), 0.8)

func _draw_cheap_chevron(rect: Rect2, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var direction := Vector2(float(dir.x), float(dir.y)).normalized()
	var perp := Vector2(-direction.y, direction.x)
	var center := rect.get_center()
	var arm_len := rect.size.x * 0.22
	var arm_width := rect.size.x * 0.155
	var back := center - direction * arm_len
	var tip  := center + direction * arm_len
	draw_line(back + perp * arm_width, tip, _with_alpha(GUIDANCE_CENTER_RED, 0.82), 1.8)
	draw_line(back - perp * arm_width, tip, _with_alpha(GUIDANCE_CENTER_RED, 0.82), 1.8)

func _get_guidance_exit_dir(cell: Vector2i) -> Vector2i:
	if level_manager == null or not level_manager.multi_paths.has("default"):
		return Vector2i.ZERO
	var cells: Array = level_manager.multi_paths["default"]
	for i in range(cells.size()):
		if cells[i] is Vector2i and cells[i] == cell:
			if i < cells.size() - 1 and cells[i + 1] is Vector2i:
				var d: Vector2i = cells[i + 1] - cells[i]
				return Vector2i(signi(d.x), signi(d.y))
	return Vector2i.ZERO

func _get_guidance_cell_index(cell: Vector2i) -> int:
	if level_manager == null or not level_manager.multi_paths.has("default"):
		return -1
	var cells: Array = level_manager.multi_paths["default"]
	for i in range(cells.size()):
		if cells[i] is Vector2i and cells[i] == cell:
			return i
	return -1

func _is_guidance_corner(cell: Vector2i) -> bool:
	if level_manager == null or not level_manager.multi_paths.has("default"):
		return false
	var cells: Array = level_manager.multi_paths["default"]
	for i in range(1, cells.size() - 1):
		if not (cells[i] is Vector2i) or cells[i] != cell:
			continue
		if not (cells[i - 1] is Vector2i) or not (cells[i + 1] is Vector2i):
			continue
		var prev_dir: Vector2i = cells[i] - cells[i - 1]
		var next_dir: Vector2i = cells[i + 1] - cells[i]
		prev_dir = Vector2i(signi(prev_dir.x), signi(prev_dir.y))
		next_dir = Vector2i(signi(next_dir.x), signi(next_dir.y))
		return prev_dir != next_dir
	return false

func _draw_neon_edge(a: Vector2, b: Vector2, glow: Color, main: Color, core: Color) -> void:
	draw_line(a, b, glow, 5.0)
	draw_line(a, b, main, 2.2)
	draw_line(a, b, core, 1.0)

func _draw_tile_road_roundabouts(accent: Color) -> void:
	if PERFORMANCE_MODE: return
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
	if PERFORMANCE_MODE: return
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
	if _uses_guidance_lane():
		_draw_guidance_route_flow_arrows()
		return

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

func _draw_guidance_route_flow_arrows() -> void:
	if level_manager == null or not level_manager.multi_paths.has("default"):
		return
	var path_ids: Array[String] = ["default"]
	if preview_alpha > 0.01 and not active_preview_paths.is_empty() and not active_preview_paths.has("default"):
		return
	for path_id in path_ids:
		var points = level_manager.get_path_points_for_id(path_id)
		if points.size() < 2:
			continue
		var start_pos: Vector2 = points[0]
		var end_pos: Vector2 = points[points.size() - 1]
		draw_circle(start_pos, 2.0, _with_alpha(GUIDANCE_CENTER_RED, 0.12))
		draw_circle(end_pos, 2.0, _with_alpha(GUIDANCE_CENTER_AMBER, 0.12))

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
	var cell: Vector2i = _vector2i_from_value(spec["cell"])
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
		elif dv is Array and dv.size() >= 2:
			dir = Vector2(float(dv[0]), float(dv[1])).normalized()
	if dir.length() <= 0.001:
		dir = Vector2.RIGHT
	var offset_t: float = float(spec.get("offset", 0.0))
	var side_t: float = float(spec.get("side_offset", 0.0))
	var perp := Vector2(-dir.y, dir.x)
	var pos: Vector2 = level_manager.cell_to_world_center(cell) + dir * offset_t * float(level_manager.grid_size) + perp * side_t * float(level_manager.grid_size)
	_draw_embedded_lane_chevron(pos, dir, pulse)

func _vector2i_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO

func _draw_embedded_lane_strip(points: Array, force_guidance: bool = false) -> void:
	var guidance := force_guidance or _uses_guidance_lane()
	var shadow: Color = Color(0.0, 0.0, 0.0, 0.62) if guidance else ROUTE_GROOVE_DARK
	var fill: Color = Color(0.105, 0.04, 0.022, 0.94) if guidance else ROUTE_GROOVE_FILL
	var warm_edge: Color = _with_alpha(GUIDANCE_CENTER_RED, 0.36 if guidance else 0.11)
	var hot_core: Color = _with_alpha(GUIDANCE_CENTER_AMBER, 0.29 if guidance else 0.09)
	var spec: Color = _with_alpha(Color.WHITE, 0.09 if guidance else 0.045)

	draw_polyline(points, shadow, 17.0 if guidance else 16.0, true)
	draw_polyline(points, fill, 11.2 if guidance else 11.5, true)
	draw_polyline(points, warm_edge, 4.8 if guidance else 5.0, true)
	draw_polyline(points, hot_core, 1.8 if guidance else 1.6, true)
	draw_polyline(points, spec, 0.85 if guidance else 0.8, true)

func _draw_embedded_lane_chevron(pos: Vector2, dir: Vector2, fade: float = 1.0) -> void:
	var guidance := _uses_guidance_lane()
	var glow_color: Color = _with_alpha(GUIDANCE_CENTER_RED, (0.24 if guidance else 0.18) * fade)
	var hot_color: Color = _with_alpha(GUIDANCE_CENTER_AMBER, (0.70 if guidance else 0.62) * fade)
	var main_color: Color = _with_alpha(GUIDANCE_CENTER_RED, (0.94 if guidance else 0.92) * fade)
	var core_color: Color = _with_alpha(Color.WHITE, (0.22 if guidance else 0.16) * fade)
	var length: float = 20.0 if guidance else ROUTE_CHEVRON_LENGTH
	var half_width: float = 7.5 if guidance else ROUTE_CHEVRON_HALF_WIDTH
	var pair_offset: float = 14.0 if guidance else ROUTE_CHEVRON_PAIR_OFFSET
	var perp: Vector2 = Vector2(-dir.y, dir.x)

	if guidance:
		var triple_spacing: float = 17.0
		for i in range(3):
			var offset_pos: Vector2 = pos + dir * (float(i - 1) * triple_spacing)
			var center: Vector2 = offset_pos
			var back: Vector2 = center - dir * (length * 0.5)
			var tip: Vector2 = center + dir * (length * 0.5)
			var left: Vector2 = back + perp * half_width
			var right: Vector2 = back - perp * half_width
			draw_line(left, tip, glow_color, 6.2)
			draw_line(right, tip, glow_color, 6.2)
			draw_line(left, tip, hot_color, 3.4)
			draw_line(right, tip, hot_color, 3.4)
			draw_line(left, tip, main_color, 1.6)
			draw_line(right, tip, main_color, 1.6)
			draw_line(left.lerp(tip, 0.66), tip, core_color, 0.8)
			draw_line(right.lerp(tip, 0.66), tip, core_color, 0.8)
		return

	for offset in [-pair_offset * 0.5, pair_offset * 0.5]:
		var center: Vector2 = pos + dir * offset
		var back: Vector2 = center - dir * (length * 0.5)
		var tip: Vector2 = center + dir * (length * 0.5)
		var left: Vector2 = back + perp * half_width
		var right: Vector2 = back - perp * half_width
		draw_line(left, tip, glow_color, 6.2)
		draw_line(right, tip, glow_color, 6.2)
		draw_line(left, tip, hot_color, 3.4)
		draw_line(right, tip, hot_color, 3.4)
		draw_line(left, tip, main_color, 1.6)
		draw_line(right, tip, main_color, 1.6)
		draw_line(left.lerp(tip, 0.66), tip, core_color, 0.8)
		draw_line(right.lerp(tip, 0.66), tip, core_color, 0.8)

func _should_show_tile_route_arrow() -> bool:
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
		var label = _lane_marker_label(str(p_id))
		var active_spawn = active_preview_paths.has(str(p_id)) and preview_alpha > 0.01
		var portal_radius := gs * (0.55 if str(p_id) == "default" else 0.40)
		_draw_spawn_portal(spawn_pos, portal_radius, current_theme.color_spawn, active_spawn)
		var label_color = current_theme.color_spawn
		label_color.a = 1.0 if active_spawn else 0.62
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

	_draw_path_portal_markers(font, font_size, gs)

func _lane_marker_label(path_id: String) -> String:
	if path_id == "default":
		return "A"
	if path_id == "lane_b":
		return "B"
	if path_id == "lane_c":
		return "C"
	return path_id.substr(0, min(3, path_id.length())).to_upper()

func _draw_path_portal_markers(font: Font, font_size: int, gs: int) -> void:
	var portals = level_manager.level_data.get("path_portals", [])
	if not (portals is Array):
		return
	for portal in portals:
		if not (portal is Dictionary):
			continue
		var path_id := str(portal.get("path", "default"))
		if not level_manager.multi_paths.has(path_id):
			continue
		var cells: Array = level_manager.multi_paths[path_id]
		var entry_index := int(portal.get("entry_index", -1))
		var exit_index := int(portal.get("exit_index", -1))
		if entry_index < 0 or exit_index < 0 or entry_index >= cells.size() or exit_index >= cells.size():
			continue
		var entry_pos: Vector2 = level_manager.cell_to_world_center(cells[entry_index])
		var exit_pos: Vector2 = level_manager.cell_to_world_center(cells[exit_index])
		var color := Color(0.62, 0.86, 1.0, 0.92)
		draw_line(entry_pos, exit_pos, Color(color.r, color.g, color.b, 0.18), 3.0)
		_draw_phase_gate_marker(entry_pos, gs * 0.30, color)
		_draw_phase_gate_marker(exit_pos, gs * 0.30, Color(1.0, 0.70, 0.30, 0.92))
		draw_string(font, entry_pos + Vector2(-16, -gs * 0.48), "GATE", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size - 2, color)

func _draw_phase_gate_marker(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius * 1.55, Color(color.r, color.g, color.b, 0.08))
	draw_arc(pos, radius, 0.0, TAU, 24, color, 2.0)
	draw_arc(pos, radius * 0.62, PI * 0.15, PI * 1.45, 18, Color(1.0, 1.0, 1.0, 0.55), 1.2)
	draw_circle(pos, radius * 0.22, Color(color.r, color.g, color.b, 0.82))

func _draw_spawn_portal(pos: Vector2, radius: float, color: Color, active: bool = false) -> void:
	var time = preview_timer * 2.0
	var active_boost = preview_alpha if active else 0.0
	var ring_color = color
	ring_color.a = lerp(0.45, 0.95, active_boost)
	
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
	draw_polyline(PackedVector2Array([back + perp * 10.0, tip, back - perp * 10.0]), _with_alpha(color, color.a * 0.2), 6.0, true)
	# Main line
	draw_polyline(PackedVector2Array([back + perp * 8.0, tip, back - perp * 8.0]), color, 3.5, true)
	# High contrast center
	draw_polyline(PackedVector2Array([back + perp * 8.0, tip, back - perp * 8.0]), _with_alpha(Color.WHITE, color.a * 0.6), 1.0, true)

func _preview_has_base_at(base_pos: Vector2) -> bool:
	if preview_alpha <= 0.01:
		return false
	for p_id in active_preview_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() > 0 and points[points.size() - 1].distance_to(base_pos) < 5.0:
			return true
	return false

func _draw_normal_build_tile(rect: Rect2, cell: Vector2i) -> void:
	if PERFORMANCE_MODE:
		draw_rect(rect, Color(0.038, 0.050, 0.068, 1.0))
		draw_rect(rect.grow(-6.0), Color(0.025, 0.032, 0.046, 1.0))
		draw_rect(rect.grow(-6.0), _with_alpha(PATH_EDGE_CYAN, 0.35), false, 1.0)
		return
	draw_rect(rect.grow(1.5), Color(0.0, 0.0, 0.0, 0.18))
	draw_rect(rect, Color(0.038, 0.050, 0.068, 1.0))
	var frame: Rect2 = rect.grow(-3.0)
	draw_rect(frame, Color(0.052, 0.068, 0.092, 1.0))
	var inner: Rect2 = rect.grow(-8.0)
	draw_rect(inner, Color(0.025, 0.032, 0.046, 1.0))
	draw_line(frame.position, Vector2(frame.end.x, frame.position.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.38), 1.5)
	draw_line(frame.position, Vector2(frame.position.x, frame.end.y), _with_alpha(PATH_METAL_HIGHLIGHT, 0.28), 1.5)
	draw_line(Vector2(frame.position.x, frame.end.y), frame.end, Color(0.0, 0.0, 0.0, 0.34), 1.5)
	draw_line(Vector2(frame.end.x, frame.position.y), frame.end, Color(0.0, 0.0, 0.0, 0.44), 1.5)
	var cx: float = rect.position.x + rect.size.x * 0.5
	var cy: float = rect.position.y + rect.size.y * 0.5
	draw_line(Vector2(rect.position.x + 12.0, cy), Vector2(rect.end.x - 12.0, cy), Color(0.0, 0.0, 0.0, 0.22), 0.8)
	draw_line(Vector2(cx, rect.position.y + 12.0), Vector2(cx, rect.end.y - 12.0), Color(0.0, 0.0, 0.0, 0.22), 0.8)
	var sheen_rect: Rect2 = Rect2(inner.position + Vector2(2.0, 2.0), Vector2(inner.size.x - 4.0, max(6.0, inner.size.y * 0.18)))
	draw_rect(sheen_rect, Color(1.0, 1.0, 1.0, 0.018))
	_draw_tile_surface_details(rect, cell)
	draw_rect(frame, _with_alpha(PATH_EDGE_CYAN, 0.30), false, 1.0)
	draw_rect(inner, _with_alpha(PATH_EDGE_BLUE, 0.16), false, 0.8)
	_draw_tile_corner_accents(rect)

func _draw_tile_surface_details(rect: Rect2, cell: Vector2i) -> void:
	var padding: float = 12.0
	var inner: Rect2 = rect.grow(-padding)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var h: int = cell.x * 7919 + cell.y * 6271
	var num_lines: int = abs(h % 3)
	var trace_color: Color = _with_alpha(PATH_EDGE_CYAN, 0.025)
	for i in range(num_lines):
		var hi: int = h + i * 2137
		var horizontal: bool = (abs(hi * 17) % 2) == 0
		var t: float = float(abs(hi * 43) % 100) / 100.0
		if horizontal:
			var py: float = inner.position.y + t * inner.size.y
			var x0: float = inner.position.x + float(abs(hi * 11) % 20)
			var x1: float = inner.end.x - float(abs(hi * 13) % 20)
			if x1 > x0:
				draw_line(Vector2(x0, py), Vector2(x1, py), trace_color, 0.7)
		else:
			var px: float = inner.position.x + t * inner.size.x
			var y0: float = inner.position.y + float(abs(hi * 11) % 20)
			var y1: float = inner.end.y - float(abs(hi * 13) % 20)
			if y1 > y0:
				draw_line(Vector2(px, y0), Vector2(px, y1), trace_color, 0.7)
	if (abs(h * 31) % 4) == 0:
		var dot_x: float = inner.position.x + float(abs(h * 61) % 100) / 100.0 * inner.size.x
		var dot_y: float = inner.position.y + float(abs(h * 73) % 100) / 100.0 * inner.size.y
		draw_circle(Vector2(dot_x, dot_y), 0.8, _with_alpha(PATH_EDGE_CYAN, 0.06))

func _draw_tile_corner_accents(rect: Rect2) -> void:
	var inset: float = 11.0
	var corners: Array[Vector2] = [
		rect.position + Vector2(inset, inset),
		Vector2(rect.end.x - inset, rect.position.y + inset),
		rect.end - Vector2(inset, inset),
		Vector2(rect.position.x + inset, rect.end.y - inset)
	]
	for corner in corners:
		draw_circle(corner, 1.5, Color(0.0, 0.0, 0.0, 0.60))
		draw_circle(corner, 0.8, _with_alpha(PATH_EDGE_CYAN, 0.26))

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clamp(alpha, 0.0, 1.0))

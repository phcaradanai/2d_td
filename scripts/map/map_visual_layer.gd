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
const PATH_EDGE_CYAN := Color(0.0, 0.82, 1.0, 1.0)
const PATH_EDGE_BLUE := Color(0.12, 0.42, 1.0, 1.0)
const PATH_INNER_AMBER := Color(1.0, 0.55, 0.08, 1.0)
const PATH_METAL_DARK := Color(0.015, 0.025, 0.04, 1.0)
const PATH_METAL_MID := Color(0.045, 0.07, 0.095, 1.0)

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
	if preview_alpha > 0.001 or not active_preview_paths.is_empty():
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
	
	for x in range(cols):
		for y in range(rows):
			var cell = Vector2i(x, y)
			
			# Don't place on path or buildable foundations (to keep them clear)
			if level_manager.is_path_cell(cell): continue
			if not level_manager.buildable_cells.is_empty() and cell in level_manager.buildable_cells: continue
			
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
	
	# 1. Base Ground (BG)
	draw_rect(Rect2(origin, Vector2(cols * gs, rows * gs)), current_theme.color_bg)
	
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
			
			if not level_manager.buildable_cells.is_empty() and cell in level_manager.buildable_cells:
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
	
	# Clean Sci-Fi Plate
	draw_rect(rect, color)
	draw_rect(rect.grow(-2), border, false, 1.0)
	
	# Corner Accents (Small Cyan L-shapes)
	var s = 6.0
	var p = rect.position + Vector2(4, 4)
	var e = rect.end - Vector2(4, 4)
	var acc = Color.CYAN * 0.5
	
	draw_polyline([p + Vector2(s, 0), p, p + Vector2(0, s)], acc, 1.5)
	draw_polyline([e - Vector2(s, 0), e, e - Vector2(0, s)], acc, 1.5)
	
	# Subtle Center Grid
	var g_color = Color(1, 1, 1, 0.02)
	draw_line(Vector2(rect.position.x + rect.size.x/2, rect.position.y + 4), Vector2(rect.position.x + rect.size.x/2, rect.end.y - 4), g_color)
	draw_line(Vector2(rect.position.x + 4, rect.position.y + rect.size.y/2), Vector2(rect.end.x - 4, rect.position.y + rect.size.y/2), g_color)

func _draw_blocked_tile(rect: Rect2) -> void:
	var color = current_theme.color_blocked
	draw_rect(rect, color)
	
	# Pattern
	var steps = 3
	var p_color = Color(1, 1, 1, 0.05)
	for i in range(steps + 1):
		var offset = (rect.size.x / steps) * i
		draw_line(rect.position + Vector2(offset, 0), rect.position + Vector2(0, offset), p_color)
		draw_line(rect.position + Vector2(rect.size.x, offset), rect.position + Vector2(offset, rect.size.y), p_color)

func _draw_all_paths_base() -> void:
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

func _draw_path_overlays() -> void:
	if not show_path_overlays: return
	
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		draw_polyline(points, _with_alpha(PATH_EDGE_CYAN, 0.12), current_theme.path_glow_width, true)
		draw_polyline(points, _with_alpha(PATH_EDGE_CYAN, 0.42), 2.0, true)
		draw_polyline(points, _with_alpha(PATH_INNER_AMBER, 0.22), 1.0, true)
		
	if preview_alpha > 0.01:
		_draw_preview_pulses()

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
				var edge_fade = min(d, dist - d) / 20.0
				var a_color = _with_alpha(PATH_EDGE_CYAN, 0.74 * preview_alpha * clamp(edge_fade, 0.0, 1.0))
				
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
		var label = "A" if str(p_id) == "default" else str(p_id).capitalize().replace("Lane_", "")
		var active_spawn = active_preview_paths.has(str(p_id)) and preview_alpha > 0.01
		_draw_spawn_portal(spawn_pos, gs * 0.55, current_theme.color_spawn, active_spawn)
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
	draw_arc(pos, radius * 1.1, 0, TAU, 32, Color(0.2, 0.2, 0.2), 4.0)
	draw_arc(pos, radius * 1.1, 0, TAU, 32, ring_color, 1.5 + active_boost)
	if active:
		draw_arc(pos, radius * (1.25 + sin(time * 3.0) * 0.08), 0, TAU, 32, active_cyan, 3.0)
	
	# Rotating Emitters
	for i in range(4):
		var ang = time + (i * TAU / 4)
		var e_pos = pos + Vector2(cos(ang), sin(ang)) * radius
		draw_circle(e_pos, 4, Color.BLACK)
		draw_circle(e_pos, 3, ring_color)
		draw_circle(e_pos, 1.5, Color.WHITE)
		
		# Beam to center
		draw_line(e_pos, pos, Color(color.r, color.g, color.b, 0.18 + active_boost * 0.18), 1.0)
	
	# Center Warp Effect (Geometric)
	var pts = PackedVector2Array()
	var sides = 6
	var rot = -time * 0.5
	for i in range(sides):
		var a = rot + (i * TAU / sides)
		pts.append(pos + Vector2(cos(a), sin(a)) * radius * 0.6)
	
	draw_colored_polygon(pts, Color(0, 0, 0, 0.9))
	draw_polyline(pts + PackedVector2Array([pts[0]]), ring_color, 2.0)
	
	# Pulse
	var pulse = (sin(time * 3.0) + 1.0) * 0.5
	draw_circle(pos, radius * (0.3 + active_boost * 0.12) * pulse, Color(color.r, color.g, color.b, 0.45 + active_boost * 0.25))

func _draw_energy_core(pos: Vector2, radius: float, color: Color, active: bool = false) -> void:
	var time = preview_timer
	var active_boost = preview_alpha if active else 0.0
	
	# Hexagonal Containment
	var base_pts = PackedVector2Array()
	for i in range(6):
		var a = (i * TAU / 6)
		base_pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	
	draw_colored_polygon(base_pts, Color(0.1, 0.1, 0.15, 0.8))
	draw_polyline(base_pts + PackedVector2Array([base_pts[0]]), _with_alpha(PATH_EDGE_CYAN, 0.30 + active_boost * 0.25), 2.0)
	
	# Inner Spinning Core
	var core_pts = PackedVector2Array()
	var rot = time * 2.0
	for i in range(3):
		var a = rot + (i * TAU / 3)
		core_pts.append(pos + Vector2(cos(a), sin(a)) * radius * 0.7)
	
	draw_colored_polygon(core_pts, color)
	draw_polyline(core_pts + PackedVector2Array([core_pts[0]]), Color.WHITE, 2.0)
	
	# Pulsing Glow
	var pulse = (sin(time * 5.0) + 1.0) * 0.5
	draw_circle(pos, radius * 0.3, Color.WHITE)
	draw_arc(pos, radius * (0.4 + pulse * (0.2 + active_boost * 0.18)), 0, TAU, 24, Color(color.r, color.g, color.b, 0.4 + active_boost * 0.25), 1.5 + active_boost)
	
	# Orbiting Nodes
	for i in range(3):
		var ang = -time * 1.5 + (i * TAU / 3)
		var n_pos = pos + Vector2(cos(ang), sin(ang)) * radius * 1.2
		draw_circle(n_pos, 3, color)
		draw_circle(n_pos, 1.5, Color.WHITE)

func _draw_chevron(pos: Vector2, dir: Vector2, color: Color) -> void:
	var perp = Vector2(-dir.y, dir.x)
	var tip = pos + dir * 13.0
	var back = pos - dir * 8.0
	draw_line(back + perp * 8.0, tip, color, 3.0, true)
	draw_line(back - perp * 8.0, tip, color, 3.0, true)
	draw_line(back + perp * 8.0, tip, _with_alpha(Color.WHITE, color.a * 0.45), 1.0, true)
	draw_line(back - perp * 8.0, tip, _with_alpha(Color.WHITE, color.a * 0.45), 1.0, true)

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

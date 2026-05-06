extends Node2D

# Map Visual Layer
# Responsible for rendering the environment based on AreaTheme.

var level_manager: Node = null
var current_theme: Resource = null
var prop_container: Node2D = null

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
	draw_rect(rect.grow(-2), color)
	draw_rect(rect.grow(-2), border, false, 2.0)
	
	# Corner accents
	var s = 6.0
	var p = 4.0
	draw_line(rect.position + Vector2(p, p), rect.position + Vector2(p + s, p), Color.WHITE * 0.2)
	draw_line(rect.position + Vector2(p, p), rect.position + Vector2(p, p + s), Color.WHITE * 0.2)

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
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		# Draw thick background for the path
		draw_polyline(points, current_theme.color_path, level_manager.grid_size * 0.75, true)

func _draw_path_overlays() -> void:
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.size() < 2: continue
		
		# Glowing spine
		draw_polyline(points, current_theme.color_path_glow, current_theme.path_glow_width, true)
		draw_polyline(points, current_theme.color_path_line, 2.0, true)

func _draw_markers(gs: int) -> void:
	var font = Control.new().get_theme_font("font")
	var font_size = 14
	var drawn_base_positions = []
	
	for p_id in level_manager.multi_paths:
		var points = level_manager.get_path_points_for_id(p_id)
		if points.is_empty(): continue
		
		var spawn_pos = points[0]
		var label = "A" if str(p_id) == "default" else str(p_id).capitalize().replace("Lane_", "")
		_draw_portal(spawn_pos, gs * 0.35, current_theme.color_spawn)
		draw_string(font, spawn_pos + Vector2(-8, -gs * 0.5), label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, current_theme.color_spawn)
		
		var base_pos = points[points.size() - 1]
		var is_duplicate = false
		for pos in drawn_base_positions:
			if pos.distance_to(base_pos) < 5.0:
				is_duplicate = true
				break
		
		if not is_duplicate:
			_draw_portal(base_pos, gs * 0.4, current_theme.color_base)
			draw_string(font, base_pos + Vector2(-15, gs * 0.6), "CORE", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, current_theme.color_base)
			drawn_base_positions.append(base_pos)

func _draw_portal(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius * 1.2, Color(color.r, color.g, color.b, 0.1))
	draw_arc(pos, radius, 0, TAU, 32, color, 3.0)
	draw_circle(pos, radius * 0.4, Color(color.r, color.g, color.b, 0.2))
	var s = radius * 0.5
	for i in range(4):
		var ang = i * PI/2 + PI/4
		var corner = pos + Vector2(cos(ang), sin(ang)) * radius * 1.4
		draw_arc(corner, radius * 0.3, ang + PI, ang + PI + PI/2, 8, color, 1.5)

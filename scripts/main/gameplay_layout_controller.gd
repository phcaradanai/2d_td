extends RefCounted
class_name GameplayLayoutController

var main = null

func _init(owner: Node = null) -> void:
	main = owner

func update_world_layout() -> void:
	if not is_instance_valid(main.world_root): return

	var view_size = main.get_viewport().get_visible_rect().size

	# 1. Compute playfield rect
	var playfield_rect = Rect2()
	if main.game_hud and main.game_hud.has_method("get_playfield_rect"):
		playfield_rect = main.game_hud.get_playfield_rect()
		# No outer margin for maximal expansion
	else:
		# Fallback to old constants if HUD not ready
		var playfield_x = main.LEFT_SIDEBAR_WIDTH + main.OUTER_MARGIN
		var playfield_y = main.TOP_BAR_HEIGHT + main.OUTER_MARGIN
		var playfield_w = view_size.x - main.LEFT_SIDEBAR_WIDTH - main.RIGHT_SIDEBAR_WIDTH - (main.OUTER_MARGIN * 2)
		var playfield_h = view_size.y - main.TOP_BAR_HEIGHT - (main.OUTER_MARGIN * 2)
		playfield_rect = Rect2(playfield_x, playfield_y, playfield_w, playfield_h)

	# 2. Fit Map inside playfield
	if main.level_manager and main.level_manager.level_id != "" and main.map_root:
		fit_map_to_playfield(playfield_rect)
	
	if main.background:
		main.background.color = Color.BLACK
		# Ensure background covers at least the playfield area in screen space
		# Since we use camera, we'll just make it very large for now
		main.background.size = Vector2(8000, 8000)
		main.background.position = Vector2(-4000, -4000)

func fit_map_to_playfield(playfield_rect: Rect2) -> void:
	if not main.level_manager or not main.map_root or not main.camera: return

	# 1. Calculate map content bounds in world space
	var content_bounds = get_map_content_bounds()
	if content_bounds.size == Vector2.ZERO: return
	
	# Add padding
	var padding = 40.0
	content_bounds = content_bounds.grow(padding)
	
	# 2. Calculate scale to fit bounds into playfield
	var scale_x = playfield_rect.size.x / content_bounds.size.x
	var scale_y = playfield_rect.size.y / content_bounds.size.y
	var fit_zoom = min(scale_x, scale_y)
	
	# Maximize scale (allow up to 5x for small maps on large screens)
	fit_zoom = clamp(fit_zoom, 0.4, 5.0)
	
	# 3. Apply to camera
	main.camera.zoom = Vector2.ONE * fit_zoom
	
	var content_center = content_bounds.get_center()
	var camera_pos = content_center - (playfield_rect.get_center() / fit_zoom)
	main.camera.position = camera_pos
	
	if OS.is_debug_build():
		var window_size = main.get_viewport().get_visible_rect().size
		var unused_x = playfield_rect.size.x - (content_bounds.size.x * fit_zoom)
		var unused_y = playfield_rect.size.y - (content_bounds.size.y * fit_zoom)
		print("[LAYOUT_DEBUG] window_size=", window_size)
		print("[LAYOUT_DEBUG] center_frame_rect=", playfield_rect)
		print("[LAYOUT_DEBUG] content_bounds=", content_bounds)
		print("[LAYOUT_DEBUG] camera_zoom=", fit_zoom)
		print("[LAYOUT_DEBUG] camera_position=", camera_pos)
		print("[LAYOUT_DEBUG] unused_px_h=", unused_x, " unused_px_v=", unused_y)

	# Reset map_root transform (we use camera now)
	main.map_root.scale = Vector2.ONE
	main.map_root.position = Vector2.ZERO
	main.world_root.position = Vector2.ZERO

func get_map_content_bounds() -> Rect2:
	if not main.level_manager:
		return Rect2()

	var gs = main.level_manager.grid_size
	var map_w = main.level_manager.grid_cols * gs
	var map_h = main.level_manager.grid_rows * gs
	var fit_mode := str(main.level_manager.level_data.get("camera_fit_mode", ""))

	# Optional road-focused framing for polished small maps.
	if fit_mode == "road_focus":
		var focus_cells: Array[Vector2i] = []
		for p_id in main.level_manager.multi_paths:
			for cell in main.level_manager.multi_paths[p_id]:
				if cell is Vector2i and not focus_cells.has(cell):
					focus_cells.append(cell)
		for cell in cells_from_level_arrays(main.level_manager.level_data.get("spawn_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		for cell in cells_from_level_arrays(main.level_manager.level_data.get("base_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		if main.level_manager.spawn_cell != Vector2i.ZERO and not focus_cells.has(main.level_manager.spawn_cell):
			focus_cells.append(main.level_manager.spawn_cell)
		if main.level_manager.base_cell != Vector2i.ZERO and not focus_cells.has(main.level_manager.base_cell):
			focus_cells.append(main.level_manager.base_cell)

		if not focus_cells.is_empty():
			var min_cell: Vector2i = focus_cells[0]
			var max_cell: Vector2i = focus_cells[0]
			for cell in focus_cells:
				min_cell.x = min(min_cell.x, cell.x)
				min_cell.y = min(min_cell.y, cell.y)
				max_cell.x = max(max_cell.x, cell.x)
				max_cell.y = max(max_cell.y, cell.y)

			var bounds := Rect2(
				Vector2(min_cell.x * gs, min_cell.y * gs),
				Vector2((max_cell.x - min_cell.x + 1) * gs, (max_cell.y - min_cell.y + 1) * gs)
			)
			var margin_x := float(main.level_manager.level_data.get("camera_focus_margin_cells_x", 2.0)) * float(gs)
			var margin_y := float(main.level_manager.level_data.get("camera_focus_margin_cells_y", 1.5)) * float(gs)
			bounds = bounds.grow_side(SIDE_LEFT, margin_x)
			bounds = bounds.grow_side(SIDE_RIGHT, margin_x)
			bounds = bounds.grow_side(SIDE_TOP, margin_y)
			bounds = bounds.grow_side(SIDE_BOTTOM, margin_y)
			return bounds

	var points: Array[Vector2] = []

	# Default full-grid framing.
	points.append(Vector2.ZERO)
	points.append(Vector2(map_w, map_h))

	if main.level_manager.spawn_cell != Vector2i.ZERO:
		points.append(Vector2(main.level_manager.spawn_cell) * gs + Vector2(gs, gs) * 0.5)
	if main.level_manager.base_cell != Vector2i.ZERO:
		points.append(Vector2(main.level_manager.base_cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in main.level_manager.path_cells:
		points.append(Vector2(cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in main.level_manager.buildable_cells:
		points.append(Vector2(cell) * gs + Vector2(gs, gs) * 0.5)

	if points.is_empty():
		return Rect2(0, 0, map_w, map_h)

	var min_p = points[0]
	var max_p = points[0]
	for p in points:
		min_p.x = min(min_p.x, p.x)
		min_p.y = min(min_p.y, p.y)
		max_p.x = max(max_p.x, p.x)
		max_p.y = max(max_p.y, p.y)

	var bounds = Rect2(min_p, max_p - min_p)
	bounds = bounds.grow_side(SIDE_LEFT, 64)
	bounds = bounds.grow_side(SIDE_RIGHT, 48)
	bounds = bounds.grow_side(SIDE_TOP, 48)
	bounds = bounds.grow_side(SIDE_BOTTOM, 48)
	return bounds

func cells_from_level_arrays(raw: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not (raw is Array):
		return out
	for item in raw:
		if item is Array and item.size() >= 2:
			out.append(Vector2i(int(item[0]), int(item[1])))
	return out

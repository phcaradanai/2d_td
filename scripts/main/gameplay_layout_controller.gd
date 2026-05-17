extends RefCounted
class_name GameplayLayoutController

var world_root: Node2D = null
var map_root: Node2D = null
var camera: Camera2D = null
var background: ColorRect = null
var game_hud: Node = null
var level_manager: Node = null
var top_bar_height: float = 0.0
var left_sidebar_width: float = 0.0
var right_sidebar_width: float = 0.0
var outer_margin: float = 0.0
var get_view_size: Callable

func bind(deps: Dictionary) -> void:
	world_root = deps.get("world_root") as Node2D
	map_root = deps.get("map_root") as Node2D
	camera = deps.get("camera") as Camera2D
	background = deps.get("background") as ColorRect
	game_hud = deps.get("game_hud") as Node
	level_manager = deps.get("level_manager") as Node
	top_bar_height = float(deps.get("top_bar_height", 0.0))
	left_sidebar_width = float(deps.get("left_sidebar_width", 0.0))
	right_sidebar_width = float(deps.get("right_sidebar_width", 0.0))
	outer_margin = float(deps.get("outer_margin", 0.0))
	get_view_size = deps.get("get_view_size", Callable())

func update_world_layout() -> void:
	if not is_instance_valid(world_root):
		return

	var view_size := Vector2.ZERO
	if get_view_size.is_valid():
		view_size = get_view_size.call()

	# 1. Compute playfield rect
	var playfield_rect = Rect2()
	if game_hud and game_hud.has_method("get_playfield_rect"):
		playfield_rect = game_hud.get_playfield_rect()
		# No outer margin for maximal expansion
	else:
		# Fallback to old constants if HUD not ready
		var playfield_x = left_sidebar_width + outer_margin
		var playfield_y = top_bar_height + outer_margin
		var playfield_w = view_size.x - left_sidebar_width - right_sidebar_width - (outer_margin * 2)
		var playfield_h = view_size.y - top_bar_height - (outer_margin * 2)
		playfield_rect = Rect2(playfield_x, playfield_y, playfield_w, playfield_h)

	# 2. Fit Map inside playfield
	if level_manager and level_manager.level_id != "" and map_root:
		fit_map_to_playfield(playfield_rect)
	
	if background:
		background.color = Color.BLACK
		# Ensure background covers at least the playfield area in screen space
		# Since we use camera, we'll just make it very large for now
		background.size = Vector2(8000, 8000)
		background.position = Vector2(-4000, -4000)

const MAP_FILL_ZOOM_BIAS := 1.05
const MAP_MAX_ZOOM := 5.0
const MAP_MIN_ZOOM := 0.4
func fit_map_to_playfield(playfield_rect: Rect2) -> void:

	if not level_manager or not map_root or not camera:
		return
	# 1. Calculate map content bounds in world space
	var content_bounds = get_map_content_bounds()
	if content_bounds.size == Vector2.ZERO:
		return
	
	# get_map_content_bounds() already adds per-side margins; no extra grow needed.
	
	# 2. Calculate scale to fit bounds into playfield
	var scale_x = playfield_rect.size.x / content_bounds.size.x
	var scale_y = playfield_rect.size.y / content_bounds.size.y
	# Fit-inside zoom.
	var fit_zoom = min(scale_x, scale_y)
	# 3. Add a controlled visual fill bias.
	# This zooms the map in a little more after normal fitting.
	# Increase to 1.12–1.18 if you still see too much empty space.
	fit_zoom *= MAP_FILL_ZOOM_BIAS
	# Maximize scale safely.
	fit_zoom = clamp(fit_zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)
	
	# 4. Apply to camera
	camera.zoom = Vector2.ONE * fit_zoom
	
	var content_center = content_bounds.get_center()
	var camera_pos = content_center - (playfield_rect.get_center() / fit_zoom)
	camera.position = camera_pos
	
	# Reset map_root transform (we use camera now)
	map_root.scale = Vector2.ONE
	map_root.position = Vector2.ZERO
	world_root.position = Vector2.ZERO

func get_map_content_bounds() -> Rect2:
	if not level_manager:
		return Rect2()

	var gs = level_manager.grid_size
	var map_w = level_manager.grid_cols * gs
	var map_h = level_manager.grid_rows * gs
	var fit_mode := str(level_manager.level_data.get("camera_fit_mode", ""))

	# Optional road-focused framing for polished small maps.
	if fit_mode == "road_focus":
		var focus_cells: Array[Vector2i] = []
		for p_id in level_manager.multi_paths:
			for cell in level_manager.multi_paths[p_id]:
				if cell is Vector2i and not focus_cells.has(cell):
					focus_cells.append(cell)
		for cell in cells_from_level_arrays(level_manager.level_data.get("spawn_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		for cell in cells_from_level_arrays(level_manager.level_data.get("base_cells", [])):
			if not focus_cells.has(cell):
				focus_cells.append(cell)
		if level_manager.spawn_cell != Vector2i.ZERO and not focus_cells.has(level_manager.spawn_cell):
			focus_cells.append(level_manager.spawn_cell)
		if level_manager.base_cell != Vector2i.ZERO and not focus_cells.has(level_manager.base_cell):
			focus_cells.append(level_manager.base_cell)

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
			var margin_x := float(level_manager.level_data.get("camera_focus_margin_cells_x", 2.0)) * float(gs)
			var margin_y := float(level_manager.level_data.get("camera_focus_margin_cells_y", 1.5)) * float(gs)
			bounds = bounds.grow_side(SIDE_LEFT, margin_x)
			bounds = bounds.grow_side(SIDE_RIGHT, margin_x)
			bounds = bounds.grow_side(SIDE_TOP, margin_y)
			bounds = bounds.grow_side(SIDE_BOTTOM, margin_y)
			return bounds

	var points: Array[Vector2] = []

	# Default full-grid framing.
	points.append(Vector2.ZERO)
	points.append(Vector2(map_w, map_h))

	if level_manager.spawn_cell != Vector2i.ZERO:
		points.append(Vector2(level_manager.spawn_cell) * gs + Vector2(gs, gs) * 0.5)
	if level_manager.base_cell != Vector2i.ZERO:
		points.append(Vector2(level_manager.base_cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in level_manager.path_cells:
		points.append(Vector2(cell) * gs + Vector2(gs, gs) * 0.5)

	for cell in level_manager.buildable_cells:
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

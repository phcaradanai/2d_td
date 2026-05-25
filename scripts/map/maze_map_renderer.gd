extends Node2D
class_name MazeMapRenderer

## Lightweight maze/Element-TD map renderer.
## Draws a readable fixed-path road that matches the actual enemy path cells.
## No per-frame processing — redraws on demand only.

# ------------------------------------------------------------------ colors
# These are vars (not consts) so _apply_theme_for_level() can override them.
var BG_COLOR             := Color(0.055, 0.065, 0.095, 1.0)
var GRID_COLOR           := Color(0.12, 0.14, 0.18, 0.28)
var BUILDABLE_TINT       := Color(0.08, 0.105, 0.135, 1.0)
var BOARD_HALO           := Color(0.05, 0.28, 0.38, 0.12)
var BOARD_BACKING        := Color(0.012, 0.025, 0.040, 0.82)
var BOARD_FRAME          := Color(0.12, 0.54, 0.72, 0.34)
var ROAD_PANEL           := Color(0.105, 0.125, 0.155, 1.0)
var ROAD_PANEL_ALT       := Color(0.075, 0.095, 0.125, 1.0)
var ROAD_EDGE_DARK       := Color(0.015, 0.02, 0.03, 0.95)
var ROAD_EDGE_CYAN       := Color(0.12, 0.66, 0.90, 0.48)
var ROAD_CENTER_GLOW     := Color(0.12, 0.78, 1.0, 0.18)
var ROAD_CENTER_LINE     := Color(0.56, 0.92, 1.0, 0.32)
var ROAD_CORNER_GLOW     := Color(0.2, 0.95, 1.0, 0.12)
var SPAWN_COLOR          := Color(1.0,  0.22, 0.12, 0.95)
var CORE_COLOR           := Color(0.3,  0.95, 0.45, 0.95)
var GUIDELINE_COLOR      := Color(1.0, 0.58, 0.18, 0.56)
var GUIDELINE_SHADOW     := Color(0.0, 0.0, 0.0, 0.36)
var PATH_DOT_COLOR       := Color(0.16, 0.88, 1.0, 0.38)

# ------------------------------------------------------------------ state
var _grid_origin: Vector2 = Vector2.ZERO
var _grid_size:   float   = 64.0
var _grid_cols:   int     = 10
var _grid_rows:   int     = 10

var _spawn_cells:     Array[Vector2i] = []
var _base_cells:      Array[Vector2i] = []
var _road_cells:      Array[Vector2i] = []
var _guideline_cells: Array[Vector2i] = []
var _draw_guideline:  bool = false

var _baked_sprite: Sprite2D = null
var _level_num: int = 0  # 1-20, used for per-level accent shift
var _ground_lanes: Array = []  # Array of Array[Vector2i], one per ground lane (air excluded)
var _portal_entries: Array[Vector2i] = []  # cells where path teleports FROM
var _portal_exits:   Array[Vector2i] = []  # cells where path teleports TO


# ================================================================== setup
func _ready() -> void:
	set_process(false)


func setup(p_level_manager: Node) -> void:
	# Clean up baked sprite from any previous level before re-baking
	if _baked_sprite != null and is_instance_valid(_baked_sprite):
		_baked_sprite.queue_free()
		_baked_sprite = null
	visible = true

	# --- parse level number for per-level accent shift ---
	var level_id: String = p_level_manager.get("level_id") if p_level_manager.get("level_id") != null else ""
	_level_num = _parse_level_num(level_id)

	# --- apply area theme + per-level shift ---
	var theme = p_level_manager.get("current_theme")
	_apply_theme_for_level(theme, _level_num)

	# --- read grid parameters from the level manager -------------------
	_grid_origin = _read_vec2_attr(p_level_manager, "grid_origin", Vector2.ZERO)
	_grid_size   = _read_float_attr(p_level_manager, "grid_size", 64.0)
	_grid_cols   = _read_int_attr(p_level_manager, "grid_cols", 10)
	_grid_rows   = _read_int_attr(p_level_manager, "grid_rows", 10)

	_spawn_cells.clear()
	_base_cells.clear()
	_road_cells.clear()
	_guideline_cells.clear()
	_ground_lanes.clear()
	_portal_entries.clear()
	_portal_exits.clear()

	# --- spawn / base / guideline from level_data ----------------------
	var ldl: Variant = p_level_manager.get("level_data")
	if ldl != null and ldl is Dictionary:
		var ld: Dictionary = ldl as Dictionary
		_spawn_cells     = _extract_cells(ld.get("spawn_cells", []))
		_base_cells      = _extract_cells(ld.get("base_cells", []))
		_guideline_cells = _extract_cells(ld.get("guideline_cells", []))
		_road_cells      = _extract_cells(ld.get("path_cells", []))

	# --- actual path from level manager is the source of truth ----------
	# Air paths (key starts with "air") are ground-invisible — skip from road rendering.
	var mp: Variant = p_level_manager.get("multi_paths")
	if mp != null and mp is Dictionary:
		var collected: Array[Vector2i] = []
		for path_id in (mp as Dictionary).keys():
			if (path_id as String).begins_with("air"):
				continue  # air lanes: enemies fly, no ground road tile
			var lane_cells: Array[Vector2i] = _extract_cells((mp as Dictionary).get(path_id, []))
			_ground_lanes.append(lane_cells)
			for c in lane_cells:
				if not collected.has(c):
					collected.append(c)
		if not collected.is_empty():
			_road_cells = collected
		if _guideline_cells.is_empty() and (mp as Dictionary).has("default"):
			_guideline_cells = _extract_cells((mp as Dictionary).get("default", []))

	# --- portal entry/exit cells from path_portals in level_data -------
	if ldl != null and ldl is Dictionary:
		var portals = (ldl as Dictionary).get("path_portals", [])
		if portals is Array:
			var mp_dict: Dictionary = (mp as Dictionary) if mp != null and mp is Dictionary else {}
			for portal in portals:
				if not (portal is Dictionary): continue
				var pid: String = portal.get("path", "default")
				var e_idx: int   = int(portal.get("entry_index", -1))
				var x_idx: int   = int(portal.get("exit_index",  -1))
				var lane_raw = mp_dict.get(pid, [])
				var lane: Array[Vector2i] = _extract_cells(lane_raw)
				if e_idx >= 0 and e_idx < lane.size():
					_portal_entries.append(lane[e_idx])
				if x_idx >= 0 and x_idx < lane.size():
					_portal_exits.append(lane[x_idx])

	# --- fallback: single spawn / base cell ----------------------------
	if _spawn_cells.is_empty():
		_spawn_cells = _extract_single_cell(p_level_manager, "spawn_cell")

	if _base_cells.is_empty():
		_base_cells = _extract_single_cell(p_level_manager, "base_cell")

	if _road_cells.is_empty():
		var pc: Variant = p_level_manager.get("path_cells")
		_road_cells = _extract_cells(pc)

	if _guideline_cells.is_empty():
		_guideline_cells = _road_cells.duplicate()

	_draw_guideline = not _guideline_cells.is_empty()
	queue_redraw()
	_bake_map()  # Fire-and-forget: replaces draw commands with a single Sprite2D


# ============================================================= theme
func _parse_level_num(level_id: String) -> int:
	# Expects "level_01" .. "level_20"
	if level_id.begins_with("level_"):
		var num_str := level_id.substr(6)
		if num_str.is_valid_int():
			return clampi(num_str.to_int(), 1, 20)
	return 1


func _apply_theme_for_level(theme: Resource, level_num: int) -> void:
	if theme == null:
		return

	var area_idx     := (level_num - 1) / 5          # 0-3
	var level_in_area := (level_num - 1) % 5          # 0-4
	var t            := float(level_in_area) / 4.0    # 0.0 → 1.0

	# Base colors from AreaTheme
	var base_accent: Color = theme.get("color_path_glow")
	var base_line:   Color = theme.get("color_path_line")
	var base_bg:     Color = theme.get("color_bg")
	var base_build:  Color = theme.get("color_buildable")
	var base_grid:   Color = theme.get("color_grid")

	# Per-area accent endpoint: each area shifts toward a distinct hue by level 5
	# Area 1 (Cyan)   → Azure/Powder-Blue    Area 2 (Teal)  → Lime-Green
	# Area 3 (Violet) → Hot-Pink/Magenta     Area 4 (Gold)  → Fiery Red-Orange
	var accent_end := base_accent
	match area_idx:
		0: accent_end = Color(0.30, 0.55, 1.00, base_accent.a)  # cyan → azure
		1: accent_end = Color(0.10, 1.00, 0.30, base_accent.a)  # teal → lime
		2: accent_end = Color(1.00, 0.05, 0.55, base_accent.a)  # violet → hot-pink
		3: accent_end = Color(1.00, 0.30, 0.05, base_accent.a)  # gold → ember

	var accent := base_accent.lerp(accent_end, t)

	# Levels grow slightly darker / more intense within each area
	var brightness := 1.0 - t * 0.12

	# --- fill all color vars ---
	BG_COLOR      = Color(base_bg.r * brightness, base_bg.g * brightness, base_bg.b * brightness, 1.0)
	GRID_COLOR    = Color(base_grid.r, base_grid.g, base_grid.b, base_grid.a * (1.0 + t * 0.5))
	BUILDABLE_TINT = Color(base_build.r * brightness, base_build.g * brightness, base_build.b * brightness, 1.0)

	BOARD_BACKING = Color(BG_COLOR.r * 0.55, BG_COLOR.g * 0.55, BG_COLOR.b * 0.55, 0.82)
	BOARD_HALO    = Color(accent.r, accent.g, accent.b, 0.13 + t * 0.04)
	BOARD_FRAME   = Color(base_line.r, base_line.g, base_line.b, 0.30 + t * 0.08)

	# Road panel: bg × 1.9 + faint accent tint
	var rp_r := clampf(BG_COLOR.r * 1.9 + accent.r * 0.07, 0.0, 1.0)
	var rp_g := clampf(BG_COLOR.g * 1.9 + accent.g * 0.07, 0.0, 1.0)
	var rp_b := clampf(BG_COLOR.b * 1.9 + accent.b * 0.07, 0.0, 1.0)
	ROAD_PANEL     = Color(rp_r, rp_g, rp_b, 1.0)
	ROAD_PANEL_ALT = Color(rp_r * 0.74, rp_g * 0.74, rp_b * 0.74, 1.0)

	ROAD_EDGE_DARK   = Color(0.015, 0.018, 0.025, 0.95)
	ROAD_EDGE_CYAN   = Color(accent.r, accent.g, accent.b, 0.45 + t * 0.06)
	ROAD_CENTER_GLOW = Color(accent.r, accent.g, accent.b, 0.16 + t * 0.04)
	ROAD_CORNER_GLOW = Color(accent.r, accent.g, accent.b, 0.11 + t * 0.03)

	# Center line: bright desaturated version of accent
	var cl_r := clampf(accent.r * 0.55 + 0.38, 0.0, 1.0)
	var cl_g := clampf(accent.g * 0.55 + 0.38, 0.0, 1.0)
	var cl_b := clampf(accent.b * 0.55 + 0.38, 0.0, 1.0)
	ROAD_CENTER_LINE = Color(cl_r, cl_g, cl_b, 0.28 + t * 0.06)

	PATH_DOT_COLOR  = Color(accent.r, accent.g, accent.b, 0.35 + t * 0.06)
	GUIDELINE_COLOR = Color(base_line.r, base_line.g, base_line.b, 0.52 + t * 0.08)
	GUIDELINE_SHADOW = Color(0.0, 0.0, 0.0, 0.36)

	SPAWN_COLOR = theme.get("color_spawn")
	CORE_COLOR  = theme.get("color_base")


func _copy_colors_from(src: MazeMapRenderer) -> void:
	BG_COLOR       = src.BG_COLOR
	GRID_COLOR     = src.GRID_COLOR
	BUILDABLE_TINT = src.BUILDABLE_TINT
	BOARD_HALO     = src.BOARD_HALO
	BOARD_BACKING  = src.BOARD_BACKING
	BOARD_FRAME    = src.BOARD_FRAME
	ROAD_PANEL     = src.ROAD_PANEL
	ROAD_PANEL_ALT = src.ROAD_PANEL_ALT
	ROAD_EDGE_DARK = src.ROAD_EDGE_DARK
	ROAD_EDGE_CYAN = src.ROAD_EDGE_CYAN
	ROAD_CENTER_GLOW = src.ROAD_CENTER_GLOW
	ROAD_CENTER_LINE = src.ROAD_CENTER_LINE
	ROAD_CORNER_GLOW = src.ROAD_CORNER_GLOW
	SPAWN_COLOR    = src.SPAWN_COLOR
	CORE_COLOR     = src.CORE_COLOR
	GUIDELINE_COLOR = src.GUIDELINE_COLOR
	GUIDELINE_SHADOW = src.GUIDELINE_SHADOW
	PATH_DOT_COLOR = src.PATH_DOT_COLOR


# =============================================================== helpers
func _read_vec2_attr(obj: Node, attr: String, default: Vector2) -> Vector2:
	var v: Variant = obj.get(attr)
	if v == null:
		return default
	if v is Vector2:
		return v as Vector2
	if v is Array and (v as Array).size() >= 2:
		var a: Array = v as Array
		return Vector2(float(a[0]), float(a[1]))
	return default


func _read_float_attr(obj: Node, attr: String, default: float) -> float:
	var v: Variant = obj.get(attr)
	if v == null:
		return default
	return float(v)


func _read_int_attr(obj: Node, attr: String, default: int) -> int:
	var v: Variant = obj.get(attr)
	if v == null:
		return default
	return int(v)


func _extract_single_cell(obj: Node, attr: String) -> Array[Vector2i]:
	var v: Variant = obj.get(attr)
	if v == null:
		return []
	if v is Vector2i:
		return [v as Vector2i]
	if v is Array and (v as Array).size() >= 2:
		var a: Array = v as Array
		return [Vector2i(int(a[0]), int(a[1]))]
	return []


## Handles Array[Vector2i], Array[Array], and loosely typed Variant arrays.
func _extract_cells(cells: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if cells == null:
		return result
	if not (cells is Array):
		return result

	for cell in (cells as Array):
		if cell is Vector2i:
			result.append(cell as Vector2i)
		elif cell is Vector2:
			var v := cell as Vector2
			result.append(Vector2i(int(v.x), int(v.y)))
		elif cell is Array and (cell as Array).size() >= 2:
			var a: Array = cell as Array
			result.append(Vector2i(int(a[0]), int(a[1])))

	return result


func _cell_center(ci: Vector2i) -> Vector2:
	return _grid_origin + Vector2(
		float(ci.x) * _grid_size + _grid_size * 0.5,
		float(ci.y) * _grid_size + _grid_size * 0.5
	)


func _cell_rect(ci: Vector2i, inset: float = 0.0) -> Rect2:
	return Rect2(
		_grid_origin + Vector2(float(ci.x) * _grid_size + inset, float(ci.y) * _grid_size + inset),
		Vector2(_grid_size - inset * 2.0, _grid_size - inset * 2.0)
	)


func _path_points_from_cells(cells: Array[Vector2i]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in cells:
		points.append(_cell_center(cell))
	return points


func _setup_raw(
		p_origin: Vector2, p_grid_size: float, p_cols: int, p_rows: int,
		p_spawn: Array[Vector2i], p_base: Array[Vector2i],
		p_road: Array[Vector2i], p_guide: Array[Vector2i],
		p_draw_guide: bool, p_lanes: Array = [],
		p_portal_entries: Array[Vector2i] = [],
		p_portal_exits: Array[Vector2i] = []) -> void:
	_grid_origin     = p_origin
	_grid_size       = p_grid_size
	_grid_cols       = p_cols
	_grid_rows       = p_rows
	_spawn_cells     = p_spawn
	_base_cells      = p_base
	_road_cells      = p_road
	_guideline_cells = p_guide
	_draw_guideline  = p_draw_guide
	_ground_lanes    = p_lanes
	_portal_entries  = p_portal_entries
	_portal_exits    = p_portal_exits
	queue_redraw()


func _bake_map() -> void:
	var orig_parent := get_parent()
	if orig_parent == null or not is_inside_tree():
		return

	var tw   := float(_grid_cols) * _grid_size
	var th   := float(_grid_rows) * _grid_size
	var pad  := int(_grid_size * 0.85)
	var vp_w := int(tw) + pad * 2
	var vp_h := int(th) + pad * 2

	if vp_w > 4096 or vp_h > 4096:
		return  # Map too large to bake — keep procedural draw

	var vp := SubViewport.new()
	vp.size                       = Vector2i(vp_w, vp_h)
	vp.transparent_bg             = true
	vp.render_target_update_mode  = SubViewport.UPDATE_DISABLED
	vp.render_target_clear_mode   = SubViewport.CLEAR_MODE_ALWAYS
	orig_parent.add_child(vp)

	var cam := Camera2D.new()
	cam.position = Vector2(pad + tw * 0.5, pad + th * 0.5)
	cam.enabled  = true
	vp.add_child(cam)
	cam.make_current()

	var clone := MazeMapRenderer.new()
	vp.add_child(clone)
	clone._setup_raw(
		Vector2(pad, pad), _grid_size, _grid_cols, _grid_rows,
		_spawn_cells.duplicate(), _base_cells.duplicate(),
		_road_cells.duplicate(), _guideline_cells.duplicate(), _draw_guideline,
		_ground_lanes.duplicate(true),
		_portal_entries.duplicate(), _portal_exits.duplicate()
	)
	# Pass themed colors to the baked clone so the sprite captures the right palette
	clone._copy_colors_from(self)

	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.queue_free()

	if img == null or img.is_empty():
		return  # Bake failed — keep procedural draw

	var tex := ImageTexture.create_from_image(img)
	_baked_sprite             = Sprite2D.new()
	_baked_sprite.texture     = tex
	_baked_sprite.centered    = false
	_baked_sprite.z_index     = z_index
	_baked_sprite.z_as_relative = z_as_relative
	_baked_sprite.position    = orig_parent.to_local(to_global(_grid_origin - Vector2(pad, pad)))
	orig_parent.add_child(_baked_sprite)
	orig_parent.move_child(_baked_sprite, 0)  # Keep below towers/enemies

	visible = false  # Remove ~700 cached draw commands from the render pipeline


# =================================================================== draw
func _draw() -> void:
	_draw_background()
	_draw_grid()
	_draw_road_tiles()
	_draw_portal_tiles()
	_draw_spawn_cells()
	_draw_base_cells()
	if _draw_guideline:
		_draw_guideline_path()


func _draw_background() -> void:
	var tw: float = float(_grid_cols) * _grid_size
	var th: float = float(_grid_rows) * _grid_size
	var board_rect := Rect2(_grid_origin, Vector2(tw, th))
	var pad := _grid_size * 0.55
	draw_rect(board_rect.grow(pad * 1.35), Color(0.0, 0.0, 0.0, 0.28), true)
	draw_rect(board_rect.grow(pad), BOARD_BACKING, true)
	draw_rect(board_rect.grow(pad), BOARD_HALO, false, 3.0)
	draw_rect(board_rect.grow(6.0), BOARD_FRAME, false, 2.0)
	draw_rect(board_rect, BG_COLOR)

	for x in range(_grid_cols):
		for y in range(_grid_rows):
			if (x + y) % 2 == 0:
				draw_rect(_cell_rect(Vector2i(x, y), 1.0), BUILDABLE_TINT, true)


func _draw_grid() -> void:
	var tw: float = float(_grid_cols) * _grid_size
	var th: float = float(_grid_rows) * _grid_size

	for col in range(_grid_cols + 1):
		var x: float = _grid_origin.x + float(col) * _grid_size
		draw_line(Vector2(x, _grid_origin.y), Vector2(x, _grid_origin.y + th), GRID_COLOR, 1.0)

	for row in range(_grid_rows + 1):
		var y: float = _grid_origin.y + float(row) * _grid_size
		draw_line(Vector2(_grid_origin.x, y), Vector2(_grid_origin.x + tw, y), GRID_COLOR, 1.0)


func _draw_road_tiles() -> void:
	if _road_cells.is_empty():
		return

	for i in range(_road_cells.size()):
		var cell: Vector2i = _road_cells[i]
		var outer := _cell_rect(cell, _grid_size * 0.05)
		var inner := _cell_rect(cell, _grid_size * 0.13)
		var core  := _cell_rect(cell, _grid_size * 0.23)

		draw_rect(outer, ROAD_EDGE_DARK, true)
		draw_rect(inner, ROAD_PANEL if i % 2 == 0 else ROAD_PANEL_ALT, true)
		draw_rect(inner, ROAD_EDGE_CYAN, false, 1.2)
		draw_rect(core, ROAD_CORNER_GLOW, true)

	for cell in _road_cells:
		var c := _cell_center(cell)
		draw_circle(c, _grid_size * 0.042, PATH_DOT_COLOR)


func _draw_turn_arrows(cells: Array) -> void:
	if cells.size() < 2:
		return
	var arrow_size := _grid_size * 0.19
	# Corners: cells where incoming direction != outgoing direction
	for i in range(1, cells.size() - 1):
		var dir_in  := Vector2i(cells[i]) - Vector2i(cells[i - 1])
		var dir_out := Vector2i(cells[i + 1]) - Vector2i(cells[i])
		if dir_in != dir_out:
			_draw_path_arrow(_cell_center(cells[i]), Vector2(dir_out.x, dir_out.y).normalized(), arrow_size)
	# Final cell before base always gets an arrow so the goal is obvious
	var last := cells.size() - 1
	var final_dir := Vector2(Vector2i(cells[last]) - Vector2i(cells[last - 1])).normalized()
	_draw_path_arrow(_cell_center(cells[last]), final_dir, arrow_size)


func _draw_path_arrow(at: Vector2, dir: Vector2, size: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var perp := Vector2(-dir.y, dir.x)
	var tip   := at + dir  * size * 0.90
	var left  := at - dir  * size * 0.38 + perp * size * 0.52
	var right := at - dir  * size * 0.38 - perp * size * 0.52
	# Shadow
	var off := Vector2(0.0, 1.5)
	draw_colored_polygon(PackedVector2Array([tip + off, left + off, right + off]),
		Color(0.0, 0.0, 0.0, 0.32))
	# Fill
	draw_colored_polygon(PackedVector2Array([tip, left, right]),
		Color(GUIDELINE_COLOR.r, GUIDELINE_COLOR.g, GUIDELINE_COLOR.b, 0.72))


func _draw_portal_tiles() -> void:
	# Entry portal: violet tile — creep disappears here
	var entry_color := Color(0.78, 0.22, 1.0, 0.95)
	for cell in _portal_entries:
		draw_rect(_cell_rect(cell), Color(entry_color.r, entry_color.g, entry_color.b, 0.28), true)
		draw_rect(_cell_rect(cell, 1.0), entry_color, false, 2.5)

	# Exit portal: cyan tile — creep reappears here
	var exit_color := Color(0.18, 0.95, 1.0, 0.95)
	for cell in _portal_exits:
		draw_rect(_cell_rect(cell), Color(exit_color.r, exit_color.g, exit_color.b, 0.28), true)
		draw_rect(_cell_rect(cell, 1.0), exit_color, false, 2.5)


func _draw_spawn_cells() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(_grid_size * 0.18), 8)
	var half: float = _grid_size * 0.32
	var label_offset: float = half + font_size * 0.6

	for cell in _spawn_cells:
		var center: Vector2 = _cell_center(cell) + Vector2(0.0, -_grid_size * 0.08)

		var portal_center := _cell_center(cell)
		draw_circle(portal_center, _grid_size * 0.48, Color(SPAWN_COLOR.r, SPAWN_COLOR.g, SPAWN_COLOR.b, 0.09))
		draw_circle(portal_center, _grid_size * 0.36, Color(SPAWN_COLOR.r, SPAWN_COLOR.g, SPAWN_COLOR.b, 0.07))
		draw_arc(portal_center, _grid_size * 0.38, -PI * 0.15, PI * 1.15, 28, Color(0.997, 0.716, 0.698, 0.58), 1.6)
		draw_arc(portal_center, _grid_size * 0.28, PI * 0.85, PI * 2.10, 28, Color(1.0, 0.435, 0.402, 0.42), 1.2)

		var pts := PackedVector2Array([
			center + Vector2(0.0, -half),
			center + Vector2(-half * 0.866, half * 0.5),
			center + Vector2( half * 0.866, half * 0.5),
		])
		draw_colored_polygon(pts, SPAWN_COLOR)

		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.95),
			2.4,
			true
		)
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.96),
			3.2,
			true
		)
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
			Color(0.996, 0.192, 0.118, 0.549),
			1.2,
			true
		)
		var label_rect := Rect2(
			center.x - _grid_size * 0.5,
			center.y + label_offset,
			_grid_size,
			float(font_size)
		)
		draw_string(font, label_rect.position + Vector2(0, float(font_size)),
			"", HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, font_size, SPAWN_COLOR)


func _draw_base_cells() -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(_grid_size * 0.18), 8)
	var half: float = _grid_size * 0.32
	var label_offset: float = half + font_size * 0.6

	for cell in _base_cells:
		var center: Vector2 = _cell_center(cell) + Vector2(0.0, -_grid_size * 0.08)

		var core_center := _cell_center(cell)
		draw_circle(core_center, _grid_size * 0.52, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.11))
		draw_circle(core_center, _grid_size * 0.38, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.08))
		draw_arc(core_center, _grid_size * 0.40, -PI * 0.25, PI * 1.25, 30, Color(0.488, 0.841, 0.0, 0.56), 1.7)
		draw_arc(core_center, _grid_size * 0.28, PI * 0.80, PI * 2.05, 30, Color(0.0, 0.696, 0.262, 0.44), 1.2)

		var pts := PackedVector2Array([
			center + Vector2(0.0, -half),
			center + Vector2( half, 0.0),
			center + Vector2(0.0,  half),
			center + Vector2(-half, 0.0),
		])
		draw_colored_polygon(pts, CORE_COLOR)

		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.95),
			2.4,
			true
		)
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.96),
			3.2,
			true
		)
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.303, 0.95, 0.0, 0.55),
			1.2,
			true
		)
		var label_rect := Rect2(
			center.x - _grid_size * 0.5,
			center.y + label_offset,
			_grid_size,
			float(font_size)
		)
		draw_string(font, label_rect.position + Vector2(0, float(font_size)),
			"", HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, font_size, CORE_COLOR)


func _draw_guideline_path() -> void:
	if _guideline_cells.is_empty():
		return

	var path_size: int = _guideline_cells.size()
	if path_size < 2:
		return

	const ARROW_STEP := 5
	for i in range(1, path_size - 1):
		if i % ARROW_STEP != 0:
			continue
		var from_pos: Vector2 = _cell_center(_guideline_cells[i])
		var to_pos: Vector2 = _cell_center(_guideline_cells[i + 1])
		var dir: Vector2 = from_pos.direction_to(to_pos)
		var chevron_pos := from_pos.lerp(to_pos, 0.35)
		if _is_on_road_cell(chevron_pos):
			_draw_chevron(chevron_pos, dir, _grid_size * 0.30)

	var last_idx: int = path_size - 1
	var last_pos: Vector2 = _cell_center(_guideline_cells[last_idx])
	var prev_pos: Vector2 = _cell_center(_guideline_cells[last_idx - 1])
	var last_dir: Vector2 = prev_pos.direction_to(last_pos)
	var last_chevron_pos := prev_pos.lerp(last_pos, 0.55)
	if _is_on_road_cell(last_chevron_pos):
		_draw_chevron(last_chevron_pos, last_dir, _grid_size * 0.36)


func _is_on_road_cell(world_pos: Vector2) -> bool:
	var local_pos := world_pos - _grid_origin
	var cell := Vector2i(floori(local_pos.x / _grid_size), floori(local_pos.y / _grid_size))
	return _road_cells.has(cell)


func _draw_chevron(at: Vector2, dir: Vector2, size: float) -> void:
	if dir.length_squared() < 0.0001:
		return

	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = at + dir * size * 0.48
	var back: Vector2 = at - dir * size * 0.28
	var left: Vector2 = back + perp * size * 0.42
	var right: Vector2 = back - perp * size * 0.42

	var shadow_tip := tip + Vector2(0, 2)
	var shadow_left := left + Vector2(0, 2)
	var shadow_right := right + Vector2(0, 2)
	draw_line(shadow_left, shadow_tip, GUIDELINE_SHADOW, 2.0)
	draw_line(shadow_right, shadow_tip, GUIDELINE_SHADOW, 2.0)
	draw_line(back, tip, Color(0.25, 0.09, 0.02, 0.26), 1.2)
	draw_line(left, tip, GUIDELINE_COLOR, 1.45)
	draw_line(right, tip, GUIDELINE_COLOR, 1.45)

extends Node2D
class_name MazeMapRenderer

## Lightweight maze/Element-TD map renderer.
## Draws a readable fixed-path road that matches the actual enemy path cells.
## No per-frame processing — redraws on demand only.

# ------------------------------------------------------------------ colors
const BG_COLOR             := Color(0.055, 0.065, 0.095, 1.0)
const GRID_COLOR           := Color(0.12, 0.14, 0.18, 0.28)
const BUILDABLE_TINT       := Color(0.08, 0.105, 0.135, 1.0)
const BOARD_HALO           := Color(0.05, 0.28, 0.38, 0.12)
const BOARD_BACKING        := Color(0.012, 0.025, 0.040, 0.82)
const BOARD_FRAME          := Color(0.12, 0.54, 0.72, 0.34)
const ROAD_PANEL           := Color(0.105, 0.125, 0.155, 1.0)
const ROAD_PANEL_ALT       := Color(0.075, 0.095, 0.125, 1.0)
const ROAD_EDGE_DARK       := Color(0.015, 0.02, 0.03, 0.95)
const ROAD_EDGE_CYAN       := Color(0.12, 0.66, 0.90, 0.48)
const ROAD_CENTER_GLOW     := Color(0.12, 0.78, 1.0, 0.18)
const ROAD_CENTER_LINE     := Color(0.56, 0.92, 1.0, 0.32)
const ROAD_CORNER_GLOW     := Color(0.2, 0.95, 1.0, 0.12)
const SPAWN_COLOR          := Color(1.0,  0.22, 0.12, 0.95)
const CORE_COLOR           := Color(0.3,  0.95, 0.45, 0.95)
const GUIDELINE_COLOR      := Color(1.0, 0.58, 0.18, 0.56)
const GUIDELINE_SHADOW     := Color(0.0, 0.0, 0.0, 0.36)
const PATH_DOT_COLOR       := Color(0.16, 0.88, 1.0, 0.38)

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


# ================================================================== setup
func _ready() -> void:
	set_process(false)


func setup(p_level_manager: Node) -> void:
	# Clean up baked sprite from any previous level before re-baking
	if _baked_sprite != null and is_instance_valid(_baked_sprite):
		_baked_sprite.queue_free()
		_baked_sprite = null
	visible = true

	# --- read grid parameters from the level manager -------------------
	_grid_origin = _read_vec2_attr(p_level_manager, "grid_origin", Vector2.ZERO)
	_grid_size   = _read_float_attr(p_level_manager, "grid_size", 64.0)
	_grid_cols   = _read_int_attr(p_level_manager, "grid_cols", 10)
	_grid_rows   = _read_int_attr(p_level_manager, "grid_rows", 10)

	_spawn_cells.clear()
	_base_cells.clear()
	_road_cells.clear()
	_guideline_cells.clear()

	# --- spawn / base / guideline from level_data ----------------------
	var ldl: Variant = p_level_manager.get("level_data")
	if ldl != null and ldl is Dictionary:
		var ld: Dictionary = ldl as Dictionary
		_spawn_cells     = _extract_cells(ld.get("spawn_cells", []))
		_base_cells      = _extract_cells(ld.get("base_cells", []))
		_guideline_cells = _extract_cells(ld.get("guideline_cells", []))
		_road_cells      = _extract_cells(ld.get("path_cells", []))

	# --- actual path from level manager is the source of truth ----------
	# If the level has multi_paths, collect every lane so visuals always match
	# what WaveManager/Path2D uses for enemy movement.
	var mp: Variant = p_level_manager.get("multi_paths")
	if mp != null and mp is Dictionary:
		var collected: Array[Vector2i] = []
		for path_id in (mp as Dictionary).keys():
			var path_cells: Variant = (mp as Dictionary).get(path_id, [])
			for c in _extract_cells(path_cells):
				if not collected.has(c):
					collected.append(c)
				if _guideline_cells.is_empty():
					# keep default below; this branch intentionally only collects road cells
					pass
		if not collected.is_empty():
			_road_cells = collected
		if _guideline_cells.is_empty() and (mp as Dictionary).has("default"):
			_guideline_cells = _extract_cells((mp as Dictionary).get("default", []))

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
		p_draw_guide: bool) -> void:
	_grid_origin     = p_origin
	_grid_size       = p_grid_size
	_grid_cols       = p_cols
	_grid_rows       = p_rows
	_spawn_cells     = p_spawn
	_base_cells      = p_base
	_road_cells      = p_road
	_guideline_cells = p_guide
	_draw_guideline  = p_draw_guide
	queue_redraw()


func _bake_map() -> void:
	var orig_parent := get_parent()
	if orig_parent == null or not is_inside_tree():
		return

	var tw   := float(_grid_cols) * _grid_size
	var th   := float(_grid_rows) * _grid_size
	var pad  := int(_grid_size * 0.85)   # covers board_rect.grow(pad*1.35) padding
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
		_road_cells.duplicate(), _guideline_cells.duplicate(), _draw_guideline
	)

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
	orig_parent.move_child(_baked_sprite, 0)  # Keep below towers/enemies (same slot as this node)

	visible = false  # Remove ~700 cached draw commands from the render pipeline


# =================================================================== draw
func _draw() -> void:
	_draw_background()
	_draw_grid()
	_draw_road_tiles()
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

	# subtle playable-area tint inside each cell so road tiles stand out clearly
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

	# Panel road cells: visible tile identity matching actual path cells.
	for i in range(_road_cells.size()):
		var cell: Vector2i = _road_cells[i]
		var outer := _cell_rect(cell, _grid_size * 0.05)
		var inner := _cell_rect(cell, _grid_size * 0.13)
		var core  := _cell_rect(cell, _grid_size * 0.23)

		draw_rect(outer, ROAD_EDGE_DARK, true)
		draw_rect(inner, ROAD_PANEL if i % 2 == 0 else ROAD_PANEL_ALT, true)
		draw_rect(inner, ROAD_EDGE_CYAN, false, 1.2)
		draw_rect(core, ROAD_CORNER_GLOW, true)

	# Continuous route strip: makes the enemy lane read as one road, not isolated squares.
	var pts := _path_points_from_cells(_guideline_cells if not _guideline_cells.is_empty() else _road_cells)
	if pts.size() >= 2:
		draw_polyline(pts, ROAD_EDGE_DARK, _grid_size * 0.42, false)
		draw_polyline(pts, ROAD_PANEL, _grid_size * 0.34, false)
		draw_polyline(pts, ROAD_CENTER_GLOW, _grid_size * 0.07, false)
		draw_polyline(pts, ROAD_CENTER_LINE, 1.1, false)

	# Small cyan nodes at each cell center increase readability for fixed-path tests.
	for cell in _road_cells:
		var c := _cell_center(cell)
		draw_circle(c, _grid_size * 0.042, PATH_DOT_COLOR)


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
		# Outer black outline
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.96),
			3.2,
			true
		)

		# Inner warm highlight
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
#SPAWN
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
		# Outer black outline
		draw_polyline(
			PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(0.02, 0.02, 0.025, 0.96),
			3.2,
			true
		)

		# Inner warm highlight
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
#CORE
		draw_string(font, label_rect.position + Vector2(0, float(font_size)),
			"", HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x, font_size, CORE_COLOR)


func _draw_guideline_path() -> void:
	if _guideline_cells.is_empty():
		return

	var path_size: int = _guideline_cells.size()
	if path_size < 2:
		return

	# Place chevrons based on index so even straight routes are readable.
	const ARROW_STEP := 5
	for i in range(1, path_size - 1):
		if i % ARROW_STEP != 0:
			continue
		var from_pos: Vector2 = _cell_center(_guideline_cells[i])
		var to_pos: Vector2 = _cell_center(_guideline_cells[i + 1])
		var dir: Vector2 = from_pos.direction_to(to_pos)
		_draw_chevron(from_pos.lerp(to_pos, 0.35), dir, _grid_size * 0.30)

	# Final arrow into core.
	var last_idx: int = path_size - 1
	var last_pos: Vector2 = _cell_center(_guideline_cells[last_idx])
	var prev_pos: Vector2 = _cell_center(_guideline_cells[last_idx - 1])
	var last_dir: Vector2 = prev_pos.direction_to(last_pos)
	_draw_chevron(prev_pos.lerp(last_pos, 0.55), last_dir, _grid_size * 0.36)


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

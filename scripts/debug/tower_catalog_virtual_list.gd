class_name TowerCatalogVirtualList
extends Node

const DEFAULT_ROW_HEIGHT := 424.0
const SECTION_ROW_HEIGHT := 44.0
const SEPARATOR_ROW_HEIGHT := 16.0
const OVERSCAN_ROWS := 3

var row_factory: Callable = Callable()
var row_deactivator: Callable = Callable()

var _scroll_container: ScrollContainer = null
var _content_root: Control = null
var _canvas: Control = null
var _entries: Array = []
var _row_pool: Array[Control] = []
var _row_indices: Dictionary = {}
var _row_tops: Array[float] = []
var _total_height := 0.0

func setup(scroll_container: ScrollContainer, content_root: Control, factory: Callable, deactivator: Callable) -> void:
	_scroll_container = scroll_container
	_content_root = content_root
	row_factory = factory
	row_deactivator = deactivator

	for child in _content_root.get_children():
		child.queue_free()

	_canvas = Control.new()
	_canvas.name = "VirtualCanvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_child(_canvas)

	_scroll_container.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:
		refresh_visible_rows()
	)
	_scroll_container.resized.connect(refresh_visible_rows)

func set_entries(entries: Array) -> void:
	_entries = entries.duplicate(true)
	_recalculate_heights()
	if _canvas:
		_canvas.custom_minimum_size = Vector2(1120, _total_height)
		_canvas.size = _canvas.custom_minimum_size
	_ensure_pool()
	refresh_visible_rows()

func refresh_visible_rows() -> void:
	if _canvas == null:
		return
	if _entries.is_empty():
		_deactivate_all_rows()
		return

	var scroll_top := float(_scroll_container.scroll_vertical)
	var viewport_h := _scroll_container.size.y
	var first: int = maxi(0, _find_row_at(scroll_top) - OVERSCAN_ROWS)
	var last: int = mini(_entries.size() - 1, _find_row_at(scroll_top + viewport_h) + OVERSCAN_ROWS)
	var needed: int = last - first + 1
	_ensure_pool(needed)

	var used: Dictionary = {}
	for offset in range(needed):
		var entry_index: int = first + offset
		var row: Control = _row_pool[offset]
		used[row] = true
		_bind_row(row, entry_index)

	for row in _row_pool:
		if not used.has(row):
			_deactivate_row(row)
			row.visible = false
			_row_indices.erase(row)

func get_active_preview_count() -> int:
	var count := 0
	for row in _row_pool:
		if row.visible:
			count += 1
	return count

func _ensure_pool(min_rows: int = -1) -> void:
	if _canvas == null:
		return
	var viewport_rows: int = int(ceil(_scroll_container.size.y / DEFAULT_ROW_HEIGHT)) + OVERSCAN_ROWS * 2 + 1
	var target: int = maxi(viewport_rows, min_rows)
	while _row_pool.size() < target:
		var row := Control.new()
		row.name = "VirtualRow"
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.visible = false
		_canvas.add_child(row)
		_row_pool.append(row)

func _bind_row(row: Control, entry_index: int) -> void:
	_deactivate_row(row)
	_row_indices[row] = entry_index
	var entry: Dictionary = _entries[entry_index]
	var height := _entry_height(entry)
	row.position = Vector2(0, _row_tops[entry_index])
	row.size = Vector2(maxf(_scroll_container.size.x - 24.0, 1120.0), height)
	row.custom_minimum_size = row.size
	row.visible = true
	if row_factory.is_valid():
		row_factory.call(row, entry)

func _deactivate_all_rows() -> void:
	for row in _row_pool:
		_deactivate_row(row)
		row.visible = false
	_row_indices.clear()

func _deactivate_row(row: Control) -> void:
	if row_deactivator.is_valid():
		row_deactivator.call(row)
	for child in row.get_children():
		child.queue_free()

func _recalculate_heights() -> void:
	_row_tops.clear()
	_total_height = 0.0
	for entry in _entries:
		_row_tops.append(_total_height)
		_total_height += _entry_height(entry)

func _entry_height(entry: Dictionary) -> float:
	match str(entry.get("type", "row")):
		"section":
			return SECTION_ROW_HEIGHT
		"separator":
			return SEPARATOR_ROW_HEIGHT
		_:
			return DEFAULT_ROW_HEIGHT

func _find_row_at(y: float) -> int:
	if _row_tops.is_empty():
		return 0
	var low := 0
	var high := _row_tops.size() - 1
	while low <= high:
		var mid := int((low + high) / 2)
		var top := _row_tops[mid]
		var bottom := top + _entry_height(_entries[mid])
		if y < top:
			high = mid - 1
		elif y >= bottom:
			low = mid + 1
		else:
			return mid
	return clampi(low, 0, _row_tops.size() - 1)

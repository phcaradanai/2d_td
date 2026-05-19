# scripts/debug/tower_effect_catalog_zoom_controller.gd
class_name TowerEffectCatalogZoomController
extends RefCounted

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEPS: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

var zoom_value: float = 1.0
var content_root: Control = null
var scroll_container: ScrollContainer = null

var _natural_size: Vector2 = Vector2.ZERO

func setup(p_content_root: Control, p_scroll: ScrollContainer) -> void:
	content_root = p_content_root
	scroll_container = p_scroll
	content_root.resized.connect(_on_content_resized)

func _on_content_resized() -> void:
	if zoom_value == 1.0:
		_natural_size = content_root.size

func zoom_in() -> void:
	set_zoom(_next_step(1))

func zoom_out() -> void:
	set_zoom(_next_step(-1))

func reset_zoom() -> void:
	set_zoom(1.0)

func fit_grid() -> void:
	if content_root == null or scroll_container == null or _natural_size.x <= 0.0:
		return
	set_zoom(scroll_container.size.x / _natural_size.x)

func set_zoom(value: float) -> void:
	zoom_value = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()

func get_zoom() -> float:
	return zoom_value

func _apply_zoom() -> void:
	if content_root == null:
		return
	content_root.scale = Vector2.ONE * zoom_value
	if _natural_size != Vector2.ZERO:
		content_root.custom_minimum_size = _natural_size * zoom_value

func _next_step(direction: int) -> float:
	var current_index := 2
	for i in range(ZOOM_STEPS.size()):
		if ZOOM_STEPS[i] >= zoom_value - 0.01:
			current_index = i
			break
	return ZOOM_STEPS[clamp(current_index + direction, 0, ZOOM_STEPS.size() - 1)]

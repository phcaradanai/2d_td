extends RefCounted
class_name TowerVisualRenderer

# Central tower visual facade.
# tower.gd calls this file; actual tower silhouettes live in scripts/towers/visuals/*_tower_visual.gd.

const TowerVisualDrawUtils = preload("res://scripts/towers/visuals/common/tower_visual_draw_utils.gd")
const TowerVisualRegistry = preload("res://scripts/towers/visuals/tower_visual_registry.gd")

static func draw_base_plate(t: Node2D) -> void:
	TowerVisualDrawUtils.draw_base_plate(t)

static func draw_element_core(t: Node2D) -> void:
	TowerVisualDrawUtils.draw_element_core(t)

static func draw_turret_contour(t: Node2D) -> void:
	var visual_script := TowerVisualRegistry.get_visual_script(t.tower_id, t.visual_type)
	if visual_script:
		visual_script.draw_contour(t)

static func draw_turret_top(t: Node2D) -> void:
	var lvl = t.tree_tier
	var el_colors: Array[Color] = t._get_all_element_colors()
	var main_color: Color
	var secondary_color: Color
	var core_color: Color

	if not el_colors.is_empty():
		main_color = el_colors[0]
		secondary_color = el_colors[1] if el_colors.size() >= 2 else el_colors[0].lightened(0.3)
		core_color = main_color.lightened(0.45)
	else:
		main_color = Color(0.45, 0.55, 0.6, 1.0)
		secondary_color = Color(0.55, 0.65, 0.7, 1.0)
		core_color = Color(0.7, 0.8, 0.85, 1.0)

	var size = 20.0
	var visual_script := TowerVisualRegistry.get_visual_script(t.tower_id, t.visual_type)
	if visual_script:
		visual_script.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

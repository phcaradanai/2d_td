extends RefCounted
class_name TowerVisualRenderer

# Central tower visual facade.
# tower.gd calls this file; actual tower silhouettes live in scripts/towers/visuals/*_tower_visual.gd.

const TowerVisualDrawUtilsScript = preload("res://scripts/towers/visuals/common/tower_visual_draw_utils.gd")
const TowerVisualRegistryScript = preload("res://scripts/towers/visuals/tower_visual_registry.gd")
const CatalogPreviewModeScript = preload("res://scripts/debug/catalog_preview_mode.gd")

const DETAIL_QUALITY_TOWER_IDS := {
	"blacksmith_t1": true,
	"fire_t1": true,
	"ice_t1": true,
	"light_t1": true,
	"nature_t1": true,
}

static func draw_base_plate(t: Node2D) -> void:
	TowerVisualDrawUtilsScript.draw_base_plate(t)

static func draw_element_core(t: Node2D) -> void:
	TowerVisualDrawUtilsScript.draw_element_core(t)

static func draw_turret_contour(t: Node2D) -> void:
	var visual_script := TowerVisualRegistryScript.get_visual_script(t.tower_id, t.visual_type)
	if visual_script:
		var detail_quality := _resolve_detail_quality(t)
		if DETAIL_QUALITY_TOWER_IDS.has(t.tower_id):
			visual_script.draw_contour(t, detail_quality)
		else:
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
	var visual_script := TowerVisualRegistryScript.get_visual_script(t.tower_id, t.visual_type)
	if visual_script:
		var detail_quality := _resolve_detail_quality(t)
		if DETAIL_QUALITY_TOWER_IDS.has(t.tower_id):
			visual_script.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors, detail_quality)
		else:
			visual_script.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

static func _resolve_detail_quality(t: Node2D) -> int:
	var is_static_preview := CatalogPreviewModeScript.is_static_preview(t)
	if is_static_preview:
		return TowerVisualDrawUtilsScript.DetailQuality.LOW

	if CatalogPreviewModeScript.is_selected_demo(t) or bool(t.get("is_selected")) or bool(t.get("is_hovered")) or bool(t.get("hovered")):
		return TowerVisualDrawUtilsScript.DetailQuality.HIGH

	return TowerVisualDrawUtilsScript.DetailQuality.MEDIUM

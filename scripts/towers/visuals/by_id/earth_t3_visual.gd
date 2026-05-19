extends RefCounted

# Tower: Earth Tower III
# Role: Heavy boulder slam
# Elements: earth
# Visual source: tier fallback wrapper → by_id/earth_t1_visual.gd
# Tier 3 intentionally reuses the tier 1 premium model until a dedicated T3 silhouette is produced.

const _Fallback = preload("res://scripts/towers/visuals/by_id/earth_t1_visual.gd")

static func draw_contour(t: Node2D) -> void:
	_Fallback.draw_contour(t)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	_Fallback.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

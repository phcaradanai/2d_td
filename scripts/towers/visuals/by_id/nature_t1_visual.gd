extends RefCounted

# Tower: Nature Tower I
# Role: Bio-vine tangle trap
# Elements: nature
# Visual source: wrapper → fallback/bio_vine_tower_visual.gd
# TODO: Replace fallback wrapper with a custom silhouette that communicates role.

const _Fallback = preload("res://scripts/towers/visuals/fallback/bio_vine_tower_visual.gd")

static func draw_contour(t: Node2D) -> void:
	_Fallback.draw_contour(t)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	_Fallback.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

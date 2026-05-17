extends RefCounted

# Tower: Nova Tower 2
# Role: Solar nova — radiant AoE burst
# Elements: light, fire, nature
# Visual source: wrapper → fallback/solar_bloom_tower_visual.gd
# TODO: Replace fallback wrapper with a custom silhouette that communicates role.

const _Fallback = preload("res://scripts/towers/visuals/fallback/solar_bloom_tower_visual.gd")

static func draw_contour(t: Node2D) -> void:
	_Fallback.draw_contour(t)

static func draw_top(t: Node2D, main_color: Color, secondary_color: Color, core_color: Color, lvl: int, size: float, el_colors: Array[Color]) -> void:
	_Fallback.draw_top(t, main_color, secondary_color, core_color, lvl, size, el_colors)

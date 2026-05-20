class_name CatalogRenderGuard
extends RefCounted

const DEFAULT_MAX_PREVIEW_CARDS := 24

static var catalog_safe_mode: bool = true
static var catalog_list_first: bool = true
static var max_preview_cards: int = 24
static var max_active_vfx_previews: int = 1
static var max_draw_calls_per_visual: int = 24
static var max_draw_calls_per_catalog_card: int = 24
static var max_polyline_points: int = 16
static var max_circle_segments: int = 12
static var max_detail_segments: int = 12
static var allow_decorative_strokes: bool = false
static var allow_rank_badges: bool = false
static var allow_animated_redraw: bool = false

static func reset_to_defaults() -> void:
	catalog_safe_mode = true
	catalog_list_first = true
	max_preview_cards = DEFAULT_MAX_PREVIEW_CARDS
	max_active_vfx_previews = 1
	max_draw_calls_per_visual = 24
	max_draw_calls_per_catalog_card = 24
	max_polyline_points = 16
	max_circle_segments = 12
	max_detail_segments = 12
	allow_decorative_strokes = false
	allow_rank_badges = false
	allow_animated_redraw = false

static func is_catalog_preview(node: Node) -> bool:
	return catalog_safe_mode and node != null and node.get("preview_mode") == true

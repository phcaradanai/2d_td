extends RefCounted
class_name CosmeticDrawUtils

static func draw_projectile(canvas: CanvasItem, cosmetic_id: String, cfg: Dictionary, speed: float = 560.0) -> void:
	var core := Color.from_string(str(cfg.get("core_color", "#8fc8ff")), Color(0.56, 0.78, 1.0, 1.0))
	var glow := Color.from_string(str(cfg.get("glow_color", "#2f7fff")), Color(0.18, 0.50, 1.0, 0.78))
	var accent := Color.from_string(str(cfg.get("accent_color", "#ffffff")), Color.WHITE)
	var length := 17.0 if speed > 550.0 else 14.0
	if cosmetic_id == "basic_gold_bolt":
		var pts := PackedVector2Array([Vector2(length, 0), Vector2(-length * 0.45, -5.2), Vector2(-length * 0.78, 0), Vector2(-length * 0.45, 5.2)])
		canvas.draw_colored_polygon(pts, core)
		canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 1.0, false)
		canvas.draw_circle(Vector2(2.0, 0), 2.8, Color.WHITE)
		return
	_draw_default_bolt(canvas, core, glow, accent, length)

static func draw_impact(canvas: CanvasItem, cfg: Dictionary, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	var fade := 1.0 - t
	var core := Color.from_string(str(cfg.get("core_color", "#8fc8ff")), Color(0.56, 0.78, 1.0, 1.0))
	var glow := Color.from_string(str(cfg.get("glow_color", "#2f7fff")), Color(0.18, 0.50, 1.0, 0.78))
	var accent := Color.from_string(str(cfg.get("accent_color", "#ffffff")), Color.WHITE)
	var low_detail := bool(cfg.get("_low_detail", false))
	var radius := lerpf(5.0, 18.0, t)
	canvas.draw_circle(Vector2.ZERO, radius * 0.34, Color(core.r, core.g, core.b, 0.38 * fade))
	canvas.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 10, Color(glow.r, glow.g, glow.b, 0.96 * fade), 2.2, false)
	var ray_count := 4
	for i in range(ray_count):
		var a := float(i) * TAU / float(ray_count)
		var p1 := Vector2.RIGHT.rotated(a) * radius * 0.35
		var p2 := Vector2.RIGHT.rotated(a) * radius
		var width := 1.2 if low_detail else 1.6
		canvas.draw_line(p1, p2, Color(accent.r, accent.g, accent.b, 0.90 * fade), width, false)

static func _draw_default_bolt(canvas: CanvasItem, core: Color, glow: Color, accent: Color, length: float) -> void:
	var pts := PackedVector2Array([Vector2(length, 0), Vector2(-length / 2.0, -3), Vector2(-length / 2.0, 3)])
	canvas.draw_colored_polygon(pts, core)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 1.0, true)
	canvas.draw_line(Vector2(-length, 0), Vector2(length, 0), Color(glow.r, glow.g, glow.b, 0.4), 4.0, true)

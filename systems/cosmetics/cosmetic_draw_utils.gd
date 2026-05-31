extends RefCounted
class_name CosmeticDrawUtils

const _ResolverScript := preload("res://systems/cosmetics/cosmetic_preview_resolver.gd")
const _SpriteRendererScript := preload("res://systems/cosmetics/cosmetic_sprite_renderer.gd")

static func draw_projectile_default(canvas: CanvasItem, tower_cfg: Dictionary) -> void:
	var info := _ResolverScript.get_projectile_draw_info(tower_cfg)
	var core: Color = info["core_color"]
	var glow: Color = info["glow_color"]
	var accent: Color = info["accent_color"]
	var speed: float = info["speed"]
	match str(info["shape"]):
		"flame":
			_draw_flame(canvas, core, glow, accent)
		"beam":
			_draw_beam(canvas, core, glow)
		"shell":
			_draw_shell(canvas, core, glow, accent)
		"droplet":
			_draw_droplet(canvas, core, glow)
		_:
			_draw_default_bolt(canvas, core, glow, accent, 17.0 if speed > 550.0 else 14.0)

static func draw_impact_default(canvas: CanvasItem, tower_cfg: Dictionary) -> void:
	var info := _ResolverScript.get_impact_draw_info(tower_cfg)
	var core: Color = info["core_color"]
	var glow: Color = info["glow_color"]
	var accent: Color = info["accent_color"]
	_draw_impact_mode(canvas, str(info["mode"]), core, glow, accent)

static func _draw_flame(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	var fl := 20.0
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5, -5), Vector2(fl, -2), Vector2(fl + 8, 0), Vector2(fl, 2), Vector2(-5, 5)]), Color(glow.r, glow.g, glow.b, 0.55))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-3, -3), Vector2(fl * 0.75, -1), Vector2(fl + 3, 0), Vector2(fl * 0.75, 1), Vector2(-3, 3)]), core)
	canvas.draw_circle(Vector2(fl * 0.55, 0), 2.5, accent)

static func _draw_beam(canvas: CanvasItem, core: Color, glow: Color) -> void:
	canvas.draw_line(Vector2(-12, 0), Vector2(16, 0), glow, 4.0, true)
	canvas.draw_line(Vector2(-10, 0), Vector2(18, 0), Color.WHITE, 1.5, true)
	canvas.draw_circle(Vector2(18, 0), 2.0, core)

static func _draw_shell(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 5.0, core)
	canvas.draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 16, glow, 1.5)
	canvas.draw_line(Vector2(-10, 0), Vector2(-2, 0), accent, 3.0)

static func _draw_droplet(canvas: CanvasItem, core: Color, glow: Color) -> void:
	var pts := PackedVector2Array([Vector2(8, 0), Vector2(-5, -4), Vector2(-8, 0), Vector2(-5, 4)])
	canvas.draw_colored_polygon(pts, core)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), glow, 1.0)
	canvas.draw_circle(Vector2(-2, 0), 2.5, Color.WHITE)

static func _draw_impact_mode(canvas: CanvasItem, mode: String, core: Color, glow: Color, accent: Color) -> void:
	var r := 22.0
	match mode:
		"splash": _draw_impact_splash(canvas, r, core, glow, accent)
		"slow": _draw_impact_slow(canvas, core, glow, accent)
		"chain": _draw_impact_chain(canvas, core, glow, accent)
		"beam": _draw_impact_beam_hit(canvas, core, glow, accent)
		"fire": _draw_impact_fire(canvas, core, glow)
		"fire_blast": _draw_impact_fire_blast(canvas, r, core, glow, accent)
		"seismic": _draw_impact_seismic(canvas, r, core, glow, accent)
		"water": _draw_impact_water(canvas, r, core, glow, accent)
		"frost": _draw_impact_frost(canvas, core, glow)
		"toxic": _draw_impact_toxic(canvas, r, core, glow, accent)
		"void": _draw_impact_void(canvas, core, glow, accent)
		"prism": _draw_impact_prism(canvas, core, glow)
		"nature": _draw_impact_nature(canvas, core, glow)
		"gold": _draw_impact_gold(canvas, core, glow, accent)
		"arcane": _draw_impact_arcane(canvas, r, core, glow, accent)
		_: _draw_impact_single(canvas, core, glow, accent)

static func _draw_impact_single(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 4.0, Color(core.r, core.g, core.b, 0.72))
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + 0.25)
		canvas.draw_line(dir * 3.0, dir * 13.0, Color(glow.r, glow.g, glow.b, 0.72), 1.6, true)
	canvas.draw_circle(Vector2.ZERO, 1.8, Color.WHITE)

static func _draw_impact_splash(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, r * 0.46, Color(glow.r, glow.g, glow.b, 0.14))
	canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(core.r, core.g, core.b, 0.58), 2.15, true)
	canvas.draw_arc(Vector2.ZERO, r * 0.58, PI * 0.08, PI * 1.52, 28, Color(accent.r, accent.g, accent.b, 0.52), 1.4, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
		canvas.draw_line(dir * (r * 0.18), dir * (r * 0.42), Color(core.r, core.g, core.b, 0.36), 1.5, true)
	canvas.draw_circle(Vector2.ZERO, 4.5, Color.WHITE)

static func _draw_impact_slow(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(glow.r, glow.g, glow.b, 0.66), 2.0, true)
	canvas.draw_arc(Vector2.ZERO, 24.0, -PI * 0.25, PI * 1.1, 24, Color(core.r, core.g, core.b, 0.32), 1.2, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0)
		canvas.draw_line(dir * 5.0, dir * 14.0, Color(accent.r, accent.g, accent.b, 0.58), 1.0, true)
	canvas.draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

static func _draw_impact_chain(canvas: CanvasItem, core: Color, glow: Color, _accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 4.8, Color(core.r, core.g, core.b, 0.70))
	for i in range(5):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 5.0 + 0.15)
		var side := dir.rotated(PI * 0.5)
		canvas.draw_polyline(PackedVector2Array([dir * 4.0, dir * 10.0 + side * 2.3, dir * 15.0 - side * 1.7]), Color(glow.r, glow.g, glow.b, 0.76), 1.35, true)

static func _draw_impact_beam_hit(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_line(Vector2(-16.0, 0.0), Vector2(18.0, 0.0), Color(glow.r, glow.g, glow.b, 0.74), 3.0, true)
	canvas.draw_line(Vector2(-10.0, -5.5), Vector2(11.0, 5.5), Color(core.r, core.g, core.b, 0.52), 1.3, true)
	canvas.draw_line(Vector2(-10.0, 5.5), Vector2(11.0, -5.5), Color(accent.r, accent.g, accent.b, 0.48), 1.1, true)
	canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

static func _draw_impact_fire(canvas: CanvasItem, core: Color, glow: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-10, -5), Vector2(2, -11), Vector2(15, 0), Vector2(2, 11), Vector2(-10, 5)]), Color(glow.r, glow.g, glow.b, 0.42))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5, -2.8), Vector2(4, -5), Vector2(10, 0), Vector2(4, 5), Vector2(-5, 2.8)]), Color(core.r, core.g, core.b, 0.68))
	canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

static func _draw_impact_fire_blast(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, r * 0.34, Color(glow.r, glow.g, glow.b, 0.18))
	canvas.draw_arc(Vector2.ZERO, r * 0.72, -0.2, TAU - 0.2, 34, Color(core.r, core.g, core.b, 0.58), 2.0, true)
	for i in range(7):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 7.0 + 0.12)
		canvas.draw_line(dir * (r * 0.12), dir * (r * (0.36 + float(i % 3) * 0.045)), Color(accent.r, accent.g, accent.b, 0.45), 1.4, true)
	canvas.draw_circle(Vector2.ZERO, 3.2, Color.WHITE)

static func _draw_impact_seismic(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, r * 0.88, PI * 0.05, PI * 1.85, 42, Color(core.r, core.g, core.b, 0.50), 2.3, true)
	canvas.draw_arc(Vector2.ZERO, r * 0.42, -PI * 0.2, PI * 1.2, 24, Color(glow.r, glow.g, glow.b, 0.28), 1.2, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + 0.08)
		var side := dir.rotated(PI * 0.5)
		canvas.draw_polyline(PackedVector2Array([dir * (r * 0.10), dir * (r * 0.34) + side * (2.0 if i % 2 == 0 else -2.0), dir * (r * 0.58)]), Color(accent.r, accent.g, accent.b, 0.58), 1.7, true)
	canvas.draw_circle(Vector2.ZERO, 3.0, Color.WHITE)

static func _draw_impact_water(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, r * 0.82, PI * 0.10, PI * 1.92, 44, Color(core.r, core.g, core.b, 0.56), 2.0, true)
	canvas.draw_arc(Vector2.ZERO, r * 0.50, -PI * 0.24, PI * 1.15, 28, Color(glow.r, glow.g, glow.b, 0.34), 1.4, true)
	for i in range(5):
		canvas.draw_circle(Vector2.RIGHT.rotated(float(i) * TAU / 5.0 + 0.35) * (r * 0.34), 1.8, Color(accent.r, accent.g, accent.b, 0.58))
	canvas.draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

static func _draw_impact_frost(canvas: CanvasItem, core: Color, glow: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(glow.r, glow.g, glow.b, 0.62), 1.7, true)
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + PI * 0.08)
		var side := dir.rotated(PI * 0.5)
		canvas.draw_colored_polygon(PackedVector2Array([dir * 17.0, dir * 6.5 + side * 2.4, dir * 6.5 - side * 2.4]), Color(core.r, core.g, core.b, 0.42))
	canvas.draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

static func _draw_impact_toxic(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, r * 0.22, Color(glow.r, glow.g, glow.b, 0.24))
	canvas.draw_arc(Vector2.ZERO, r * 0.56, 0.0, TAU, 26, Color(core.r, core.g, core.b, 0.46), 1.4, true)
	for offset in [Vector2(8, -3), Vector2(-7, -5), Vector2(-5, 6), Vector2(5, 7), Vector2(13, 4)]:
		canvas.draw_circle(offset, 1.6, Color(accent.r, accent.g, accent.b, 0.72))
	canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

static func _draw_impact_void(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 5.2, Color(0.02, 0.0, 0.045, 0.78))
	canvas.draw_arc(Vector2.ZERO, 12.5, 0.0, TAU, 32, Color(glow.r, glow.g, glow.b, 0.70), 1.8, true)
	canvas.draw_arc(Vector2.ZERO, 18.5, PI * 0.22, PI * 1.70, 32, Color(core.r, core.g, core.b, 0.34), 1.1, true)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + 0.42)
		canvas.draw_line(dir * 5.0, dir * 15.5, Color(accent.r, accent.g, accent.b, 0.52), 1.1, true)
	canvas.draw_circle(Vector2.ZERO, 1.8, Color.WHITE)

static func _draw_impact_prism(canvas: CanvasItem, core: Color, glow: Color) -> void:
	for i in range(6):
		canvas.draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(float(i) * TAU / 6.0) * 17.0, Color(core.r, core.g, core.b, 0.62), 1.35, true)
	canvas.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 6, Color(glow.r, glow.g, glow.b, 0.72), 1.4, true)
	canvas.draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

static func _draw_impact_nature(canvas: CanvasItem, core: Color, glow: Color) -> void:
	for i in range(5):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 5.0 - PI * 0.5)
		var side := dir.rotated(PI * 0.5)
		canvas.draw_colored_polygon(PackedVector2Array([dir * 15.0, dir * 5.0 + side * 3.2, dir * 5.0 - side * 3.2]), Color(core.r, core.g, core.b, 0.42))
	canvas.draw_arc(Vector2.ZERO, 13.0, PI * 0.15, PI * 1.55, 20, Color(glow.r, glow.g, glow.b, 0.44), 1.2, true)
	canvas.draw_circle(Vector2.ZERO, 2.4, Color.WHITE)

static func _draw_impact_gold(canvas: CanvasItem, core: Color, _glow: Color, accent: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 8, Color(core.r, core.g, core.b, 0.72), 1.6, true)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + PI * 0.25)
		canvas.draw_rect(Rect2(dir.x * 9.0 - 1.6, dir.y * 9.0 - 1.6, 3.2, 3.2), Color(accent.r, accent.g, accent.b, 0.62))
	canvas.draw_circle(Vector2.ZERO, 2.2, Color.WHITE)

static func _draw_impact_arcane(canvas: CanvasItem, r: float, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_arc(Vector2.ZERO, r * 0.50, 0.0, TAU, 3, Color(core.r, core.g, core.b, 0.48), 1.5, true)
	canvas.draw_arc(Vector2.ZERO, r * 0.34, PI * 0.25, PI * 1.58, 5, Color(glow.r, glow.g, glow.b, 0.58), 1.1, true)
	for i in range(6):
		canvas.draw_circle(Vector2.RIGHT.rotated(float(i) * TAU / 6.0 + 0.18) * (r * 0.26), 1.2, Color(accent.r, accent.g, accent.b, 0.68))
	canvas.draw_circle(Vector2.ZERO, 2.0, Color.WHITE)

static func draw_aura(canvas: CanvasItem, _cosmetic_id: String, cfg: Dictionary) -> void:
	var core := Color.from_string(str(cfg.get("core_color", "#8fc8ff")), Color(0.56, 0.78, 1.0))
	var glow := Color.from_string(str(cfg.get("glow_color", "#2f7fff")), Color(0.18, 0.50, 1.0))
	var accent := Color.from_string(str(cfg.get("accent_color", "#ffffff")), Color.WHITE)
	var pattern := str(cfg.get("aura_pattern", "ring"))
	_draw_aura_pattern(canvas, pattern, core, glow, accent)

static func draw_aura_default(canvas: CanvasItem, tower_cfg: Dictionary) -> void:
	var elements: Array = tower_cfg.get("elements", [])
	var core := Color(0.56, 0.78, 1.0)
	var glow := Color(0.18, 0.50, 1.0)
	var accent := Color.WHITE
	if elements.size() > 0:
		core = _ResolverScript._element_color(str(elements[0]))
		glow = core.lightened(0.22)
	if elements.size() > 1:
		accent = _ResolverScript._element_color(str(elements[1])).lightened(0.15)
	var visual_type := str(tower_cfg.get("visual_type", ""))
	var pattern := "spark" if visual_type == "forge_anvil" else "ring"
	_draw_aura_pattern(canvas, pattern, core, glow, accent)

static func _draw_aura_pattern(canvas: CanvasItem, pattern: String, core: Color, glow: Color, accent: Color) -> void:
	if pattern == "spark":
		_draw_aura_spark(canvas, core, glow, accent)
	else:
		_draw_aura_ring(canvas, core, glow, accent)

static func _draw_aura_ring(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 32.0, Color(glow.r, glow.g, glow.b, 0.06))
	canvas.draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 36, Color(core.r, core.g, core.b, 0.22), 1.4, true)
	canvas.draw_arc(Vector2.ZERO, 24.0, -0.4, 2.2, 18, Color(glow.r, glow.g, glow.b, 0.38), 1.0, true)
	canvas.draw_arc(Vector2.ZERO, 24.0, PI + 0.2, PI + 2.6, 18, Color(accent.r, accent.g, accent.b, 0.34), 1.0, true)
	canvas.draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 28, Color(glow.r, glow.g, glow.b, 0.16), 0.9, true)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + 0.4)
		canvas.draw_circle(dir * 27.0, 2.2, Color(accent.r, accent.g, accent.b, 0.62))
		canvas.draw_circle(dir * 27.0, 1.0, Color.WHITE)

static func _draw_aura_spark(canvas: CanvasItem, core: Color, glow: Color, accent: Color) -> void:
	canvas.draw_circle(Vector2.ZERO, 28.0, Color(glow.r, glow.g, glow.b, 0.06))
	canvas.draw_arc(Vector2.ZERO, 26.0, deg_to_rad(200.0), deg_to_rad(340.0), 22, Color(core.r, core.g, core.b, 0.28), 1.5, true)
	canvas.draw_arc(Vector2.ZERO, 26.0, deg_to_rad(20.0), deg_to_rad(160.0), 22, Color(glow.r, glow.g, glow.b, 0.24), 1.5, true)
	canvas.draw_arc(Vector2.ZERO, 20.0, deg_to_rad(210.0), deg_to_rad(330.0), 18, Color(core.r, core.g, core.b, 0.16), 0.9, true)
	for sp in [Vector2(-8, -22), Vector2(0, -25), Vector2(8, -22), Vector2(15, -18), Vector2(-15, -18)]:
		canvas.draw_circle(sp, 2.0, Color(core.r, core.g, core.b, 0.08))
		canvas.draw_circle(sp, 1.0, Color(accent.r, accent.g, accent.b, 0.80))
		canvas.draw_circle(sp, 0.45, Color.WHITE)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + PI * 0.25)
		canvas.draw_circle(dir * 24.0, 3.2, Color(core.r, core.g, core.b, 0.14))
		canvas.draw_circle(dir * 24.0, 1.8, Color(glow.r, glow.g, glow.b, 0.70))
		canvas.draw_circle(dir * 24.0, 0.8, Color.WHITE)

static func draw_projectile(canvas: CanvasItem, cosmetic_id: String, cfg: Dictionary, speed: float = 560.0) -> void:
	var textures: Array[Texture2D] = _SpriteRendererScript.collect_textures(cfg)
	if _SpriteRendererScript.draw_frame(canvas, cfg, textures, float(Engine.get_process_frames() % 24) / 24.0):
		return
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
	var textures: Array[Texture2D] = _SpriteRendererScript.collect_textures(cfg)
	if _SpriteRendererScript.draw_frame(canvas, cfg, textures, progress):
		return
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

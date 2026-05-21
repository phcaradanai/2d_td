extends Node2D
class_name EnemyBeamVFX

var time: float = 999.0
var duration: float = 0.45
var beam_color: Color = Color(0.9, 1.0, 0.95, 1.0)
var mode: String = "idle"
var links: Array[Node] = []
var source: Node2D = null
var _redraw_elapsed: float = 0.0
const LINK_REDRAW_INTERVAL := 0.10

func _ready() -> void:
	visible = false
	set_process(false)

func play_heal_cast(p_duration: float = 0.45) -> void:
	mode = "heal_cast"
	duration = p_duration
	time = 0.0
	beam_color = Color(1.0, 0.92, 0.56, 1.0)
	visible = true
	set_process(true)
	queue_redraw()

func show_links(p_source: Node2D, p_targets: Array, p_color: Color) -> void:
	source = p_source
	links = p_targets.duplicate()
	beam_color = p_color
	_redraw_elapsed = 0.0

	if links.is_empty():
		clear_links()
		return

	mode = "links"
	visible = true
	set_process(true)
	queue_redraw()

func clear_links() -> void:
	links.clear()
	mode = "idle"
	visible = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if mode == "heal_cast":
		time += delta
		if time >= duration:
			mode = "idle"
			visible = false
			set_process(false)
			queue_redraw()
			return
		queue_redraw()
	else:
		time += delta
		_redraw_elapsed += delta
		if _redraw_elapsed >= LINK_REDRAW_INTERVAL:
			_redraw_elapsed = 0.0
			queue_redraw()

func _draw() -> void:
	if not visible:
		return

	if mode == "heal_cast":
		_draw_heal_cast()
	elif mode == "links":
		_draw_links()

func _draw_heal_cast() -> void:
	if time >= duration:
		return
	var t := clampf(time / duration, 0.0, 1.0)
	var alpha := sin(t * PI)
	var height := 76.0
	var half_width := 7.0 + alpha * 5.0
	var pts := PackedVector2Array([
		Vector2(-half_width, 2.0),
		Vector2(half_width, 2.0),
		Vector2(half_width * 0.35, -height),
		Vector2(-half_width * 0.35, -height)
	])
	draw_colored_polygon(pts, Color(0.65, 1.0, 0.95, 0.13 * alpha))
	draw_line(Vector2.ZERO, Vector2(0, -height), Color(1.0, 0.96, 0.72, 0.72 * alpha), 3.0)
	draw_line(Vector2(-5, -6), Vector2(-1, -height * 0.75), Color(0.45, 1.0, 0.9, 0.38 * alpha), 1.5)
	for i in range(6):
		var p := Vector2(sin(time * 18.0 + i) * 9.0, -float(i) * 11.0 - t * 16.0)
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.9, 0.45, 0.55 * alpha))
	draw_arc(Vector2.ZERO, 20.0 + alpha * 8.0, time * 7.0, time * 7.0 + PI * 1.25, 24, Color(0.45, 1.0, 0.9, 0.45 * alpha), 2.0)

func _draw_links() -> void:
	var alpha_max := 0.22
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and comfort.has_method("get_link_alpha_max"):
		alpha_max = float(comfort.get_link_alpha_max()) * 0.75

	# Cap: only show the first 4 links per disruptor to avoid fan-of-lines overload.
	var draw_count := mini(links.size(), 4)
	var phase := fmod(time * 38.0, 14.0)  # dash animation offset

	for i in range(draw_count):
		var target = links[i]
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var local_target := to_local((target as Node2D).global_position)
		var dist := local_target.length()
		if dist < 1.0:
			continue
		var dir := local_target / dist
		var c := Color(beam_color.r, beam_color.g, beam_color.b, alpha_max)

		# Animated dashes: short segments moving from disruptor toward tower.
		var dash := 7.0
		var gap  := 7.0
		var p    := fmod(phase, dash + gap)
		while p < dist:
			var seg_end := minf(p + dash, dist)
			var fade    := 1.0 - (p / dist) * 0.55   # far end fades out
			draw_line(dir * p, dir * seg_end,
				Color(c.r, c.g, c.b, c.a * 0.20 * fade), 2.5, true)  # soft glow
			draw_line(dir * p, dir * seg_end,
				Color(c.r, c.g, c.b, c.a * fade), 1.0, true)          # crisp core
			p += dash + gap

		# Small pulse dot at origin and target endpoint.
		var pulse := 0.55 + sin(time * 9.0) * 0.35
		draw_circle(Vector2.ZERO, 2.5 * pulse, Color(c.r, c.g, c.b, 0.55))
		draw_circle(local_target,  2.0 * pulse, Color(c.r, c.g, c.b, 0.40))

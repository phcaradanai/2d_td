extends Node2D
class_name TowerConstructionComponent

signal finished(mode: String, payload: Dictionary)

var active: bool = false
var mode: String = ""
var duration: float = 0.0
var remaining: float = 0.0
var payload: Dictionary = {}
var _redraw_timer: float = 0.0

const REDRAW_INTERVAL := 0.083

func start(p_mode: String, p_duration: float, p_payload: Dictionary = {}) -> void:
	mode = p_mode
	duration = maxf(0.01, p_duration)
	remaining = duration
	payload = p_payload.duplicate(true)
	active = true
	_redraw_timer = 0.0
	visible = true
	set_process(true)
	queue_redraw()

func cancel() -> void:
	active = false
	mode = ""
	payload.clear()
	visible = false
	set_process(false)
	queue_redraw()

func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(1.0 - (remaining / duration), 0.0, 1.0)

func _ready() -> void:
	z_index = 140
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	if not active:
		set_process(false)
		return
	remaining = maxf(0.0, remaining - delta)
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_INTERVAL
		queue_redraw()
	if remaining > 0.0:
		return
	var finished_mode := mode
	var finished_payload := payload.duplicate(true)
	cancel()
	finished.emit(finished_mode, finished_payload)

func _draw() -> void:
	if not active:
		return
	var p := progress()
	var ring_color := Color(0.30, 0.95, 1.00, 0.86)
	if mode == "upgrade":
		ring_color = Color(1.00, 0.72, 0.26, 0.90)
	var base_color := Color(0.02, 0.04, 0.06, 0.72)
	var radius := 34.0
	draw_circle(Vector2.ZERO, radius, Color(ring_color.r, ring_color.g, ring_color.b, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, base_color, 4.0, true)
	draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * p, 48, ring_color, 4.0, true)
	for i in range(4):
		var a := (TAU * float(i) / 4.0) + (Time.get_ticks_msec() * 0.0018)
		var inner := Vector2.RIGHT.rotated(a) * 18.0
		var outer := Vector2.RIGHT.rotated(a) * 28.0
		draw_line(inner, outer, Color(ring_color.r, ring_color.g, ring_color.b, 0.55), 2.0, true)

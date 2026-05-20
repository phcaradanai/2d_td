class_name CatalogPerformanceMonitor
extends Node

var _fps_label: Label = null
var _process_label: Label = null
var _drawn_label: Label = null
var _nodes_label: Label = null
var _active_label: Label = null
var _active_preview_count: Callable = Callable()
var _sample_timer: Timer = null

func setup(labels: Dictionary, active_preview_count: Callable) -> void:
	_fps_label = labels.get("fps")
	_process_label = labels.get("process")
	_drawn_label = labels.get("drawn")
	_nodes_label = labels.get("nodes")
	_active_label = labels.get("active")
	_active_preview_count = active_preview_count
	_update_labels()

func _ready() -> void:
	_sample_timer = Timer.new()
	_sample_timer.wait_time = 0.35
	_sample_timer.one_shot = false
	_sample_timer.autostart = true
	_sample_timer.timeout.connect(_update_labels)
	add_child(_sample_timer)

func _update_labels() -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _process_label:
		var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_process_label.text = "Process: %.1f ms" % process_ms
	if _drawn_label:
		var drawn := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_drawn_label.text = "Drawn: %d" % drawn
	if _nodes_label:
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_nodes_label.text = "Nodes: %d" % nodes
	if _active_label:
		var active := 0
		if _active_preview_count.is_valid():
			active = int(_active_preview_count.call())
		_active_label.text = "Active: %d" % active

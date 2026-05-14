extends Node2D

const IMPACT_SCENE: PackedScene = preload("res://scenes/effects/ImpactEffect.tscn")

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var core_color: Color = Color(0.44, 1.0, 0.24, 1.0)
var edge_color: Color = Color(0.48, 0.12, 0.78, 1.0)
var spore_color: Color = Color(0.65, 1.0, 0.32, 1.0)
var show_trail: bool = true
var trail_points: Array[Vector2] = []
var max_trail_points: int = 4

func setup(p_start: Vector2, p_end: Vector2, p_core: Color, p_edge: Color, p_spore: Color, quality_name: String = "HIGH") -> void:
	start_pos = p_start
	end_pos = p_end
	core_color = p_core
	edge_color = p_edge
	spore_color = p_spore
	show_trail = quality_name != "LOW"
	max_trail_points = 3 if quality_name == "MED" else 4

func _ready() -> void:
	global_position = start_pos
	trail_points.clear()
	trail_points.append(global_position)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.tween_property(self, "global_position", end_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_spawn_toxic_impact)
	tween.tween_callback(queue_free)

func _process(_delta: float) -> void:
	if show_trail:
		if trail_points.is_empty() or trail_points.back().distance_to(global_position) >= 7.0:
			trail_points.append(global_position)
			if trail_points.size() > max_trail_points:
				trail_points.pop_front()
		queue_redraw()

func _draw() -> void:
	if show_trail and trail_points.size() >= 2:
		for i in range(trail_points.size() - 1):
			var p1 := to_local(trail_points[i])
			var p2 := to_local(trail_points[i + 1])
			var alpha := float(i + 1) / float(trail_points.size())
			draw_line(p1, p2, Color(edge_color.r, edge_color.g, edge_color.b, 0.22 * alpha), 4.0 * alpha, true)
			draw_line(p1, p2, Color(core_color.r, core_color.g, core_color.b, 0.34 * alpha), 1.6 * alpha, true)
	draw_circle(Vector2.ZERO, 4.6, Color(edge_color.r, edge_color.g, edge_color.b, 0.68))
	draw_circle(Vector2.ZERO, 2.8, core_color)
	draw_circle(Vector2(2.0, -1.0), 1.1, spore_color)

func _spawn_toxic_impact() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		parent_node = get_tree().current_scene
	if parent_node == null:
		return
	var impact = IMPACT_SCENE.instantiate()
	parent_node.add_child(impact)
	impact.global_position = end_pos
	if impact.has_method("setup"):
		impact.setup(core_color, 0.82, "toxic_bloom", edge_color, spore_color)

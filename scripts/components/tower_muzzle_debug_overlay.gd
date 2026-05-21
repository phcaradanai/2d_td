extends Node2D
class_name TowerMuzzleDebugOverlay

const REDRAW_INTERVAL := 0.05
const MUZZLE_COLOR := Color(0.2, 0.95, 1.0, 0.95)
const TARGET_COLOR := Color(1.0, 0.72, 0.18, 0.90)
const LINE_COLOR := Color(0.2, 0.95, 1.0, 0.36)

var tower: Node2D = null
var _redraw_timer := 0.0

func setup(p_tower: Node2D) -> void:
	tower = p_tower
	z_index = 2200
	set_active(false)

func set_active(value: bool) -> void:
	visible = value
	set_process(value)
	if value:
		queue_redraw()

func _process(delta: float) -> void:
	_redraw_timer += delta
	if _redraw_timer < REDRAW_INTERVAL:
		return
	_redraw_timer = 0.0
	queue_redraw()

func _draw() -> void:
	if not visible or tower == null or not is_instance_valid(tower):
		return
	if not tower.has_method("get_fire_origin"):
		return

	var muzzle_pos: Vector2 = tower.get_fire_origin()
	var local_muzzle := to_local(muzzle_pos)
	draw_circle(local_muzzle, 3.5, Color(0.0, 0.0, 0.0, 0.75))
	draw_circle(local_muzzle, 2.2, MUZZLE_COLOR)
	draw_arc(local_muzzle, 6.0, 0.0, TAU, 16, MUZZLE_COLOR, 1.0, true)

	var target = tower.get("current_target")
	if target == null or not is_instance_valid(target):
		return

	var target_pos := _get_target_pos(target)
	var local_target := to_local(target_pos)
	draw_line(local_muzzle, local_target, LINE_COLOR, 1.4, true)
	draw_circle(local_target, 4.0, Color(0.0, 0.0, 0.0, 0.70))
	draw_circle(local_target, 2.4, TARGET_COLOR)

func _get_target_pos(target: Variant) -> Vector2:
	if tower != null and tower.has_method("get_target_hit_anchor_global_position"):
		return tower.get_target_hit_anchor_global_position(target)
	if target.has_method("get_hit_anchor_global_position"):
		return target.get_hit_anchor_global_position()
	if target.has_method("get_hit_origin"):
		return target.get_hit_origin()
	if target.has_method("get_aim_point"):
		return target.get_aim_point()
	if target is Node2D:
		return target.global_position
	return Vector2.ZERO

class_name EnemyBossMarker
extends RefCounted

const GOLD := Color(1.0, 0.78, 0.18, 0.95)
const GOLD_DARK := Color(0.18, 0.10, 0.02, 0.82)
const GEM := Color(0.55, 0.92, 1.0, 0.95)

static func is_boss(enemy: Node2D) -> bool:
	if bool(enemy.get("is_boss_unit")):
		return true
	var enemy_type := str(enemy.get("enemy_type"))
	if enemy_type == "boss" or enemy_type.begins_with("boss_"):
		return true
	var tags = enemy.get("tags")
	return tags is Array and (tags as Array).has("boss")

static func draw_crown(enemy: Node2D, body_size: float, anchor: Vector2 = Vector2.ZERO) -> void:
	var w := body_size * 0.78
	var h := body_size * 0.38
	var y := -body_size * 1.15
	var center := anchor + Vector2(0.0, y)
	var pts := PackedVector2Array([
		center + Vector2(-w * 0.55, h * 0.28),
		center + Vector2(-w * 0.42, -h * 0.35),
		center + Vector2(-w * 0.18, h * 0.08),
		center + Vector2(0.0, -h * 0.58),
		center + Vector2(w * 0.18, h * 0.08),
		center + Vector2(w * 0.42, -h * 0.35),
		center + Vector2(w * 0.55, h * 0.28),
		center + Vector2(w * 0.48, h * 0.56),
		center + Vector2(-w * 0.48, h * 0.56),
	])
	var closed := pts + PackedVector2Array([pts[0]])
	enemy.draw_polyline(closed, GOLD_DARK, 3.2, true)
	enemy.draw_colored_polygon(pts, GOLD)
	enemy.draw_polyline(closed, Color(1.0, 0.92, 0.45, 0.95), 1.25, true)
	enemy.draw_circle(center + Vector2(0.0, -h * 0.04), maxf(1.6, body_size * 0.08), GEM)
	enemy.draw_circle(center + Vector2(-w * 0.42, -h * 0.30), maxf(1.2, body_size * 0.055), Color(1.0, 0.95, 0.58, 0.95))
	enemy.draw_circle(center + Vector2(w * 0.42, -h * 0.30), maxf(1.2, body_size * 0.055), Color(1.0, 0.95, 0.58, 0.95))

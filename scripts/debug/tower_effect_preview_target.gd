# scripts/debug/tower_effect_preview_target.gd
class_name DummyTowerPreview
extends Node2D

var tower_id: String = ""
var _color: Color = Color.WHITE

func setup(p_tower_id: String, p_color: Color) -> void:
	tower_id = p_tower_id
	_color = p_color

func get_fire_origin() -> Vector2:
	return global_position

func _get_tower_color() -> Color:
	return _color

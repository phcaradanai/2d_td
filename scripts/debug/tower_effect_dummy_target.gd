# scripts/debug/tower_effect_dummy_target.gd
class_name DummyTargetPreview
extends Node2D

func get_hit_origin() -> Vector2:
	return global_position

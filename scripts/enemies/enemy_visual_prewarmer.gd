## EnemyVisualPrewarmer — renders every enemy visual_type × health_state once
## to force Godot to compile all canvas shaders before gameplay starts.
## Add as a child of main scene, call start(), await done signal.
extends Node2D

signal done

const ROUTER := preload("res://scripts/enemies/enemy_visual_router.gd")

const VISUAL_TYPES := [
	"basic", "fast", "tank", "bulwark", "hunter", "swarm",
	"runner", "shieldbearer", "healer", "splitter", "cloaked",
	"flyer", "fast_flyer", "armored_flyer", "disruptor",
]
const HEALTH_STATES := [0, 1, 2]   # OK, DAMAGED, CRITICAL
const SLOW_STATES   := [0.0, 0.5]  # no-slow, slowed

var _items: Array = []

func start() -> void:
	visible = false
	_build_items()
	# One frame to register items, one to render, then clean up.
	await get_tree().process_frame
	await get_tree().process_frame
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	done.emit()
	queue_free()

func _build_items() -> void:
	for vt in VISUAL_TYPES:
		for hs in HEALTH_STATES:
			for slow in SLOW_STATES:
				var item := _DummyEnemy.new()
				item.visual_type          = vt
				item.health_visual_state  = hs
				item.active_slow_percent  = slow
				item.PERFORMANCE_VISUAL_MODE = true
				add_child(item)
				item.queue_redraw()
				_items.append(item)

# ── Inner class: minimal CanvasItem that exposes the enemy draw interface ──

class _DummyEnemy extends Node2D:
	var visual_type:            String  = "basic"
	var health_visual_state:    int     = 0
	var active_slow_percent:    float   = 0.0
	var shield_remaining:       float   = 0.0
	var is_flashing:            bool    = false
	var hit_flash_color:        Color   = Color.WHITE
	var hit_flash_alpha:        float   = 0.0
	var pulse_time:             float   = 0.0
	var PERFORMANCE_VISUAL_MODE: bool   = true

	func _draw() -> void:
		ROUTER.draw_enemy(self)

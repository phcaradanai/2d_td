class_name DamageNumber
extends Node2D

## Maximum simultaneously active damage-number labels.
## Past this cap, new numbers are skipped — gameplay totals are unaffected.
const MAX_ACTIVE: int = 20
static var _active_count: int = 0

@export var duration: float = 0.6
@export var travel_distance: float = 40.0
@export var fade_delay: float = 0.3

@onready var label: Label = get_node_or_null("Label") as Label

var pending_text: String = "-0"
var pending_color: Color = Color.WHITE
var pending_font_size: int = 18
var _counted: bool = false
var _active_tween: Tween = null

func setup(amount: int, color: Color = Color.WHITE) -> void:
	setup_text("-" + str(amount), color, 18)

func setup_text(text: String, color: Color = Color.WHITE, font_size: int = 14) -> void:
	_begin_pooled_lifecycle()
	pending_text = text
	pending_color = color
	pending_font_size = font_size
	_apply_label_style()

func _ready() -> void:
	if PerformanceFirebreak.disable_damage_numbers:
		_release_to_pool()
		return
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-64, -18)
		label.size = Vector2(128, 36)
		add_child(label)

	_apply_label_style()
	if not has_meta("pooled"):
		_begin_pooled_lifecycle()

func _begin_pooled_lifecycle() -> void:
	if _counted:
		return
	_counted = true
	DamageNumber._active_count += 1
	visible = true
	set_process(true)
	modulate = Color.WHITE
	scale = Vector2(0.5, 0.5)
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	# Move up relative to starting position
	# Using position here works because it's relative to the parent (EffectsContainer)
	# And we set global_position just after add_child in the caller.
	_active_tween.tween_property(self, "position:y", position.y - travel_distance, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# Scale pop
	_active_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)

	# Fade out
	_active_tween.tween_property(self, "modulate:a", 0.0, duration - fade_delay)\
		.set_delay(fade_delay)
	
	_active_tween.chain().tween_callback(_on_expire)

func _on_expire() -> void:
	_release_to_pool()

func _release_to_pool() -> void:
	if _counted:
		_counted = false
		DamageNumber._active_count = maxi(0, DamageNumber._active_count - 1)
	var pool := get_node_or_null("/root/VisualEffectPoolService")
	if pool != null and pool.has_method("release"):
		pool.release(self)
	else:
		call_deferred("free")

func reset_for_pool() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	# Decrement the static active counter when the pool reclaims this node externally
	# (e.g. via release_active() on level restart), since _release_to_pool won't be called.
	if _counted:
		_counted = false
		DamageNumber._active_count = maxi(0, DamageNumber._active_count - 1)
	pending_text = "-0"
	pending_color = Color.WHITE
	pending_font_size = 18
	position = Vector2.ZERO
	scale = Vector2.ONE
	modulate = Color.WHITE

func _apply_label_style() -> void:
	if label == null:
		return
	label.text = pending_text
	label.add_theme_color_override("font_color", pending_color)
	label.add_theme_font_size_override("font_size", pending_font_size)

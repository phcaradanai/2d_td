extends Node2D

@export var duration: float = 0.6
@export var travel_distance: float = 40.0
@export var fade_delay: float = 0.3

@onready var label: Label = get_node_or_null("Label") as Label

func setup(amount: int, color: Color = Color.WHITE) -> void:
	if label:
		label.text = "-" + str(amount)
		label.add_theme_color_override("font_color", color)

func _ready() -> void:
	if label == null:
		label = Label.new()
		label.name = "Label"
		label.text = "-0"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-40, -18)
		label.size = Vector2(80, 36)
		add_child(label)

	var tween = create_tween()
	tween.set_parallel(true)
	
	# Move up relative to starting position
	# Using position here works because it's relative to the parent (EffectsContainer)
	# And we set global_position just after add_child in the caller.
	tween.tween_property(self, "position:y", position.y - travel_distance, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
	
	# Scale pop
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)

	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, duration - fade_delay)\
		.set_delay(fade_delay)
	
	tween.chain().tween_callback(queue_free)

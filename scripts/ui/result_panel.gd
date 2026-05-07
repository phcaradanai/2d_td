extends PanelContainer

signal retry_pressed()
signal next_level_pressed()
signal level_select_pressed()

@onready var result_title: Label = %ResultTitle
@onready var record_feedback: Label = %RecordFeedback
@onready var score_label: Label = %ScoreValue
@onready var stars_container: HBoxContainer = %StarsContainer
@onready var perfect_clear_badge: PanelContainer = %PerfectBadge
@onready var lives_label: Label = %LivesValue
@onready var gold_label: Label = %GoldValue
@onready var waves_label: Label = %WavesValue
@onready var enemies_label: Label = %EnemiesValue
@onready var time_label: Label = %TimeValue
@onready var rank_label: Label = %RankLabel

@onready var retry_button: Button = %RetryButton
@onready var next_button: Button = %NextButton
@onready var menu_button: Button = %MenuButton

var target_score: int = 0
var current_display_score: int = 0
var animation_tween: Tween
var record_tween: Tween # New: Track feedback loop tween

func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())
	next_button.pressed.connect(func(): next_level_pressed.emit())
	menu_button.pressed.connect(func(): level_select_pressed.emit())
	
	# Initial state
	modulate.a = 0
	scale = Vector2(0.8, 0.8)
	pivot_offset = size / 2.0
	if record_feedback: record_feedback.visible = false

func show_result(summary: Dictionary, improvements: Dictionary = {}, rank: int = -1) -> void:
	if animation_tween:
		animation_tween.kill()
	if record_tween:
		record_tween.kill()
	
	# Setup data
	var is_victory = summary.get("result", "") == "Victory"
	result_title.text = "LEVEL CLEAR" if is_victory else "DEFEAT"
	result_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0) if is_victory else Color(1.0, 0.3, 0.3))
	
	# Rank feedback
	if rank > 0:
		rank_label.text = "RANK: #%d" % rank
		rank_label.show()
	else:
		rank_label.hide()
		
	# Record feedback
	_setup_record_feedback(improvements)
	
	target_score = summary.get("score", 0)
	current_display_score = 0
	score_label.text = "0"
	
	lives_label.text = str(summary.get("lives", 0)) + " / " + str(summary.get("starting_lives", 20))
	gold_label.text = str(summary.get("gold_remaining", 0))
	waves_label.text = str(summary.get("waves_completed", 0)) + " / " + str(summary.get("total_waves", 0))
	enemies_label.text = str(summary.get("enemies_killed", 0))
	time_label.text = _format_time(summary.get("clear_time", 0))
	
	perfect_clear_badge.visible = summary.get("is_perfect", false)
	next_button.visible = is_victory
	
	# Reset stars
	for star in stars_container.get_children():
		if star.has_method("set"):
			star.filled = false
		star.modulate.a = 0.3 # Dim base
		star.scale = Vector2.ONE
	
	# Show panel animation
	visible = true
	animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation_tween.tween_property(self, "modulate:a", 1.0, 0.4)
	animation_tween.tween_property(self, "scale", Vector2.ONE, 0.5)
	
	# Score counting animation
	var count_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	count_tween.tween_method(_update_score_display, 0, target_score, 1.5)
	
	# Star reveal animation
	var stars_count = summary.get("stars", 0)
	var star_delay = 0.6
	for i in range(stars_count):
		var star = stars_container.get_child(i)
		var star_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		star_tween.tween_interval(star_delay + (i * 0.4))
		star_tween.tween_callback(func(): 
			if star.has_method("set"):
				star.filled = true
			_play_star_sound(i)
		)
		star_tween.parallel().tween_property(star, "modulate:a", 1.0, 0.2)
		star_tween.parallel().tween_property(star, "scale", Vector2(1.5, 1.5), 0.2)
		star_tween.tween_property(star, "scale", Vector2.ONE, 0.2)

	if OS.is_debug_build():
		print("[ResultPanel] shown for level result. score=%d stars=%d" % [target_score, stars_count])

func _update_score_display(value: int) -> void:
	score_label.text = str(value)

func _play_star_sound(_index: int) -> void:
	# Placeholder for sound effect if available
	pass

func _setup_record_feedback(improvements: Dictionary) -> void:
	if not record_feedback: return
	
	var messages = []
	if improvements.get("new_perfect_clear", false):
		messages.append("PERFECT CLEAR ACHIEVED!")
	elif improvements.get("new_best_stars", false):
		messages.append("NEW STAR RECORD!")
	
	if improvements.get("new_best_score", false):
		messages.append("NEW BEST SCORE!")
		
	if messages.size() > 0:
		record_feedback.text = messages[0]
		record_feedback.visible = true
		if record_tween:
			record_tween.kill()
		record_tween = create_tween().set_loops()
		record_tween.tween_property(record_feedback, "modulate:a", 1.0, 0.5)
		record_tween.tween_interval(1.0)
		record_tween.tween_property(record_feedback, "modulate:a", 0.0, 0.5)
		record_tween.tween_callback(func():
			var current_idx = messages.find(record_feedback.text)
			var next_idx = (current_idx + 1) % messages.size()
			record_feedback.text = messages[next_idx]
		)
	else:
		if record_tween:
			record_tween.kill()
		record_feedback.visible = false

func _format_time(seconds: int) -> String:
	var mins = int(seconds / 60)
	var secs = int(seconds % 60)
	return "%02d:%02d" % [mins, secs]

func hide_result() -> void:
	if animation_tween:
		animation_tween.kill()
	if record_tween:
		record_tween.kill()
	
	animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	animation_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	animation_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	animation_tween.tween_callback(func(): visible = false)

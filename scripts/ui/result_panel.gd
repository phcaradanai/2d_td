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
var current_report_data: Dictionary = {} # Store finalized telemetry for debug popup

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
	
	current_report_data = summary.duplicate()
	# Merge telemetry metrics if available (must do this BEFORE any cleanup/reset)
	var gm = get_tree().current_scene.get_node_or_null("GameManager")
	if gm and "battle_telemetry" in gm and gm.battle_telemetry:
		var m = gm.battle_telemetry.get_summary()
		if not m.is_empty():
			for key in m:
				current_report_data[key] = m[key]
		if OS.is_debug_build():
			print("[REPORT_UI] Stored report data. Keys count: %d" % current_report_data.size())
	
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
	_setup_record_feedback(improvements, summary)
	
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

func _setup_record_feedback(improvements: Dictionary, summary: Dictionary = {}) -> void:
	if not record_feedback: return
	
	var messages = []
	if improvements.get("new_perfect_clear", false):
		messages.append("PERFECT CLEAR ACHIEVED!")
	elif improvements.get("new_best_stars", false):
		messages.append("NEW STAR RECORD!")
	
	if improvements.get("new_best_score", false):
		messages.append("NEW BEST SCORE!")
		
	if summary.has("gold_spent") and summary.has("gold_earned"):
		var spent = summary.get("gold_spent", 0)
		var earned = summary.get("gold_earned", 1)
		if earned <= 0: earned = 1
		var efficiency = float(spent) / float(earned) * 100.0
		messages.append("GOLD EFFICIENCY: %d%%" % int(efficiency))
		
	if not current_report_data.is_empty():
		var m = current_report_data
		var best_tower = ""
		var max_dmg = 0.0
		for t_id in m.get("damage_by_tower_type", {}):
			if m["damage_by_tower_type"][t_id] > max_dmg:
				max_dmg = m["damage_by_tower_type"][t_id]
				best_tower = t_id
		if best_tower != "":
			messages.append("MVP TOWER: " + best_tower.to_upper().replace("_TOWER", ""))
			
		var total_leaks = m.get("enemies_leaked_total", 0)
		if total_leaks > 0:
			var top_leak = ""
			var max_leaks = 0
			for etype in m.get("enemies_leaked_by_type", {}):
				if m["enemies_leaked_by_type"][etype] > max_leaks:
					max_leaks = m["enemies_leaked_by_type"][etype]
					top_leak = etype
			messages.append(str(total_leaks) + " LEAKS (" + top_leak.to_upper() + ")")
		
		# Debug: Prepare the detailed summary report but keep it hidden by default
		if OS.is_debug_build():
			_prepare_debug_telemetry_report(current_report_data)
		else:
			var btn = get_node_or_null("MarginContainer/VBoxContainer/ButtonsVBox/DebugReportButton")
			if btn: btn.hide()
		
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

func _prepare_debug_telemetry_report(m: Dictionary) -> void:
	# 1. Create/Find the Balance Report Button
	var buttons_vbox = get_node_or_null("MarginContainer/VBoxContainer/ButtonsVBox")
	if not buttons_vbox: return
	
	var debug_btn = buttons_vbox.get_node_or_null("DebugReportButton")
	if not debug_btn:
		debug_btn = Button.new()
		debug_btn.name = "DebugReportButton"
		debug_btn.text = "VIEW BALANCE REPORT"
		debug_btn.custom_minimum_size.y = 40
		debug_btn.add_theme_font_size_override("font_size", 14)
		debug_btn.modulate = Color(0.6, 0.8, 1.0)
		buttons_vbox.add_child(debug_btn)
		debug_btn.pressed.connect(_toggle_debug_report_popup)
	
	debug_btn.show()
	
	# 2. Create/Find the Popup Panel
	var popup = get_node_or_null("DebugReportPopup")
	if not popup:
		popup = PanelContainer.new()
		popup.name = "DebugReportPopup"
		# Styling for the popup
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.08, 0.1, 0.95)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.2, 0.5, 0.8, 0.8)
		style.set_corner_radius_all(8)
		popup.add_theme_stylebox_override("panel", style)
		
		# Layout inside popup
		var p_margin = MarginContainer.new()
		p_margin.add_theme_constant_override("margin_left", 20)
		p_margin.add_theme_constant_override("margin_top", 20)
		p_margin.add_theme_constant_override("margin_right", 20)
		p_margin.add_theme_constant_override("margin_bottom", 20)
		popup.add_child(p_margin)
		
		var p_vbox = VBoxContainer.new()
		p_vbox.add_theme_constant_override("separation", 15)
		p_margin.add_child(p_vbox)
		
		var p_title = Label.new()
		p_title.text = "BATTLE TELEMETRY / BALANCE REPORT"
		p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p_title.add_theme_font_size_override("font_size", 18)
		p_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		p_vbox.add_child(p_title)
		
		var p_scroll = ScrollContainer.new()
		p_scroll.custom_minimum_size = Vector2(400, 300)
		p_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		p_vbox.add_child(p_scroll)
		
		var p_label = RichTextLabel.new()
		p_label.name = "ReportContent"
		p_label.bbcode_enabled = true
		p_label.fit_content = true
		p_label.selection_enabled = true # Allow selecting text in debug
		p_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_scroll.add_child(p_label)
		
		var p_close = Button.new()
		p_close.text = "CLOSE REPORT"
		p_close.custom_minimum_size.y = 40
		p_vbox.add_child(p_close)
		p_close.pressed.connect(func(): popup.hide())
		
		add_child(popup)
		popup.hide()
		
		# VERY IMPORTANT: Independent from PanelContainer layout
		popup.set_as_top_level(true)
		
		# Center the popup over the screen
		popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		popup.offset_left = -250
		popup.offset_top = -280
		popup.offset_right = 250
		popup.offset_bottom = 280
	
	# 3. Populate Content immediately
	_update_report_content(popup, m)

	if OS.is_debug_build():
		print("[REPORT_UI] debug_report_ready=true level=%s" % m.get("level_id", "unknown"))

func _toggle_debug_report_popup() -> void:
	var popup = get_node_or_null("DebugReportPopup")
	if popup:
		popup.visible = not popup.visible
		if popup.visible:
			popup.move_to_front()
			_update_report_content(popup, current_report_data)
			
			if OS.is_debug_build():
				var level_id = current_report_data.get("level_id", "unknown")
				print("[REPORT_UI] opening balance report for level=%s" % level_id)

func _update_report_content(popup_node: PanelContainer, data: Dictionary) -> void:
	# Use a more reliable path finding
	var p_label = popup_node.find_child("ReportContent", true, false)
	if p_label:
		if data.is_empty() or data.size() < 5: # Basic check for meaningful data
			p_label.text = "[center][color=gray]No detailed telemetry data found.\nCheck console for [BATTLE_REPORT].[/color][/center]"
			if OS.is_debug_build(): print("[REPORT_UI] Warning: Data dictionary too small or empty")
		else:
			p_label.text = _format_bbcode_report(data)
			if OS.is_debug_build():
				print("[REPORT_UI] Refreshed report content. Text length: %d" % p_label.text.length())
	else:
		if OS.is_debug_build(): print("[REPORT_UI] Error: Could not find ReportContent node")

func _format_bbcode_report(m: Dictionary) -> String:
	var t = "[center][b][color=#66ccff]SESSION SUMMARY[/color][/b][/center]\n\n"
	t += "[color=#aaaaaa]Level:[/color] %s\n" % m.get("level_id", "unknown")
	t += "[color=#aaaaaa]Result:[/color] %s\n" % m.get("result", "abandoned")
	t += "[color=#aaaaaa]Perfect Clear:[/color] %s\n" % str(m.get("perfect_clear", false))
	t += "[color=#aaaaaa]Time:[/color] %.1fs\n" % m.get("clear_time_sec", 0.0)
	t += "\n"
	
	t += "[b][color=#66ccff]ECONOMY[/color][/b]\n"
	t += "Start: %d\n" % m.get("gold_start", 0)
	t += "Earned: [color=#ffcc33]%d[/color] (Kills: %d, Waves: %d)\n" % [
		m.get("gold_earned_total", 0), m.get("gold_earned_from_kills", 0), m.get("gold_earned_from_waves", 0)
	]
	t += "Spent: [color=#ff6666]%d[/color] (Build: %d, Upgr: %d, Hero: %d)\n" % [
		m.get("gold_spent_total", 0), m.get("gold_spent_on_towers", 0), m.get("gold_spent_on_upgrades", 0), m.get("gold_spent_on_hero", 0)
	]
	t += "Remaining: [color=#66ff66]%d[/color]\n" % m.get("gold_remaining", 0)
	
	# Invariant check in UI
	var expected = m.get("gold_start", 0) + m.get("gold_earned_total", 0) - m.get("gold_spent_total", 0)
	if expected != m.get("gold_remaining", 0):
		t += "[color=#ff3333][b]MISMATCH: %d[/b][/color]\n" % (m.get("gold_remaining", 0) - expected)
	
	t += "\n"
	
	t += "[b][color=#66ccff]COMBAT STATS[/color][/b]\n"
	t += "MVP Tower: [b]%s[/b]\n" % _get_top_key(m.get("damage_by_tower_type", {}))
	t += "Total Kills: %d\n" % m.get("enemies_killed_total", 0)
	t += "Total Leaks: [color=#ff6666]%d[/color] (%s)\n" % [
		m.get("enemies_leaked_total", 0), _get_top_key(m.get("enemies_leaked_by_type", {}))
	]
	t += "\n"
	
	t += "[b][color=#66ccff]HERO IMPACT[/color][/b]\n"
	t += "Damage: %d | Kills: %d | Active: %.1fs\n" % [
		int(m.get("hero_damage", 0)), m.get("hero_kills", 0), m.get("hero_active_time_sec", 0.0)
	]
	
	t += "\n"
	
	# Danger Wave
	var danger_wave = 0
	var max_wave_leaks = 0
	for w_idx in m.get("wave_stats", {}):
		var w = m["wave_stats"][w_idx]
		var w_leaks = 0
		for count in w.get("enemies_leaked_by_type", {}).values():
			w_leaks += count
		if w_leaks > max_wave_leaks:
			max_wave_leaks = w_leaks
			danger_wave = int(w_idx)
	
	if danger_wave > 0:
		t += "[color=#ffaa66]Danger Wave:[/color] %d (%d leaks)\n" % [danger_wave, max_wave_leaks]
	else:
		t += "[color=#aaaaaa]Danger Wave:[/color] None\n"
	
	t += "\n"
	
	# Balance Analysis Section
	var ba = m.get("balance_analysis", {})
	if not ba.is_empty():
		t += "[center][b][color=#ffcc33]DESIGNER'S BALANCE ANALYSIS[/color][/b][/center]\n\n"
		
		var rating_color = "#66ff66" # Green for Good
		if ba.get("difficulty_rating") == "Too Easy": rating_color = "#66ccff" # Blue
		elif ba.get("difficulty_rating") == "Too Hard": rating_color = "#ff6666" # Red
		
		t += "Rating: [b][color=%s]%s[/color][/b]\n" % [rating_color, ba.get("difficulty_rating", "Unknown")]
		t += "Reason: %s\n" % ba.get("reason", "Balanced")
		t += "\n"
		
		t += "[b]Recommendations:[/b]\n"
		var actions = ba.get("recommended_actions", [])
		if actions.is_empty():
			t += "[color=#aaaaaa]- No changes needed.[/color]\n"
		else:
			for action in actions:
				t += "- %s\n" % action
	
	return t

func _get_top_key(dict: Dictionary) -> String:
	if dict.is_empty(): return "None"
	var top = "None"
	var max_val = -1.0
	for k in dict:
		if dict[k] > max_val:
			max_val = dict[k]
			top = k
	return top.replace("_tower", "").capitalize()

func hide_result() -> void:
	if animation_tween:
		animation_tween.kill()
	if record_tween:
		record_tween.kill()
	
	var popup = get_node_or_null("DebugReportPopup")
	if popup: popup.hide()
	
	animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	animation_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	animation_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.3)
	animation_tween.tween_callback(func(): visible = false)

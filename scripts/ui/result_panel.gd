extends PanelContainer

signal retry_pressed()
signal next_level_pressed()
signal level_select_pressed()

const TELEMETRY_REPORT_LOADER_SCRIPT_PATH := "res://scripts/debug/telemetry_report_loader.gd"
const BALANCE_PATCH_GENERATOR_SCRIPT_PATH := "res://scripts/debug/balance_patch_generator.gd"
const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")

@onready var result_title: Label = %ResultTitle
@onready var record_feedback: Label = %RecordFeedback
@onready var score_label: Label = %ScoreValue
@onready var stars_container: HBoxContainer = %StarsContainer
@onready var perfect_clear_badge: PanelContainer = %PerfectBadge
@onready var lives_label: Label = %LivesValue
@onready var gold_label: Label = %GoldValue
@onready var waves_label: Label = %WavesValue
@onready var enemies_label: Label = %EnemiesValue
@onready var leaked_label: Label = %LeakedValue
@onready var gold_spent_label: Label = %GoldSpentValue
@onready var mvp_tower_label: Label = %MVPTowerValue
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
var telemetry_report_loader = null
var balance_patch_generator = null
var balance_tool_aggregate: Dictionary = {}
var balance_tool_patch: Dictionary = {}
var balance_tool_preview_text: String = ""
var balance_tool_last_attempt: int = 0
var cosmetic_rewards_container: VBoxContainer = null

func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())
	next_button.pressed.connect(func(): next_level_pressed.emit())
	menu_button.pressed.connect(func(): level_select_pressed.emit())
	_hide_balance_tool_nodes()
	
	# Initial state
	modulate.a = 0
	scale = Vector2(0.8, 0.8)
	pivot_offset = size / 2.0
	if record_feedback: record_feedback.visible = false
	_ensure_cosmetic_rewards_container()

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

	var leaked = summary.get("enemies_leaked", 0)
	leaked_label.text = str(leaked)
	leaked_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if leaked > 0 else Color(0.3, 1.0, 0.5))

	gold_spent_label.text = str(summary.get("gold_spent", 0))

	var damage_map = current_report_data.get("damage_by_tower_type", {})
	mvp_tower_label.text = _get_top_key(damage_map) if not damage_map.is_empty() else "-"
	
	perfect_clear_badge.visible = summary.get("is_perfect", false)
	next_button.visible = is_victory
	_setup_cosmetic_rewards(improvements.get("new_cosmetics", []))
	
	# Reset stars
	for star in stars_container.get_children():
		if star.has_method("set"):
			star.filled = false
		star.modulate.a = 0.3 # Dim base
		star.scale = Vector2.ONE
	
	# Show panel animation
	visible = true
	animation_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation_tween.tween_property(self , "modulate:a", 1.0, 0.4)
	animation_tween.tween_property(self , "scale", Vector2.ONE, 0.5)
	
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
		var total_leaks = m.get("enemies_leaked_total", 0)
		if total_leaks > 0:
			var top_leak = ""
			var max_leaks = 0
			for etype in m.get("enemies_leaked_by_type", {}):
				if m["enemies_leaked_by_type"][etype] > max_leaks:
					max_leaks = m["enemies_leaked_by_type"][etype]
					top_leak = etype
			messages.append(str(total_leaks) + " LEAKS (" + top_leak.to_upper() + ")")

		_hide_balance_tool_nodes()
		
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

func _ensure_cosmetic_rewards_container() -> void:
	if cosmetic_rewards_container != null and is_instance_valid(cosmetic_rewards_container):
		return
	var root_vbox := get_node_or_null("MarginContainer/VBoxContainer")
	if root_vbox == null:
		return
	cosmetic_rewards_container = VBoxContainer.new()
	cosmetic_rewards_container.name = "CosmeticRewards"
	cosmetic_rewards_container.add_theme_constant_override("separation", 8)
	cosmetic_rewards_container.visible = false
	var buttons := root_vbox.get_node_or_null("ButtonsVBox")
	if buttons:
		root_vbox.add_child(cosmetic_rewards_container)
		root_vbox.move_child(cosmetic_rewards_container, buttons.get_index())
	else:
		root_vbox.add_child(cosmetic_rewards_container)

func _setup_cosmetic_rewards(rewards: Array) -> void:
	_ensure_cosmetic_rewards_container()
	if cosmetic_rewards_container == null:
		return
	for child in cosmetic_rewards_container.get_children():
		child.queue_free()
	cosmetic_rewards_container.visible = not rewards.is_empty()
	if rewards.is_empty():
		return
	var title := Label.new()
	title.text = "COSMETIC UNLOCKS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	cosmetic_rewards_container.add_child(title)
	for reward in rewards:
		if reward is Dictionary:
			cosmetic_rewards_container.add_child(_create_cosmetic_reward_card(reward))

func _create_cosmetic_reward_card(reward: Dictionary) -> Control:
	var registry := get_node_or_null("/root/CosmeticRegistry")
	var rarity := str(reward.get("rarity", "common"))
	var rarity_color := Color(0.4, 0.85, 1.0)
	var rarity_label := rarity.capitalize()
	if registry != null:
		rarity_color = registry.get_rarity_color(rarity)
		rarity_label = registry.get_rarity_label(rarity)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 74)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.94)
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var name := Label.new()
	name.text = str(reward.get("display_name", reward.get("id", "Cosmetic")))
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", Color.WHITE)
	text_box.add_child(name)
	var meta := Label.new()
	meta.text = "%s  ·  %s" % [rarity_label.to_upper(), _format_slot(str(reward.get("slot", "")))]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", rarity_color)
	text_box.add_child(meta)
	var equip := Button.new()
	equip.text = "EQUIP"
	equip.custom_minimum_size = Vector2(96, 34)
	equip.disabled = not _can_equip_reward(reward)
	equip.pressed.connect(func() -> void:
		var inventory := get_node_or_null("/root/CosmeticInventory")
		if inventory != null and inventory.has_method("equip"):
			inventory.equip(str(reward.get("tower_id", "")), str(reward.get("slot", "")), str(reward.get("id", "")))
			equip.text = "EQUIPPED"
			equip.disabled = true
	)
	row.add_child(equip)
	return panel

func _can_equip_reward(reward: Dictionary) -> bool:
	return str(reward.get("tower_id", "")) != "" and str(reward.get("slot", "")) != "" and str(reward.get("id", "")) != ""

func _format_slot(slot: String) -> String:
	return slot.replace("_", " ").capitalize()

func _format_time(seconds: int) -> String:
	var mins = int(float(seconds) / 60.0)
	var secs = int(seconds % 60)
	return "%02d:%02d" % [mins, secs]

func _hide_balance_tool_nodes() -> void:
	var names := [
		"DebugReportButton",
		"DebugAnalyzeButton",
		"DebugExportButton",
		"BalanceToolButton",
		"DebugReportPopup",
		"BalanceToolPopup"
	]
	for node_name in names:
		var node := find_child(node_name, true, false)
		if node:
			DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(node)
			if node is CanvasItem:
				node.hide()
			if node is BaseButton:
				node.disabled = true
			if node is Control:
				node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _prepare_debug_telemetry_report(m: Dictionary) -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Result Panel Balance Report"):
		_hide_balance_tool_nodes()
		return
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
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(debug_btn)
		debug_btn.pressed.connect(_toggle_debug_report_popup)
	
	debug_btn.show()
	
	# 1.5 Add Analyze & Export Buttons
	var analyze_btn = buttons_vbox.get_node_or_null("DebugAnalyzeButton")
	if not analyze_btn:
		analyze_btn = Button.new()
		analyze_btn.name = "DebugAnalyzeButton"
		analyze_btn.text = "ANALYZE ALL RUNS"
		analyze_btn.custom_minimum_size.y = 40
		analyze_btn.add_theme_font_size_override("font_size", 14)
		analyze_btn.modulate = Color(0.8, 1.0, 0.8)
		buttons_vbox.add_child(analyze_btn)
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(analyze_btn)
		analyze_btn.pressed.connect(func():
			if DEBUG_ACCESS_SCRIPT.block_balance_tool("Analyze Saved Reports"):
				return
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm and gm.battle_telemetry:
				gm.battle_telemetry.analyze_saved_reports(m.get("level_id", "unknown"))
		)
	analyze_btn.show()
	
	var export_btn = buttons_vbox.get_node_or_null("DebugExportButton")
	if not export_btn:
		export_btn = Button.new()
		export_btn.name = "DebugExportButton"
		export_btn.text = "EXPORT CSV SUMMARY"
		export_btn.custom_minimum_size.y = 40
		export_btn.add_theme_font_size_override("font_size", 14)
		export_btn.modulate = Color(1.0, 0.9, 0.6)
		buttons_vbox.add_child(export_btn)
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(export_btn)
		export_btn.pressed.connect(func():
			if DEBUG_ACCESS_SCRIPT.block_balance_tool("Export Telemetry Summary"):
				return
			var gm = get_tree().current_scene.get_node_or_null("GameManager")
			if gm and gm.battle_telemetry:
				gm.battle_telemetry.export_summary_csv(m.get("level_id", "unknown"))
		)
	export_btn.show()

	var balance_btn = buttons_vbox.get_node_or_null("BalanceToolButton")
	if not balance_btn:
		balance_btn = Button.new()
		balance_btn.name = "BalanceToolButton"
		balance_btn.text = "BALANCE TUNING TOOL"
		balance_btn.custom_minimum_size.y = 40
		balance_btn.add_theme_font_size_override("font_size", 14)
		balance_btn.modulate = Color(1.0, 0.72, 0.45)
		buttons_vbox.add_child(balance_btn)
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(balance_btn)
		balance_btn.pressed.connect(_toggle_balance_tool_popup)
	balance_btn.show()
	
	# 2. Create/Find the Popup Panel
	var popup = get_node_or_null("DebugReportPopup")
	if not popup:
		popup = PanelContainer.new()
		popup.name = "DebugReportPopup"
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(popup)
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

	_prepare_balance_tool_popup()

func _toggle_debug_report_popup() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Open Balance Report"):
		_hide_balance_tool_nodes()
		return
	var popup = get_node_or_null("DebugReportPopup")
	if popup:
		popup.visible = not popup.visible
		if popup.visible:
			popup.move_to_front()
			_update_report_content(popup, current_report_data)
			
			if OS.is_debug_build():
				var level_id = current_report_data.get("level_id", "unknown")
				print("[REPORT_UI] opening balance report for level=%s" % level_id)

func _toggle_balance_tool_popup() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Balance Tuning Tool"):
		_hide_balance_tool_nodes()
		return
	_prepare_balance_tool_popup()
	var popup = get_node_or_null("BalanceToolPopup")
	if popup:
		popup.visible = not popup.visible
		if popup.visible:
			popup.move_to_front()
			_refresh_balance_tool_summary()

func _prepare_balance_tool_popup() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Balance Tuning Tool"):
		_hide_balance_tool_nodes()
		return
	var popup = get_node_or_null("BalanceToolPopup")
	if popup:
		return

	popup = PanelContainer.new()
	popup.name = "BalanceToolPopup"
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(popup)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.055, 0.05, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.58, 0.28, 0.85)
	style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	popup.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "BALANCE TUNING TOOL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	vbox.add_child(title)

	var summary = RichTextLabel.new()
	summary.name = "BalanceSummary"
	summary.bbcode_enabled = true
	summary.fit_content = true
	summary.custom_minimum_size = Vector2(520, 115)
	vbox.add_child(summary)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	_add_balance_tool_button(grid, "Analyze Saved Reports", _on_balance_analyze_pressed)
	_add_balance_tool_button(grid, "Generate Balance Patch", _on_balance_generate_pressed)
	_add_balance_tool_button(grid, "Preview Patch", _on_balance_preview_pressed)
	_add_balance_tool_button(grid, "Apply Runtime Patch", _on_balance_apply_runtime_pressed)
	_add_balance_tool_button(grid, "Find Acceptable Patch", _on_balance_find_acceptable_pressed)
	_add_balance_tool_button(grid, "Apply File Patch", _on_balance_apply_file_pressed)
	_add_balance_tool_button(grid, "Run Dominant Strategy Test", _on_balance_dominant_test_pressed)
	_add_balance_tool_button(grid, "Run Mixed Defense Test", _on_balance_mixed_test_pressed)
	_add_balance_tool_button(grid, "Rollback Last Patch", _on_balance_rollback_pressed)
	_add_balance_tool_button(grid, "Export Patch JSON", _on_balance_export_pressed)

	var output_scroll = ScrollContainer.new()
	output_scroll.custom_minimum_size = Vector2(520, 260)
	output_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(output_scroll)

	var output = RichTextLabel.new()
	output.name = "BalanceOutput"
	output.bbcode_enabled = false
	output.fit_content = true
	output.selection_enabled = true
	output_scroll.add_child(output)

	var close = Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size.y = 36
	close.pressed.connect(func(): popup.hide())
	vbox.add_child(close)

	add_child(popup)
	popup.set_as_top_level(true)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.offset_left = -300
	popup.offset_top = -330
	popup.offset_right = 300
	popup.offset_bottom = 330
	popup.hide()

func _add_balance_tool_button(parent: Control, text: String, callable: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 34)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(button)
	button.pressed.connect(callable)
	parent.add_child(button)

func _refresh_balance_tool_summary() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Refresh Balance Tool Summary"):
		return
	var popup = get_node_or_null("BalanceToolPopup")
	if not popup:
		return
	var summary := popup.find_child("BalanceSummary", true, false) as RichTextLabel
	if not summary:
		return
	var level_id := _balance_level_id()
	var reports_count := int(balance_tool_aggregate.get("source_reports_count", 0))
	var latest_analysis: Dictionary = current_report_data.get("balance_analysis", {})
	var difficulty := str(balance_tool_aggregate.get("difficulty_rating", latest_analysis.get("difficulty_rating", "Unknown")))
	var risk := str(balance_tool_aggregate.get("dominant_strategy_risk", latest_analysis.get("dominant_strategy_risk", false)))
	var top_tower := str(balance_tool_aggregate.get("tower_dominance", latest_analysis.get("tower_dominance", _get_top_key(current_report_data.get("damage_by_tower_type", {})))))
	var gold_ratio := float(balance_tool_aggregate.get("gold_remaining_ratio", latest_analysis.get("gold_remaining_ratio", 0.0)))
	var acceptance: Dictionary = {}
	if balance_patch_generator:
		acceptance = balance_patch_generator.last_patch_acceptance
	var status := str(acceptance.get("status", "Rejected" if balance_tool_patch.is_empty() else "Pending")).capitalize().replace("_", " ")
	summary.text = "[b]level_id:[/b] %s\n[b]reports:[/b] %d  [b]difficulty:[/b] %s  [b]risk:[/b] %s\n[b]top tower:[/b] %s  [b]gold remaining:[/b] %.1f%%\n[b]Dominant Strategy:[/b] %s  [b]Mixed Defense:[/b] %s  [b]File Verify:[/b] %s\n[b]Patch Status:[/b] %s  [b]Last Attempt:[/b] %d" % [
		level_id,
		reports_count,
		difficulty,
		risk,
		top_tower,
		gold_ratio * 100.0,
		"PASS" if bool(acceptance.get("dominant_strategy_pass", false)) else "FAIL",
		"PASS" if bool(acceptance.get("mixed_defense_pass", false)) else "FAIL",
		"PASS" if bool(acceptance.get("file_verify_pass", false)) else "FAIL",
		status,
		balance_tool_last_attempt
	]

func _balance_set_output(text: String) -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Balance Tool Output"):
		return
	var popup = get_node_or_null("BalanceToolPopup")
	if popup:
		var output := popup.find_child("BalanceOutput", true, false) as RichTextLabel
		if output:
			output.text = text
	print(text)

func _balance_count_search_attempts(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		if line.begins_with("attempt="):
			count += 1
	return count

func _balance_level_id() -> String:
	var level_id := str(current_report_data.get("level_id", ""))
	if level_id == "":
		var gm = get_tree().current_scene
		if gm and "current_level_id" in gm:
			level_id = str(gm.current_level_id)
	if level_id == "":
		level_id = "unknown"
	return level_id

func _on_balance_analyze_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Analyze Saved Reports"):
		return
	if not telemetry_report_loader:
		return
	var level_id := _balance_level_id()
	balance_tool_aggregate = telemetry_report_loader.analyze_reports(level_id)
	var latest: Dictionary = telemetry_report_loader.get_latest_report(level_id)
	if not latest.is_empty():
		current_report_data = latest
	_refresh_balance_tool_summary()
	_balance_set_output("[TELEMETRY_AGGREGATE]\nlevel=%s\nruns=%d\ndifficulty_rating=%s\navg_gold_remaining_ratio=%.1f%%\ntower_dominance=%s\ntower_dominance_ratio=%.1f%%\ndominant_strategy_risk=%s" % [
		level_id,
		int(balance_tool_aggregate.get("source_reports_count", 0)),
		str(balance_tool_aggregate.get("difficulty_rating", "Unknown")),
		float(balance_tool_aggregate.get("gold_remaining_ratio", 0.0)) * 100.0,
		str(balance_tool_aggregate.get("tower_dominance", "None")),
		float(balance_tool_aggregate.get("tower_dominance_ratio", 0.0)) * 100.0,
		str(balance_tool_aggregate.get("dominant_strategy_risk", false))
	])

func _on_balance_generate_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Generate Balance Patch"):
		return
	if not balance_patch_generator:
		return
	var level_id := _balance_level_id()
	if balance_tool_aggregate.is_empty() and telemetry_report_loader:
		balance_tool_aggregate = telemetry_report_loader.analyze_reports(level_id)
	var latest: Dictionary = current_report_data
	if telemetry_report_loader:
		var loaded_latest: Dictionary = telemetry_report_loader.get_latest_report(level_id)
		if not loaded_latest.is_empty():
			latest = loaded_latest
	balance_tool_patch = balance_patch_generator.generate_patch(level_id, balance_tool_aggregate, latest)
	balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_refresh_balance_tool_summary()
	_balance_set_output(JSON.stringify(balance_tool_patch, "\t"))

func _on_balance_preview_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Preview Balance Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_balance_set_output(balance_tool_preview_text)

func _on_balance_apply_runtime_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply Runtime Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	var ok: bool = balance_patch_generator.apply_runtime_patch(balance_tool_patch, wm)
	if not ok and not balance_patch_generator.last_stage_2_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_stage_2_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	if not ok and not balance_patch_generator.last_softened_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_softened_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_refresh_balance_tool_summary()
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_find_acceptable_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Find Acceptable Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	var accepted: Dictionary = balance_patch_generator.find_acceptable_patch(balance_tool_patch, wm)
	balance_tool_last_attempt = _balance_count_search_attempts(balance_patch_generator.last_operation_log)
	if not accepted.is_empty():
		balance_tool_patch = accepted
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	elif not balance_patch_generator.last_softened_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_softened_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	elif not balance_patch_generator.last_stage_2_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_stage_2_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_refresh_balance_tool_summary()
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_apply_file_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply File Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var ok: bool = balance_patch_generator.apply_patch(balance_tool_patch)
	if not ok and not balance_patch_generator.last_stage_2_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_stage_2_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	if not ok and not balance_patch_generator.last_softened_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_softened_patch
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_refresh_balance_tool_summary()
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_dominant_test_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Run Dominant Strategy Test"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	var output: String = balance_patch_generator.run_dominant_strategy_test(_balance_level_id(), balance_tool_patch, wm)
	if "verdict=FAIL" in output:
		balance_tool_patch = balance_patch_generator.generate_stage_2_patch(balance_tool_patch)
		output += "\n" + balance_patch_generator.preview_patch(balance_tool_patch)
	_balance_set_output(output)

func _on_balance_mixed_test_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Run Mixed Defense Test"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	_balance_set_output(balance_patch_generator.run_mixed_defense_test(_balance_level_id(), balance_tool_patch, wm))

func _on_balance_rollback_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Rollback Last Patch"):
		return
	balance_patch_generator.rollback_last_patch(_balance_level_id())
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_export_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Export Patch JSON"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	var path: String = balance_patch_generator.export_patch_json(balance_tool_patch)
	_balance_set_output("[BALANCE_PATCH_EXPORT]\npath=%s\n%s" % [path, "error=" + balance_patch_generator.last_error if path == "" else "saved=true"])

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
	t += "Spent: [color=#ff6666]%d[/color] (Build: %d, Upgr: %d)\n" % [
		m.get("gold_spent_total", 0), m.get("gold_spent_on_towers", 0), m.get("gold_spent_on_upgrades", 0)
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
	animation_tween.tween_property(self , "modulate:a", 0.0, 0.3)
	animation_tween.tween_property(self , "scale", Vector2(0.8, 0.8), 0.3)
	animation_tween.tween_callback(func(): visible = false)

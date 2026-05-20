extends CanvasLayer

signal add_gold_requested(amount: int)
signal start_next_wave_requested()
signal kill_all_enemies_requested()
signal clear_projectiles_requested()
signal trigger_victory_requested()
signal trigger_game_over_requested()
signal restart_requested()
signal god_mode_toggled(enabled: bool)
signal hard_audio_test_requested()
signal test_sfx_requested()
signal test_music_requested()
signal test_sfx_master_requested()
@warning_ignore("unused_signal")
signal auto_verify_current_requested()
signal solve_current_level_requested()
signal auto_verify_level_7_requested()
signal auto_verify_all_requested()
signal verify_current_board_requested()
@warning_ignore("unused_signal")
signal auto_play_current_board_requested()
signal auto_solve_current_requested()
signal auto_solve_level_7_requested()
signal auto_play_last_plan_requested()
signal solve_all_levels_requested()
signal auto_clear_current_requested()
signal auto_clear_level_7_requested()
signal generate_balance_report_requested()
@warning_ignore("unused_signal")
signal apply_verified_starting_gold_requested()
signal reset_progress_requested()
signal print_progress_requested()

const DEBUG_ACCESS_SCRIPT := preload("res://scripts/debug/debug_access.gd")
const TELEMETRY_REPORT_LOADER_SCRIPT_PATH := "res://scripts/debug/telemetry_report_loader.gd"
const BALANCE_PATCH_GENERATOR_SCRIPT_PATH := "res://scripts/debug/balance_patch_generator.gd"
const ENEMY_FEATURE_VERIFIER_SCRIPT := preload("res://scripts/debug/enemy_feature_verifier.gd")
const BUILDABLE_RING_GENERATOR_SCRIPT := preload("res://scripts/debug/buildable_ring_generator.gd")
const BUILDABLE_GRID_GENERATOR_SCRIPT := preload("res://scripts/managers/buildable_grid_generator.gd")
const ENEMY_VFX_CONTROLLER_SCRIPT := preload("res://scripts/effects/enemy_vfx_controller.gd")

@onready var panel: PanelContainer = $Root/Panel
@onready var info_label: Label = $Root/Panel/MarginContainer/Scroll/Content/InfoLabel
@onready var god_mode_check: CheckBox = $Root/Panel/MarginContainer/Scroll/Content/GodModeCheck
@onready var status_label: Label = Label.new()

var game_manager: Node = null
var wave_manager: Node = null
var tower_container: Node2D = null
var projectile_container: Node2D = null
var advanced_content: VBoxContainer = null
var advanced_toggle: Button = null
var balance_tools_section: VBoxContainer = null
var balance_disabled_notice: Label = null
var balance_output: RichTextLabel = null
var balance_confirm_dialog: ConfirmationDialog = null
var pending_balance_confirmation: Callable = Callable()
var telemetry_report_loader = null
var balance_patch_generator = null
var balance_tool_aggregate: Dictionary = {}
var balance_tool_patch: Dictionary = {}
var balance_tool_preview_text: String = ""
var balance_tool_last_attempt: int = 0
var enemy_feature_verifier: Node = null
var buildable_ring_generator = null
var buildable_patch_preview: Dictionary = {}
var enemy_vfx_exact_radius_visible: bool = false
var enemy_vfx_quality: int = 1
var enemy_vfx_debug_toggles := {
	"support_radius": true,
	"active_skill_targets": true,
	"heal_tick_events": true,
	"disruptor_radius": true,
	"shield_coverage": true,
	"cloaked_state": true
}

signal level_load_requested(path: String)

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	game_manager = get_tree().current_scene.get_node_or_null("GameManager")
	wave_manager = get_tree().current_scene.get_node_or_null("WaveManager")
	tower_container = get_tree().current_scene.get_node_or_null("WorldRoot/TowerContainer")
	projectile_container = get_tree().current_scene.get_node_or_null("WorldRoot/ProjectileContainer")
	
	_setup_clean_auto_clear_layout()
	_load_balance_services()
	_connect_buttons()
	_update_layout()
	DEBUG_ACCESS_SCRIPT.apply_balance_tool_gate(self)
	get_viewport().size_changed.connect(_update_layout)
	_setup_perf_overlay()

## ── Performance Overlay (PERF-1) ──────────────────────────────────────────
## Toggle with F3. Updates every 0.5 s to avoid string-alloc pressure.
var _perf_overlay: Label = null
var _perf_overlay_visible: bool = false
var _perf_update_timer: float = 0.0
const PERF_UPDATE_INTERVAL := 0.5

func _setup_perf_overlay() -> void:
	_perf_overlay = Label.new()
	_perf_overlay.name = "PerfOverlay"
	_perf_overlay.position = Vector2(12, 12)
	_perf_overlay.add_theme_color_override("font_color", Color(0.0, 1.0, 0.7))
	_perf_overlay.add_theme_font_size_override("font_size", 13)
	_perf_overlay.z_index = 200
	_perf_overlay.visible = false
	add_child(_perf_overlay)

func _toggle_perf_overlay() -> void:
	_perf_overlay_visible = not _perf_overlay_visible
	if _perf_overlay:
		_perf_overlay.visible = _perf_overlay_visible
	if _perf_overlay_visible:
		_refresh_perf_overlay()

func _refresh_perf_overlay() -> void:
	if not _perf_overlay or not _perf_overlay_visible:
		return
	var pb: Node = get_node_or_null("/root/PerformanceBudget")
	var fps_val := Engine.get_frames_per_second()
	var enemy_n := get_tree().get_nodes_in_group("enemies").size()
	var tower_n := get_tree().get_nodes_in_group("placed_towers").size()
	var proj_n  := 0
	if projectile_container:
		proj_n = projectile_container.get_child_count()
	var fx_n := 0
	var effects_c := get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if effects_c:
		fx_n = effects_c.get_child_count()
	var tgt_checks := 0
	var avg_candidates := 0.0
	var active_scanners := 0
	var quality_str := "N/A"
	var pbs := get_node_or_null("/root/PerformanceBudgetService")
	if pbs:
		tgt_checks = int(pbs.get("target_scans_per_second"))
		avg_candidates = float(pbs.get("avg_candidates_per_scan"))
		active_scanners = int(pbs.get("active_towers_scanning"))
	elif pb:
		tgt_checks = pb.target_checks_per_second
	quality_str = pbs.get_quality_name() if pbs else (pb.get_quality_name() if pb else "N/A")
	_perf_overlay.text = (
		"[F3] PERF MONITOR\n"
		+ "FPS:        %d\n" % fps_val
		+ "Enemies:    %d\n" % enemy_n
		+ "Towers:     %d\n" % tower_n
		+ "Bullets:    %d\n" % proj_n
		+ "Active FX:  %d\n" % fx_n
		+ "Tgt scan/s: %d\n" % tgt_checks
		+ "Avg cand:   %.1f\n" % avg_candidates
		+ "Active scan:%d\n" % active_scanners
		+ "FX quality: %s" % quality_str
	)

func _process_perf_overlay(delta: float) -> void:
	if not _perf_overlay_visible:
		return
	_perf_update_timer += delta
	if _perf_update_timer >= PERF_UPDATE_INTERVAL:
		_perf_update_timer = 0.0
		_refresh_perf_overlay()

## ── End Performance Overlay ────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_F3:
				_toggle_perf_overlay()
			KEY_F9:
				if DEBUG_ACCESS_SCRIPT.block_balance_tool("Verify Current Board hotkey"):
					return
				verify_current_board_requested.emit()
			KEY_F8:
				if DEBUG_ACCESS_SCRIPT.block_balance_tool("Auto Solve hotkey"):
					return
				if event.shift_pressed:
					auto_solve_level_7_requested.emit()
				else:
					auto_solve_current_requested.emit()
			KEY_F10:
				if DEBUG_ACCESS_SCRIPT.block_balance_tool("Solve All Levels hotkey"):
					return
				solve_all_levels_requested.emit()

func _create_debug_button(text: String, callable: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(callable)
	return btn

func _create_balance_button(text: String, callable: Callable, dangerous: bool = false) -> Button:
	var btn = _create_debug_button(text, func():
		if DEBUG_ACCESS_SCRIPT.block_balance_tool(text):
			return
		if dangerous:
			_confirm_balance_action(text, callable)
		else:
			callable.call()
	)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(btn)
	return btn

func _load_balance_services() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Load Balance Tool Services"):
		return
	var loader_script = load(TELEMETRY_REPORT_LOADER_SCRIPT_PATH)
	var generator_script = load(BALANCE_PATCH_GENERATOR_SCRIPT_PATH)
	if loader_script:
		telemetry_report_loader = loader_script.new()
	if generator_script:
		balance_patch_generator = generator_script.new()
		if balance_patch_generator is Node:
			balance_patch_generator.add_to_group("balance_tool_runtime")
	print("[DebugPanel] Balance tools enabled.")

func _add_balance_tools_section(parent: Control) -> void:
	balance_disabled_notice = Label.new()
	balance_disabled_notice.text = "Balance tools disabled. Enable application/config/enable_balance_tools for internal testing."
	balance_disabled_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balance_disabled_notice.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	balance_disabled_notice.visible = false
	parent.add_child(balance_disabled_notice)

	balance_tools_section = VBoxContainer.new()
	balance_tools_section.name = "BalanceToolsSection"
	balance_tools_section.add_theme_constant_override("separation", 8)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(balance_tools_section)
	parent.add_child(balance_tools_section)

	var title = Label.new()
	title.text = "BALANCE TOOLS [INTERNAL]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	balance_tools_section.add_child(title)

	var warning = Label.new()
	warning.text = "Internal balance tools. Disabled in release builds."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.35))
	balance_tools_section.add_child(warning)

	_add_balance_button_group("Analysis", [
		_create_balance_button("Analyze Saved Reports", _on_balance_analyze_pressed),
		_create_balance_button("Open Balance Report", func(): generate_balance_report_requested.emit()),
		_create_balance_button("Telemetry Aggregate", _on_balance_analyze_pressed)
	])
	_add_balance_button_group("Patch", [
		_create_balance_button("Generate Balance Patch", _on_balance_generate_pressed),
		_create_balance_button("Preview Patch", _on_balance_preview_pressed),
		_create_balance_button("Apply Runtime Patch", _on_balance_apply_runtime_pressed, true),
		_create_balance_button("Apply File Patch", _on_balance_apply_file_pressed, true),
		_create_balance_button("Find Acceptable Patch", _on_balance_find_acceptable_pressed),
		_create_balance_button("Rollback Last Patch", _on_balance_rollback_pressed, true),
		_create_balance_button("Export Patch JSON", _on_balance_export_pressed)
	])
	_add_balance_button_group("Solver", [
		_create_balance_button("AUTO CLEAR CURRENT LEVEL", func(): auto_clear_current_requested.emit()),
		_create_balance_button("AUTO CLEAR LEVEL 7", func(): auto_clear_level_7_requested.emit()),
		_create_balance_button("AUTO VERIFY CURRENT", func(): verify_current_board_requested.emit()),
		_create_balance_button("AUTO SOLVE CURRENT LEVEL", func(): auto_solve_current_requested.emit()),
		_create_balance_button("AUTO PLAY LAST FOUND PLAN", func(): auto_play_last_plan_requested.emit()),
		_create_balance_button("PERFECT CLEAR REPLAY", func(): auto_play_last_plan_requested.emit()),
		_create_balance_button("SOLVE ALL LEVELS", func(): solve_all_levels_requested.emit())
	])

	var output_scroll = ScrollContainer.new()
	output_scroll.custom_minimum_size = Vector2(0, 150)
	output_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(output_scroll)
	balance_tools_section.add_child(output_scroll)

	balance_output = RichTextLabel.new()
	balance_output.name = "BalanceToolOutput"
	balance_output.fit_content = true
	balance_output.selection_enabled = true
	balance_output.text = "Balance tools ready."
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(balance_output)
	output_scroll.add_child(balance_output)

	_add_verifier_buttons(balance_tools_section)
	_add_buildable_tools_section(parent)
	_add_enemy_feature_verify_section(parent)
	_add_enemy_vfx_test_section(parent)

func _add_buildable_tools_section(parent: Control) -> void:
	var section = VBoxContainer.new()
	section.name = "BuildableToolsSection"
	section.add_theme_constant_override("separation", 8)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(section)
	parent.add_child(section)

	var title = Label.new()
	title.text = "BUILDABLE TOOLS [INTERNAL]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)

	var warning = Label.new()
	warning.text = "Internal map patch tools. Disabled in release builds."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color(1.0, 0.68, 0.35))
	section.add_child(warning)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(grid)
	section.add_child(grid)

	grid.add_child(_create_balance_button("Analyze Full Non-Path Buildable Grid", _on_buildable_analyze_pressed))
	grid.add_child(_create_balance_button("Preview Full Buildable Grid", _on_buildable_preview_pressed))
	grid.add_child(_create_balance_button("Apply Runtime Full Buildable Patch", _on_buildable_apply_runtime_pressed))
	grid.add_child(_create_balance_button("Apply File Buildable Mode Patch", _on_buildable_apply_file_pressed, true))
	grid.add_child(_create_balance_button("Validate Disruptor Counterplay", _on_disruptor_counterplay_validate_pressed))
	grid.add_child(_create_balance_button("Run All Levels Placement Validation", _on_buildable_validate_all_pressed))
	grid.add_child(_create_balance_button("Clear Buildable Preview", _on_buildable_clear_preview_pressed))

func _add_enemy_feature_verify_section(parent: Control) -> void:
	var section = VBoxContainer.new()
	section.name = "EnemyFeatureVerifySection"
	section.add_theme_constant_override("separation", 8)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(section)
	parent.add_child(section)

	var title = Label.new()
	title.text = "ENEMY FEATURE VERIFY [INTERNAL]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(grid)
	section.add_child(grid)

	grid.add_child(_create_balance_button("Spawn Healer Test", func(): _run_enemy_feature_check("healer")))
	grid.add_child(_create_balance_button("Spawn Disruptor Test", func(): _run_enemy_feature_check("disruptor")))
	grid.add_child(_create_balance_button("Spawn Shield Aura Test", func(): _run_enemy_feature_check("shield")))
	grid.add_child(_create_balance_button("Spawn Cloaked Targeting Test", func(): _run_enemy_feature_check("cloaked")))
	grid.add_child(_create_balance_button("Spawn Splitter Test", func(): _run_enemy_feature_check("splitter")))
	grid.add_child(_create_balance_button("Spawn Air Targeting Test", func(): _run_enemy_feature_check("air")))
	grid.add_child(_create_balance_button("Run All Enemy Feature Checks", _run_all_enemy_feature_checks))
	grid.add_child(_create_balance_button("Clear Test Scene", _clear_enemy_feature_scene))

func _add_enemy_vfx_test_section(parent: Control) -> void:
	var section = VBoxContainer.new()
	section.name = "EnemyVFXTestSection"
	section.add_theme_constant_override("separation", 8)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(section)
	parent.add_child(section)

	var title = Label.new()
	title.text = "ENEMY VFX TEST [INTERNAL]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	section.add_child(title)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(grid)
	section.add_child(grid)

	grid.add_child(_create_balance_button("Spawn Healer VFX Test", func(): _run_enemy_feature_check("healer")))
	grid.add_child(_create_balance_button("Trigger Healer Heal Tick", func(): _run_enemy_feature_check("healer")))
	grid.add_child(_create_balance_button("Spawn Disruptor VFX Test", func(): _run_enemy_feature_check("disruptor")))
	grid.add_child(_create_balance_button("Spawn Shield Aura VFX Test", func(): _run_enemy_feature_check("shield")))
	grid.add_child(_create_balance_button("Spawn Cloaked VFX Test", func(): _run_enemy_feature_check("cloaked")))
	grid.add_child(_create_balance_button("Spawn Splitter VFX Test", func(): _run_enemy_feature_check("splitter")))
	grid.add_child(_create_balance_button("Spawn Runner Burst VFX Test", func(): _run_enemy_feature_check("speed")))
	grid.add_child(_create_balance_button("Show Support Radius", func(): _toggle_enemy_vfx_debug("support_radius")))
	grid.add_child(_create_balance_button("Show Active Skill Targets", func(): _toggle_enemy_vfx_debug("active_skill_targets")))
	grid.add_child(_create_balance_button("Show Heal Tick Events", func(): _toggle_enemy_vfx_debug("heal_tick_events")))
	grid.add_child(_create_balance_button("Show Disruptor Radius", func(): _toggle_enemy_vfx_debug("disruptor_radius")))
	grid.add_child(_create_balance_button("Show Shield Coverage", func(): _toggle_enemy_vfx_debug("shield_coverage")))
	grid.add_child(_create_balance_button("Show Cloaked State", func(): _toggle_enemy_vfx_debug("cloaked_state")))
	grid.add_child(_create_balance_button("Toggle Exact Skill Radius", _toggle_enemy_vfx_exact_radius))
	grid.add_child(_create_balance_button("Show Lightweight/Full FX mode", _cycle_enemy_vfx_quality))
	grid.add_child(_create_balance_button("Enemy VFX Verification Report", _run_all_enemy_feature_checks))
	grid.add_child(_create_balance_button("Clear VFX Test Scene", _clear_enemy_feature_scene))

func _toggle_enemy_vfx_debug(toggle_name: String) -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Enemy VFX Toggle: %s" % toggle_name):
		return
	var enabled := not bool(enemy_vfx_debug_toggles.get(toggle_name, true))
	enemy_vfx_debug_toggles[toggle_name] = enabled
	ENEMY_VFX_CONTROLLER_SCRIPT.set_global_debug_toggle(toggle_name, enabled)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_vfx_controller"):
			var vfx = enemy.get_vfx_controller()
			if vfx and vfx.has_method("refresh_debug_visibility"):
				vfx.refresh_debug_visibility()
	_balance_set_output("[ENEMY_VFX]\n%s=%s" % [toggle_name, str(enabled)])

func _toggle_enemy_vfx_exact_radius() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Toggle Enemy VFX Exact Radius"):
		return
	enemy_vfx_exact_radius_visible = not enemy_vfx_exact_radius_visible
	ENEMY_VFX_CONTROLLER_SCRIPT.set_global_exact_radius_visible(enemy_vfx_exact_radius_visible)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_vfx_controller"):
			var vfx = enemy.get_vfx_controller()
			if vfx:
				vfx.set_exact_radius_visible(enemy_vfx_exact_radius_visible)
	_balance_set_output("[ENEMY_VFX]\nexact_skill_radius=%s" % str(enemy_vfx_exact_radius_visible))

func _cycle_enemy_vfx_quality() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Toggle Enemy VFX Quality"):
		return
	enemy_vfx_quality = (enemy_vfx_quality + 1) % 3
	ENEMY_VFX_CONTROLLER_SCRIPT.set_global_quality(enemy_vfx_quality)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("get_vfx_controller"):
			var vfx = enemy.get_vfx_controller()
			if vfx:
				vfx.set_quality(enemy_vfx_quality)
	var quality_name: String = str(["LOW", "MEDIUM", "HIGH"][enemy_vfx_quality])
	_balance_set_output("[ENEMY_VFX]\nquality=%s" % quality_name)

func _add_balance_button_group(label_text: String, buttons: Array) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 13)
	balance_tools_section.add_child(label)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(grid)
	balance_tools_section.add_child(grid)
	for button in buttons:
		grid.add_child(button)

func _confirm_balance_action(action_name: String, callable: Callable) -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool(action_name):
		return
	pending_balance_confirmation = callable
	if not balance_confirm_dialog:
		balance_confirm_dialog = ConfirmationDialog.new()
		balance_confirm_dialog.name = "BalanceToolConfirmation"
		balance_confirm_dialog.dialog_text = "Apply internal balance action?"
		DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(balance_confirm_dialog)
		add_child(balance_confirm_dialog)
		balance_confirm_dialog.confirmed.connect(func():
			if DEBUG_ACCESS_SCRIPT.block_balance_tool("Confirmed balance action"):
				return
			if pending_balance_confirmation.is_valid():
				pending_balance_confirmation.call()
		)
	balance_confirm_dialog.title = action_name
	balance_confirm_dialog.dialog_text = "%s\n\nThis is an internal balance action. Continue?" % action_name
	balance_confirm_dialog.popup_centered()

func _get_enemy_feature_verifier() -> Node:
	if enemy_feature_verifier and is_instance_valid(enemy_feature_verifier):
		return enemy_feature_verifier
	enemy_feature_verifier = ENEMY_FEATURE_VERIFIER_SCRIPT.new()
	enemy_feature_verifier.name = "EnemyFeatureVerifier"
	enemy_feature_verifier.add_to_group("balance_tool_runtime")
	add_child(enemy_feature_verifier)
	return enemy_feature_verifier

func _run_enemy_feature_check(check_name: String) -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Enemy Feature Verify: %s" % check_name):
		return
	var verifier = _get_enemy_feature_verifier()
	var result: Dictionary = await verifier.run_named_check(check_name)
	_balance_set_output(verifier.format_report({"checks": {check_name: result}, "summary": {"passed": 1 if bool(result.get("tests_passed", false)) else 0, "failed": 0 if bool(result.get("tests_passed", false)) else 1}}))

func _run_all_enemy_feature_checks() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Run All Enemy Feature Checks"):
		return
	var verifier = _get_enemy_feature_verifier()
	var result: Dictionary = await verifier.run_all_checks()
	_balance_set_output(verifier.format_report(result))

func _clear_enemy_feature_scene() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Clear Enemy Feature Test Scene"):
		return
	if enemy_feature_verifier and enemy_feature_verifier.has_method("clear_test_scene"):
		enemy_feature_verifier.clear_test_scene()
	_balance_set_output("[ENEMY_FEATURE_VERIFY]\ncleared=true")

func _balance_level_id() -> String:
	var scene = get_tree().current_scene
	if scene and "current_level_id" in scene and str(scene.current_level_id) != "":
		return str(scene.current_level_id)
	if scene and "current_level_path" in scene and str(scene.current_level_path) != "":
		return str(scene.current_level_path).get_file().get_basename()
	return "unknown"

func _balance_set_output(text: String) -> void:
	if balance_output:
		balance_output.text = text
	print(text)

func _balance_count_search_attempts(text: String) -> int:
	var count := 0
	for line in text.split("\n"):
		if line.begins_with("attempt="):
			count += 1
	return count

func _get_buildable_ring_generator():
	if buildable_ring_generator == null:
		buildable_ring_generator = BUILDABLE_RING_GENERATOR_SCRIPT.new()
	return buildable_ring_generator

func _current_level_json_path() -> String:
	var scene = get_tree().current_scene
	if scene and "current_level_path" in scene and str(scene.current_level_path) != "":
		return str(scene.current_level_path)
	var level_id := _balance_level_id()
	if level_id.begins_with("level_"):
		return "res://data/levels/%s.json" % level_id
	return ""

func _load_json_file(path: String) -> Variant:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data

func _write_json_file(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	return true

func _on_buildable_analyze_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Analyze Full Non-Path Buildable Grid"):
		return
	var path := _current_level_json_path()
	var level_data = _load_json_file(path)
	if not (level_data is Dictionary):
		_balance_set_output("[BUILDABLE_COVERAGE]\nerror=level_json_missing path=%s" % path)
		return
	var report: Dictionary = BUILDABLE_GRID_GENERATOR_SCRIPT.analyze_full_non_path(level_data)
	var counterplay := _disruptor_counterplay_report(level_data)
	report["disruptor_safe_sniper_cells"] = int(counterplay.get("valid_safe_sniper_cells_count", 0))
	buildable_patch_preview = report
	_balance_set_output(BUILDABLE_GRID_GENERATOR_SCRIPT.format_full_non_path_report(report))

func _on_buildable_preview_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Preview Full Buildable Grid"):
		return
	_on_buildable_analyze_pressed()
	var scene = get_tree().current_scene
	if not scene or not ("build_preview" in scene) or scene.build_preview == null:
		_balance_set_output(str(balance_output.text) + "\npreview_overlay=missing")
		return
	var level_data = _load_json_file(_current_level_json_path())
	var cells := BUILDABLE_GRID_GENERATOR_SCRIPT.generate_full_non_path_buildable_grid(level_data)
	scene.build_preview.set_buildable_patch_preview_cells(cells)
	_balance_set_output(str(balance_output.text) + "\npreview_overlay=shown full_buildable=%d" % cells.size())

func _on_buildable_apply_runtime_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply Runtime Full Buildable Patch"):
		return
	var path := _current_level_json_path()
	var level_data = _load_json_file(path)
	if not (level_data is Dictionary):
		_balance_set_output("[BUILDABLE_RUNTIME_PATCH]\nerror=level_json_missing path=%s" % path)
		return
	var patched: Dictionary = level_data.duplicate(true)
	patched["buildable_mode"] = "full_non_path"
	var report: Dictionary = BUILDABLE_GRID_GENERATOR_SCRIPT.analyze_full_non_path(patched)
	var scene = get_tree().current_scene
	if not scene or not ("level_manager" in scene) or scene.level_manager == null:
		_balance_set_output("[BUILDABLE_RUNTIME_PATCH]\nerror=level_manager_missing")
		return
	scene.level_manager.buildable_mode = "full_non_path"
	scene.level_manager.level_data = patched
	scene.level_manager.buildable_cells = BUILDABLE_GRID_GENERATOR_SCRIPT.generate_full_non_path_buildable_grid(patched)
	if "build_manager" in scene and scene.build_manager:
		scene.build_manager.configure_from_level(scene.level_manager)
	if "build_preview" in scene and scene.build_preview:
		scene.build_preview.set_blocked_cells(scene.level_manager.get_all_blocked_cells())
		scene.build_preview.set_buildable_cells(scene.level_manager.buildable_cells)
		scene.build_preview.clear_buildable_patch_preview()
	_balance_set_output(BUILDABLE_GRID_GENERATOR_SCRIPT.format_full_non_path_report(report) + "\nruntime_patch=applied")

func _on_buildable_apply_file_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply File Buildable Mode Patch"):
		return
	var path := _current_level_json_path()
	var level_data = _load_json_file(path)
	if not (level_data is Dictionary):
		_balance_set_output("[BUILDABLE_FILE_PATCH]\nerror=level_json_missing path=%s" % path)
		return
	var patched: Dictionary = level_data.duplicate(true)
	patched["buildable_mode"] = "full_non_path"
	patched.erase("buildable_radius")
	var ok := _write_json_file(path, patched)
	var report: Dictionary = BUILDABLE_GRID_GENERATOR_SCRIPT.analyze_full_non_path(patched)
	_balance_set_output(BUILDABLE_GRID_GENERATOR_SCRIPT.format_full_non_path_report(report) + "\nfile_patch=%s path=%s" % ["applied" if ok else "failed", path])

func _on_buildable_validate_all_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Run All Levels Placement Validation"):
		return
	var lines: Array[String] = ["[FULL_NON_PATH_PLACEMENT_ALL_LEVELS]"]
	var ok_all := true
	for i in range(1, 21):
		var path := "res://data/levels/level_%02d.json" % i
		var level_data = _load_json_file(path)
		if not (level_data is Dictionary):
			lines.append("level_%02d FAIL load_error" % i)
			ok_all = false
			continue
		var report: Dictionary = BUILDABLE_GRID_GENERATOR_SCRIPT.analyze_full_non_path(level_data)
		var counterplay := _disruptor_counterplay_report(level_data)
		var passed := bool(report.get("pass", false)) and bool(counterplay.get("pass", false))
		lines.append("%s %s mode=%s grid=%s path=%d old=%d new=%d ratio=%.1f%% disruptor_safe_sniper_cells=%d weak_segments=%d" % [
			str(report.get("level_id", "level_%02d" % i)),
			"PASS" if passed else "FAIL",
			str(report.get("mode", "")),
			str(report.get("grid_size", "")),
			int(report.get("path_cells", 0)),
			int(report.get("old_buildable_count", 0)),
			int(report.get("new_buildable_count", 0)),
			float(report.get("buildable_ratio", 0.0)),
			int(counterplay.get("valid_safe_sniper_cells_count", 0)),
			(counterplay.get("weak_segments", []) as Array).size()
		])
		if not passed:
			ok_all = false
	lines.append("ok=%s" % str(ok_all))
	_balance_set_output("\n".join(lines))

func _on_disruptor_counterplay_validate_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Validate Disruptor Counterplay"):
		return
	var level_data = _load_json_file(_current_level_json_path())
	if not (level_data is Dictionary):
		_balance_set_output("[DISRUPTOR_COUNTERPLAY]\nerror=level_json_missing")
		return
	var report := _disruptor_counterplay_report(level_data)
	_balance_set_output("\n".join([
		"Validate Disruptor Counterplay",
		"level_id=%s" % str(report.get("level_id", "unknown")),
		"disruptor_aura_radius=%.1f" % float(report.get("disruptor_aura_radius", 0.0)),
		"sniper_range=%.1f" % float(report.get("sniper_range", 0.0)),
		"valid_safe_sniper_cells_count=%d" % int(report.get("valid_safe_sniper_cells_count", 0)),
		"weak_segments=%s" % str(report.get("weak_segments", [])),
		"pass=%s" % str(report.get("pass", false))
	]))

func _disruptor_counterplay_report(level_data: Dictionary) -> Dictionary:
	var towers: Variant = _load_json_file("res://data/towers_tree.json")
	var enemies: Variant = _load_json_file("res://data/enemies.json")
	var sniper: Dictionary = towers.get("sniper_tower", {}) if towers is Dictionary else {}
	var sniper_range: float = 0.0
	if sniper.has("levels") and sniper["levels"] is Array and not sniper["levels"].is_empty():
		sniper_range = float(sniper["levels"][0].get("range", 0.0))
	else:
		sniper_range = float(sniper.get("range", 0.0))
	var disruptor: Dictionary = enemies.get("disruptor", {}) if enemies is Dictionary else {}
	var skill_params: Dictionary = disruptor.get("skill_params", {})
	var radius: float = float(skill_params.get("radius", 150.0))
	return BUILDABLE_GRID_GENERATOR_SCRIPT.validate_disruptor_counterplay(level_data, sniper_range, radius)

func _on_buildable_clear_preview_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Clear Buildable Preview"):
		return
	var scene = get_tree().current_scene
	if scene and "build_preview" in scene and scene.build_preview:
		scene.build_preview.clear_buildable_patch_preview()
	_balance_set_output("[BUILDABLE_PREVIEW]\ncleared=true")

func _on_balance_analyze_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Analyze Saved Reports"):
		return
	if not telemetry_report_loader:
		_balance_set_output("[TELEMETRY_AGGREGATE]\nloader=missing")
		return
	var level_id := _balance_level_id()
	balance_tool_aggregate = telemetry_report_loader.analyze_reports(level_id)
	var latest: Dictionary = telemetry_report_loader.get_latest_report(level_id)
	var lines := [
		"[TELEMETRY_AGGREGATE]",
		"level=%s" % level_id,
		"runs=%d" % int(balance_tool_aggregate.get("source_reports_count", 0)),
		"difficulty_rating=%s" % str(balance_tool_aggregate.get("difficulty_rating", "Unknown")),
		"tower_dominance=%s" % str(balance_tool_aggregate.get("tower_dominance", "None")),
		"dominant_strategy_risk=%s" % str(balance_tool_aggregate.get("dominant_strategy_risk", false))
	]
	if not latest.is_empty():
		lines.append("latest_report=true")
	_balance_set_output("\n".join(lines))

func _on_balance_generate_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Generate Balance Patch"):
		return
	if not balance_patch_generator:
		_balance_set_output("[BALANCE_PATCH]\ngenerator=missing")
		return
	var level_id := _balance_level_id()
	if balance_tool_aggregate.is_empty() and telemetry_report_loader:
		balance_tool_aggregate = telemetry_report_loader.analyze_reports(level_id)
	var latest: Dictionary = {}
	if telemetry_report_loader:
		latest = telemetry_report_loader.get_latest_report(level_id)
	balance_tool_patch = balance_patch_generator.generate_patch(level_id, balance_tool_aggregate, latest)
	balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_balance_set_output(JSON.stringify(balance_tool_patch, "\t"))

func _on_balance_preview_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Preview Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	if balance_patch_generator:
		balance_tool_preview_text = balance_patch_generator.preview_patch(balance_tool_patch)
	_balance_set_output(balance_tool_preview_text)

func _on_balance_apply_runtime_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply Runtime Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	if not balance_patch_generator:
		return
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	var ok: bool = balance_patch_generator.apply_runtime_patch(balance_tool_patch, wm)
	if not ok and not balance_patch_generator.last_stage_2_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_stage_2_patch
	if not ok and not balance_patch_generator.last_softened_patch.is_empty():
		balance_tool_patch = balance_patch_generator.last_softened_patch
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_apply_file_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Apply File Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	if not balance_patch_generator:
		return
	balance_patch_generator.apply_patch(balance_tool_patch)
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_find_acceptable_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Find Acceptable Patch"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	if not balance_patch_generator:
		return
	var wm = get_tree().current_scene.get_node_or_null("WaveManager")
	var accepted: Dictionary = balance_patch_generator.find_acceptable_patch(balance_tool_patch, wm)
	balance_tool_last_attempt = _balance_count_search_attempts(balance_patch_generator.last_operation_log)
	if not accepted.is_empty():
		balance_tool_patch = accepted
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_rollback_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Rollback Last Patch"):
		return
	if not balance_patch_generator:
		return
	balance_patch_generator.rollback_last_patch(_balance_level_id())
	_balance_set_output(balance_patch_generator.last_operation_log)

func _on_balance_export_pressed() -> void:
	if DEBUG_ACCESS_SCRIPT.block_balance_tool("Export Patch JSON"):
		return
	if balance_tool_patch.is_empty():
		_on_balance_generate_pressed()
	if not balance_patch_generator:
		return
	var path: String = balance_patch_generator.export_patch_json(balance_tool_patch)
	_balance_set_output("[BALANCE_PATCH_EXPORT]\npath=%s\n%s" % [path, "error=" + balance_patch_generator.last_error if path == "" else "saved=true"])

func _add_level_debug_buttons(parent: Control) -> void:
	var label = Label.new()
	label.text = "LEVELS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	
	var grid = GridContainer.new()
	grid.columns = 3
	parent.add_child(grid)
	
	for i in range(1, 4):
		var btn = Button.new()
		btn.text = "L%d" % i
		btn.custom_minimum_size = Vector2(40, 30)
		btn.pressed.connect(func(): level_load_requested.emit("res://data/levels/level_0%d.json" % i))
		grid.add_child(btn)
	
	var sep = HSeparator.new()
	parent.add_child(sep)

func _connect_buttons() -> void:
	_find_button("Gold100").pressed.connect(func(): add_gold_requested.emit(100))
	_find_button("Gold500").pressed.connect(func(): add_gold_requested.emit(500))
	_find_button("StartWave").pressed.connect(func(): start_next_wave_requested.emit())
	_find_button("KillAll").pressed.connect(func(): kill_all_enemies_requested.emit())
	_find_button("ClearProj").pressed.connect(func(): clear_projectiles_requested.emit())
	_find_button("Victory").pressed.connect(func(): trigger_victory_requested.emit())
	_find_button("GameOver").pressed.connect(func(): trigger_game_over_requested.emit())
	_find_button("Restart").pressed.connect(func(): restart_requested.emit())
	god_mode_check.toggled.connect(func(v): god_mode_toggled.emit(v))
	_find_button("HardAudioTest").pressed.connect(func(): hard_audio_test_requested.emit())
	_find_button("TestSfx").pressed.connect(func(): test_sfx_requested.emit())
	_find_button("TestMusic").pressed.connect(func(): test_music_requested.emit())
	_find_button("TestSfxMaster").pressed.connect(func(): test_sfx_master_requested.emit())

func _find_button(node_name: String) -> Button:
	return $Root/Panel/MarginContainer/Scroll/Content.find_child(node_name, true, false) as Button

func _setup_clean_auto_clear_layout() -> void:
	var root = $Root/Panel/MarginContainer/Scroll/Content
	var old_controls: Array[Node] = []
	for child in root.get_children():
		if child.name not in ["Title", "HSeparator", "InfoLabel", "HSeparator2"]:
			old_controls.append(child)
			root.remove_child(child)

	var title := root.get_node_or_null("Title")
	if title:
		title.text = "DEBUG PANEL"

	status_label.text = "AUTO CLEAR STATUS\n- State: Idle\n- Level: -\n- Current Gold Test: -\n- Best Result So Far: -\n- Final Result: -"
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	root.add_child(HSeparator.new())

	_add_balance_tools_section(root)
	
	root.add_child(HSeparator.new())
	var prog_vbox := VBoxContainer.new()
	prog_vbox.name = "ProgressActions"
	prog_vbox.add_theme_constant_override("separation", 6)
	root.add_child(prog_vbox)
	
	prog_vbox.add_child(_create_debug_button("PRINT SAVED PROGRESS", func(): print_progress_requested.emit()))
	var reset_btn = _create_debug_button("RESET ALL PROGRESS", func(): reset_progress_requested.emit())
	reset_btn.add_theme_color_override("font_color", Color.RED)
	prog_vbox.add_child(reset_btn)
	
	root.add_child(HSeparator.new())

	advanced_toggle = Button.new()
	advanced_toggle.text = "ADVANCED DEBUG ▸"
	advanced_toggle.toggle_mode = true
	advanced_toggle.custom_minimum_size = Vector2(0, 30)
	advanced_toggle.toggled.connect(_set_advanced_visible)
	root.add_child(advanced_toggle)

	advanced_content = VBoxContainer.new()
	advanced_content.name = "AdvancedDebug"
	advanced_content.visible = false
	advanced_content.add_theme_constant_override("separation", 6)
	root.add_child(advanced_content)

	for child in old_controls:
		advanced_content.add_child(child)

	_add_level_debug_buttons(advanced_content)

	if balance_disabled_notice and DEBUG_ACCESS_SCRIPT.is_debug_ui_allowed() and not DEBUG_ACCESS_SCRIPT.is_balance_tools_allowed():
		balance_disabled_notice.visible = true

func _set_advanced_visible(is_open: bool) -> void:
	if advanced_content:
		advanced_content.visible = is_open
	if advanced_toggle:
		advanced_toggle.text = "ADVANCED DEBUG ▾" if is_open else "ADVANCED DEBUG ▸"

func _add_verifier_buttons(parent: Control) -> void:
	var verifier_vbox = VBoxContainer.new()
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(verifier_vbox)
	parent.add_child(verifier_vbox)
	
	var label = Label.new()
	label.text = "VERIFICATION"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	verifier_vbox.add_child(label)
	
	var btn_verify = _create_balance_button("VERIFY CURRENT BOARD (F9)", func(): verify_current_board_requested.emit())
	var btn_solve = _create_balance_button("AUTO SOLVE CURRENT LEVEL (F8)", func(): auto_solve_current_requested.emit())
	var btn_solve7 = _create_balance_button("AUTO SOLVE LEVEL 7 (Shift+F8)", func(): auto_solve_level_7_requested.emit())
	var btn_play_last = _create_balance_button("AUTO PLAY LAST PLAN", func(): auto_play_last_plan_requested.emit())
	var btn_solve_all = _create_balance_button("SOLVE ALL LEVELS (F10)", func(): solve_all_levels_requested.emit())
	
	verifier_vbox.add_child(btn_verify)
	verifier_vbox.add_child(btn_solve)
	verifier_vbox.add_child(btn_solve7)
	verifier_vbox.add_child(btn_play_last)
	verifier_vbox.add_child(btn_solve_all)
	
	var btn_current_solve = Button.new()
	btn_current_solve.text = "SOLVE FROM SCRATCH"
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(btn_current_solve)
	btn_current_solve.pressed.connect(func():
		if DEBUG_ACCESS_SCRIPT.block_balance_tool("Solve From Scratch"):
			return
		solve_current_level_requested.emit()
	)
	parent.add_child(btn_current_solve)
	
	var btn_l7 = Button.new()
	btn_l7.text = "SOLVE LEVEL 7"
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(btn_l7)
	btn_l7.pressed.connect(func():
		if DEBUG_ACCESS_SCRIPT.block_balance_tool("Solve Level 7"):
			return
		auto_verify_level_7_requested.emit()
	)
	parent.add_child(btn_l7)
	
	var btn_all = Button.new()
	btn_all.text = "VERIFY ALL PLANS"
	DEBUG_ACCESS_SCRIPT.register_balance_tool_ui(btn_all)
	btn_all.pressed.connect(func():
		if DEBUG_ACCESS_SCRIPT.block_balance_tool("Verify All Plans"):
			return
		auto_verify_all_requested.emit()
	)
	parent.add_child(btn_all)
	
	var sep = HSeparator.new()
	parent.add_child(sep)

func update_verifier_status(msg: String, is_error: bool = false) -> void:
	if msg.begins_with("AUTO CLEAR STATUS"):
		status_label.text = msg
	else:
		status_label.text = "AUTO CLEAR STATUS\n- State: %s" % msg
	if is_error:
		status_label.add_theme_color_override("font_color", Color.RED)
	elif "SUCCESS" in msg or "FOUND" in msg or "Verified" in msg:
		status_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		status_label.add_theme_color_override("font_color", Color.YELLOW)

func update_auto_clear_status(status: Dictionary) -> void:
	var lines: Array[String] = ["AUTO CLEAR STATUS"]
	lines.append("- State: %s" % str(status.get("state", "Idle")))
	lines.append("- Level: %s" % str(status.get("level", "-")))
	lines.append("- Current Gold Test: %s" % str(status.get("gold", "-")))
	lines.append("- Candidate: %s" % str(status.get("candidate", "-")))
	lines.append("- Best Result So Far: %s" % str(status.get("best", "-")))
	lines.append("- Final Result: %s" % str(status.get("result", "-")))
	if status.has("recommended_gold"):
		lines.append("- Recommended Gold: %s" % str(status.get("recommended_gold")))
		
		var apply_btn = _find_button("ApplySetupGoldBtn")
		if apply_btn:
			var gold = int(status.get("recommended_gold", 0))
			var is_perfect = "Perfect" in str(status.get("state", ""))
			apply_btn.disabled = not (gold > 0 and is_perfect)
			
	if status.has("wave"):
		lines.append("- Wave: %s" % str(status.get("wave")))
	if status.has("lives"):
		lines.append("- Lives: %s" % str(status.get("lives")))
	if status.has("game_gold"):
		lines.append("- Gold: %s" % str(status.get("game_gold")))
	if status.has("last_action"):
		lines.append("- Last Action: %s" % str(status.get("last_action")))
	update_verifier_status("\n".join(lines), bool(status.get("is_error", false)))

func _update_layout() -> void:
	if not panel: return
	var viewport_size : Vector2 = get_viewport().get_visible_rect().size
	var panel_width : float = 240.0
	var margin : float = 16.0
	var top : float = 72.0
	var max_h : float = max(240.0, viewport_size.y - top - margin)

	panel.custom_minimum_size = Vector2(panel_width, min(560.0, max_h))
	panel.size = panel.custom_minimum_size
	panel.position = Vector2(
		viewport_size.x - panel_width - margin,
		top
	)

func _process(delta: float) -> void:
	_process_perf_overlay(delta)
	if not visible: return
	_update_info()

func _update_info() -> void:
	var info = ""
	info += "FPS: %d\n" % Engine.get_frames_per_second()
	if game_manager:
		info += "Gold: %d\n" % game_manager.gold
		info += "Lives: %d\n" % game_manager.lives
		info += "Wave: %d\n" % game_manager.current_wave
	if wave_manager:
		info += "Active Enemies: %d\n" % get_tree().get_nodes_in_group("enemies").size()
	if tower_container:
		info += "Towers: %d\n" % tower_container.get_child_count()
	if projectile_container:
		info += "Projectiles: %d\n" % projectile_container.get_child_count()
	info_label.text = info

func show_panel() -> void:
	visible = true
	layer = 500
	
	var root := get_node_or_null("Root")
	if root:
		root.visible = true
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	var panel_node := get_node_or_null("Root/Panel")
	if panel_node:
		panel_node.visible = true
		panel_node.mouse_filter = Control.MOUSE_FILTER_STOP
		
	_update_layout()
	refresh()
	if OS.is_debug_build(): print("[DebugPanel] show_panel")

func hide_panel() -> void:
	visible = false
	if OS.is_debug_build(): print("[DebugPanel] hide_panel")

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

func refresh() -> void:
	# Placeholder for future refresh logic
	pass

func is_active() -> bool:
	return visible

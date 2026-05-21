## PerfOverlay — lightweight live diagnostics overlay.
##
## Registered as an autoload ("PerfOverlay") in project.godot.
## Toggle: F9 + O
## Reads live counters from PerformanceBudget, FrameSpikeLogger, and main scene.
## Panel is always created; _process is cheap when hidden.
extends CanvasLayer

const LABEL_FONT_SIZE := 13
const PANEL_WIDTH     := 280
const PANEL_HEIGHT    := 520
const PADDING         := 8.0

var _visible_flag: bool = false
var _panel: ColorRect = null
var _label: RichTextLabel = null
var _refresh_timer: float = 0.0
const REFRESH_INTERVAL := 0.25

func _ready() -> void:
	layer = 998
	name = "PerfOverlay"
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = ColorRect.new()
	_panel.color = Color(0.0, 0.0, 0.0, 0.78)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.position = Vector2(8, 8)
	_panel.visible = false
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.size = Vector2(PANEL_WIDTH - PADDING * 2, PANEL_HEIGHT - PADDING * 2)
	_label.position = Vector2(PADDING, PADDING)
	_label.add_theme_font_size_override("normal_font_size", LABEL_FONT_SIZE)
	_panel.add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O and Input.is_key_pressed(KEY_F9):
			_visible_flag = not _visible_flag
			_panel.visible = _visible_flag
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _visible_flag or _label == null:
		return
	_refresh_timer -= delta
	if _refresh_timer > 0.0:
		return
	_refresh_timer = REFRESH_INTERVAL
	_refresh_label()

func _refresh_label() -> void:
	var pb: Node = get_node_or_null("/root/PerformanceBudget")
	var pbs: Node = get_node_or_null("/root/PerformanceBudgetService")

	var fps  := Engine.get_frames_per_second()
	var f_ms := 1000.0 / maxf(float(fps), 1.0)
	var qual : String = pbs.get_quality_name() if pbs and pbs.has_method("get_quality_name") else (pb.get_quality_name() if pb else "?")

	# Node group sizes (get_nodes_in_group is O(n) but only called at 0.25 s intervals).
	var creep_count  := get_tree().get_nodes_in_group("enemies").size()
	var tower_count  := get_tree().get_nodes_in_group("towers").size()
	# Projectiles group may not exist on all builds — be safe.
	var proj_count   := get_tree().get_nodes_in_group("projectiles").size()

	var atk_vfx := AttackVFX._active_count
	var dmg_num := DamageNumber._active_count
	var status_icons := get_tree().get_nodes_in_group("status_icons").size()
	var target_scans := int(pbs.get("target_scans_per_second")) if pbs else (int(pb.target_checks_per_second) if pb else 0)
	var avg_candidates := float(pbs.get("avg_candidates_per_scan")) if pbs else 0.0
	var active_scanners := int(pbs.get("active_towers_scanning")) if pbs else 0

	# Godot process time from the performance monitor (microseconds → ms).
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var atk_budget := int(pbs.get_budget("max_attack_vfx_active")) if pbs and pbs.has_method("get_budget") else AttackVFX.MAX_ACTIVE

	# Colour helpers.
	var c_fps  := "00ff88" if fps >= 50 else ("ffcc00" if fps >= 35 else "ff4444")
	var c_qual := "00ccff" if qual == "HIGH" else ("ffcc00" if qual == "BALANCED" or qual == "MED" else "ff4444")
	var c_avfx := "00ff88" if atk_vfx < atk_budget * 0.8 else ("ffcc00" if atk_vfx < atk_budget else "ff4444")
	var c_dn   := "00ff88" if dmg_num < DamageNumber.MAX_ACTIVE * 0.8 else ("ffcc00" if dmg_num < DamageNumber.MAX_ACTIVE else "ff4444")

	# ── Wave preview cache counters (from main scene) ──
	var cache_hits := 0
	var cache_misses := 0
	var ei_hits := 0
	var ei_misses := 0
	var preview_active := 0
	var preview_redraws := 0
	var spike_frames := 0
	var main_node := get_tree().current_scene
	if main_node and main_node.has_method("get_perf_debug_counters"):
		var counters: Dictionary = main_node.call("get_perf_debug_counters")
		cache_hits    = int(counters.get("wave_preview_cache_hits", 0))
		cache_misses  = int(counters.get("wave_preview_cache_misses", 0))
		ei_hits       = int(counters.get("element_icon_cache_hits", 0))
		ei_misses     = int(counters.get("element_icon_cache_misses", 0))
		preview_active  = int(counters.get("tower_preview_active_count", 0))
		preview_redraws = int(counters.get("tower_preview_redraw_count", 0))
	var fsl_node := get_node_or_null("/root/FrameSpikeLogger")
	if fsl_node:
		spike_frames = int(fsl_node.total_spike_frames)

	# ── Section timings from last frame ──
	var section_lines := ""
	var sections: Dictionary = fsl_node.get_section_report() if fsl_node else {}
	if not sections.is_empty():
		var pairs: Array = []
		for k in sections: pairs.append([k, float(sections[k])])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		for pair in pairs:
			var t: float = pair[1]
			var c_t := "ff4444" if t > 8.0 else ("ffcc00" if t > 4.0 else "888888")
			section_lines += "  %-24s [color=#%s]%.2f ms[/color]\n" % [pair[0], c_t, t]
	else:
		section_lines = "  [color=#555555](idle — no hot sections)[/color]\n"

	var c_cache := "00ff88" if cache_misses == 0 else ("ffcc00" if cache_misses < 3 else "ff4444")
	var c_spike := "00ff88" if spike_frames == 0 else ("ffcc00" if spike_frames < 5 else "ff4444")

	_label.text = (
		"[b][color=#aaddff]■ PERF OVERLAY[/color][/b]  [color=#555555]F10[/color]\n"
		+ "──────────────────────────\n"
		+ "[color=#%s]FPS  %d  (%.1f ms)[/color]\n" % [c_fps, fps, f_ms]
		+ "Process  [color=#ffee88]%.2f ms[/color]\n" % proc_ms
		+ "Physics  [color=#ffee88]%.2f ms[/color]\n" % physics_ms
		+ "Draws    [color=#ffffff]%d[/color]\n" % draw_calls
		+ "Nodes    [color=#ffffff]%d[/color]\n" % node_count
		+ "Quality  [color=#%s]%s[/color]\n" % [c_qual, qual]
		+ "──────────────────────────\n"
		+ "Creeps        [color=#ffffff]%d[/color]\n" % creep_count
		+ "Towers        [color=#ffffff]%d[/color]\n" % tower_count
		+ "Projectiles   [color=#ffffff]%d[/color]\n" % proj_count
		+ "──────────────────────────\n"
		+ "Attack VFX    [color=#%s]%d / %d[/color]\n" % [c_avfx, atk_vfx, atk_budget]
		+ "Dmg Numbers   [color=#%s]%d / %d[/color]\n" % [c_dn, dmg_num, DamageNumber.MAX_ACTIVE]
		+ "Status Icons  [color=#ffffff]%d[/color]\n" % status_icons
		+ "Target scans  [color=#ffffff]%d/s[/color]\n" % target_scans
		+ "──────────────────────────\n"
		+ "[b][color=#aaddff]■ CACHE / HOTPATH[/color][/b]\n"
		+ "WavePreview   [color=#%s]hit=%d miss=%d[/color]\n" % [c_cache, cache_hits, cache_misses]
		+ "ElemIcon      [color=#888888]hit=%d miss=%d[/color]\n" % [ei_hits, ei_misses]
		+ "PreviewActive [color=#ffffff]%d  redraws=%d[/color]\n" % [preview_active, preview_redraws]
		+ "SpikeFrames   [color=#%s]%d[/color]\n" % [c_spike, spike_frames]
		+ "──────────────────────────\n"
		+ "[b][color=#aaddff]■ LAST FRAME HOT SECTIONS[/color][/b]\n"
		+ section_lines
	)

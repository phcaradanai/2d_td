## PerfOverlay — lightweight live diagnostics overlay.
##
## Registered as an autoload ("PerfOverlay") in project.godot.
## Visible only in OS.is_debug_build() and only when toggled on (F11).
## Reads live counters from PerformanceBudget and static VFX budgets.
## Zero runtime cost in release builds (process disabled in _ready).
extends CanvasLayer

const LABEL_FONT_SIZE := 13
const PANEL_WIDTH     := 230
const PANEL_HEIGHT    := 270
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

	# Release builds: disable everything immediately — no overhead at all.
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return

	_panel = ColorRect.new()
	_panel.color = Color(0.0, 0.0, 0.0, 0.72)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.position = Vector2(8, 8)
	_panel.visible = false
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.size = Vector2(PANEL_WIDTH - PADDING * 2, PANEL_HEIGHT - PADDING * 2)
	_label.position = Vector2(PADDING, PADDING)
	_label.add_theme_font_size_override("normal_font_size", LABEL_FONT_SIZE)
	_panel.add_child(_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			_visible_flag = not _visible_flag
			if _panel:
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

	var fps  := Engine.get_frames_per_second()
	var f_ms := 1000.0 / maxf(float(fps), 1.0)
	var qual : String = pb.get_quality_name() if pb else "?"

	# Node group sizes (get_nodes_in_group is O(n) but only called at 0.25 s intervals).
	var creep_count  := get_tree().get_nodes_in_group("enemies").size()
	var tower_count  := get_tree().get_nodes_in_group("towers").size()
	# Projectiles group may not exist on all builds — be safe.
	var proj_count   := get_tree().get_nodes_in_group("projectiles").size()

	var atk_vfx := AttackVFX._active_count
	var dmg_num := DamageNumber._active_count

	# Godot process time from the performance monitor (microseconds → ms).
	var proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0

	# Colour helpers.
	var c_fps  := "00ff88" if fps >= 50 else ("ffcc00" if fps >= 35 else "ff4444")
	var c_qual := "00ccff" if qual == "HIGH" else ("ffcc00" if qual == "MED" else "ff4444")
	var c_avfx := "00ff88" if atk_vfx < AttackVFX.MAX_ACTIVE * 0.8 else ("ffcc00" if atk_vfx < AttackVFX.MAX_ACTIVE else "ff4444")
	var c_dn   := "00ff88" if dmg_num < DamageNumber.MAX_ACTIVE * 0.8 else ("ffcc00" if dmg_num < DamageNumber.MAX_ACTIVE else "ff4444")

	_label.text = (
		"[b][color=#aaddff]■ PERF OVERLAY[/color][/b]  [color=#555555]F11[/color]\n"
		+ "──────────────────────\n"
		+ "[color=#%s]FPS  %d  (%.1f ms)[/color]\n" % [c_fps, fps, f_ms]
		+ "Process  [color=#ffee88]%.2f ms[/color]\n" % proc_ms
		+ "Quality  [color=#%s]%s[/color]\n" % [c_qual, qual]
		+ "──────────────────────\n"
		+ "Creeps        [color=#ffffff]%d[/color]\n" % creep_count
		+ "Towers        [color=#ffffff]%d[/color]\n" % tower_count
		+ "Projectiles   [color=#ffffff]%d[/color]\n" % proj_count
		+ "──────────────────────\n"
		+ "Attack VFX    [color=#%s]%d / %d[/color]\n" % [c_avfx, atk_vfx, AttackVFX.MAX_ACTIVE]
		+ "Dmg Numbers   [color=#%s]%d / %d[/color]\n" % [c_dn, dmg_num, DamageNumber.MAX_ACTIVE]
		+ "Status VFX    [color=#ffffff]%d[/color]\n" % get_tree().get_nodes_in_group("status_vfx").size()
		+ "──────────────────────\n"
		+ "[color=#555555]Verbose targeting off\n"
		+ "Verbose combat    off[/color]"
	)

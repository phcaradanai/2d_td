extends "res://scripts/ui/modal_panel_controller.gd"
## Runtime Identity Panel
##
## Shows the runtime's identity fields and resolved access config so an admin
## can locate the install in the web panel and apply targeted overrides.
##
## Open via main_menu "ID" button.  Call refresh() before or after show().
## Closeable: X button, ESC, or backdrop click.

var _value_labels: Dictionary  = {}
var _copy_feedback: Label      = null
var _copy_timer: float         = 0.0

func _ready() -> void:
	_max_panel_width = 560.0
	_esc_closeable      = true
	_backdrop_closeable = true
	super._ready()
	set_title("RUNTIME IDENTITY")
	layer = 120   # below DemoGateModal (128)

func _process(delta: float) -> void:
	if _copy_timer > 0.0:
		_copy_timer -= delta
		if _copy_timer <= 0.0 and _copy_feedback:
			_copy_feedback.text = ""

# ── Public API ────────────────────────────────────────────────────────────────

## Populate the panel from live service nodes.  Safe to call before or after show().
## identity_svc: RuntimeIdentityService (or null)
## access_svc:   LevelAccessService (or null)
func refresh(identity_svc: Node, access_svc: Node) -> void:
	_set_field("runtime_id",  _safe(identity_svc, "get_runtime_id"))
	_set_field("install_id",  _safe(identity_svc, "get_install_id"))
	_set_field("session_id",  _safe(identity_svc, "get_runtime_session_id"))
	_set_field("build_id",    _safe(identity_svc, "get_build_id"))
	_set_field("platform",    _safe(identity_svc, "get_platform"))

	if access_svc:
		_set_field("access_mode",    access_svc.get_access_mode())
		_set_field("config_version", str(access_svc.get_config_version()))
		_set_field("config_source",  access_svc.get_access_source())
		var resolved = access_svc.get_resolved_from()
		_set_field("resolved_from",  resolved if resolved != "" else "global_default")
		var tags: Array = access_svc.get_tags()
		_set_field("tags", ", ".join(tags) if not tags.is_empty() else "—")
	else:
		for key in ["access_mode", "config_version", "config_source", "resolved_from", "tags"]:
			_set_field(key, "—")

	call_deferred("_on_viewport_resized")

# ── Build content ─────────────────────────────────────────────────────────────

func _build_modal_content() -> void:
	# ── Scroll body: Identity section ────────────────────────────────────────
	_scroll_content.add_child(_section_header("IDENTITY"))
	_add_copyable_row("Runtime ID",  "runtime_id")
	_add_copyable_row("Install ID",  "install_id")
	_add_plain_row("Session ID",    "session_id")
	_add_plain_row("Build ID",      "build_id")
	_add_plain_row("Platform",      "platform")

	_add_separator(_scroll_content)

	# ── Scroll body: Access section ───────────────────────────────────────────
	_scroll_content.add_child(_section_header("ACCESS CONFIG"))
	_add_plain_row("Access Mode",    "access_mode")
	_add_plain_row("Config Version", "config_version")
	_add_plain_row("Config Source",  "config_source")
	_add_plain_row("Resolved From",  "resolved_from")
	_add_plain_row("Tags",           "tags")

	# ── Footer ────────────────────────────────────────────────────────────────
	_copy_feedback = Label.new()
	_copy_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_copy_feedback.add_theme_font_size_override("font_size", 12)
	_copy_feedback.add_theme_color_override("font_color", _C_OK)
	_copy_feedback.text = ""
	_footer.add_child(_copy_feedback)

	var close_btn: Button = Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0.0, 44.0)
	close_btn.add_theme_font_size_override("font_size", 14)
	_apply_btn_style(close_btn, _C_CYAN)
	close_btn.pressed.connect(_on_close_pressed)
	_footer.add_child(close_btn)

# ── Row helpers ───────────────────────────────────────────────────────────────

func _section_header(text: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", _C_INK3)
	return lbl

func _add_plain_row(label_text: String, key: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_scroll_content.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", _C_INK3)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.custom_minimum_size = Vector2(140.0, 0.0)
	hbox.add_child(lbl)

	var val: Label = Label.new()
	val.text = "—"
	val.add_theme_color_override("font_color", _C_INK1)
	val.add_theme_font_size_override("font_size", 13)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.clip_text = true
	hbox.add_child(val)
	_value_labels[key] = val

func _add_copyable_row(label_text: String, key: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_scroll_content.add_child(hbox)

	var lbl: Label = Label.new()
	lbl.text = label_text + ":"
	lbl.add_theme_color_override("font_color", _C_INK3)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.custom_minimum_size = Vector2(140.0, 0.0)
	hbox.add_child(lbl)

	var val: Label = Label.new()
	val.text = "—"
	val.add_theme_color_override("font_color", _C_WARN)
	val.add_theme_font_size_override("font_size", 13)
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.clip_text = true
	hbox.add_child(val)
	_value_labels[key] = val

	var copy_btn: Button = Button.new()
	copy_btn.text = "COPY"
	copy_btn.custom_minimum_size = Vector2(52.0, 26.0)
	copy_btn.focus_mode = Control.FOCUS_NONE
	copy_btn.add_theme_font_size_override("font_size", 11)
	_apply_btn_style(copy_btn, _C_CYAN)
	copy_btn.pressed.connect(func(): _copy_value(key))
	hbox.add_child(copy_btn)

# ── Internals ─────────────────────────────────────────────────────────────────

func _set_field(key: String, value: String) -> void:
	if _value_labels.has(key):
		_value_labels[key].text = value if value != "" else "—"

func _copy_value(key: String) -> void:
	if not _value_labels.has(key):
		return
	var text: String = _value_labels[key].text
	if text == "—" or text.is_empty():
		return
	DisplayServer.clipboard_set(text)
	if _copy_feedback:
		_copy_feedback.text = "Copied: " + text.substr(0, 48)
		_copy_timer = 2.5

func _safe(node: Node, method: String) -> String:
	if node and node.has_method(method):
		return str(node.call(method))
	return "—"

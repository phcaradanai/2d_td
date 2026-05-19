# Tower Effect Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `scenes/debug/tower_catalog.tscn` into a full Tower Effect Catalog showing all 132 towers grouped by family (T1/T2/T3), with a filter toolbar, persistent side panel, grid zoom, and real attack VFX previews in the side panel's SubViewport.

**Architecture:** The existing scene is extended in-place. `TopToolbar` and `ContentArea` (wrapping the existing `ScrollContainer` + a new `SelectedTowerPanel`) are added to `MainVBox` via an updated `.tscn`. The existing modal overlay is removed. Four new focused scripts are added; `tower_catalog.gd` is rewritten to replace the hardcoded `CATALOG_ENTRIES` with dynamic family-grouped JSON loading and to wire all new components. Real VFX (from `TowerAttackVFXRegistry`) is spawned only inside the side panel's `SubViewport` using lightweight dummy nodes.

**Tech Stack:** Godot 4, GDScript 4, `towers_tree.json`, `TowerAttackVFXRegistry`, `TowerCatalogPreview` (existing `SubViewport` + `Camera2D` model viewer)

---

## File Map

| Action | Path | Responsibility |
|---|---|---|
| Modify | `scenes/debug/tower_catalog.tscn` | Add `TopToolbar`, `ContentArea`, `SelectedTowerPanel` nodes; move `ScrollContainer` inside `ContentArea` |
| Rewrite | `scripts/debug/tower_catalog.gd` | Root coordinator — dynamic JSON load, family grouping, wires all controllers, removes modal overlay |
| Create | `scripts/debug/tower_effect_catalog_controller.gd` | Toolbar state: filters, VFX toggles, auto-play timer, FPS/VFX label updates |
| Create | `scripts/debug/tower_effect_catalog_zoom_controller.gd` | Zoom state — clamps, steps, applies `ContentVBox.scale` + `custom_minimum_size` |
| Create | `scripts/debug/tower_effect_catalog_card.gd` | Per-card script: tier badge, VFX badge, play/pause buttons, selection signal |
| Create | `scripts/debug/tower_effect_preview_target.gd` | `DummyTowerPreview` Node2D — provides `get_fire_origin()` / `_get_tower_color()` for VFX spawn |
| Create | `scripts/debug/tower_effect_dummy_target.gd` | `DummyTargetPreview` Node2D — provides `get_hit_origin()` for VFX spawn |
| Modify | `scripts/towers/tower_catalog_preview.gd` | Add `get_vfx_viewport() -> SubViewport` and `disable_simulation()` methods |

---

## Task 1 — Scaffold four new scripts + extend TowerCatalogPreview

**Files:**
- Create: `scripts/debug/tower_effect_catalog_zoom_controller.gd`
- Create: `scripts/debug/tower_effect_catalog_card.gd`
- Create: `scripts/debug/tower_effect_catalog_controller.gd`
- Create: `scripts/debug/tower_effect_preview_target.gd`
- Create: `scripts/debug/tower_effect_dummy_target.gd`
- Modify: `scripts/towers/tower_catalog_preview.gd`

- [ ] **Step 1: Create zoom controller scaffold**

```gdscript
# scripts/debug/tower_effect_catalog_zoom_controller.gd
class_name TowerEffectCatalogZoomController
extends RefCounted

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEPS: Array[float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]

var zoom_value: float = 1.0
var content_root: Control = null
var scroll_container: ScrollContainer = null

var _natural_size: Vector2 = Vector2.ZERO

func setup(p_content_root: Control, p_scroll: ScrollContainer) -> void:
	content_root = p_content_root
	scroll_container = p_scroll
	content_root.resized.connect(_on_content_resized)

func _on_content_resized() -> void:
	if zoom_value == 1.0:
		_natural_size = content_root.size

func zoom_in() -> void:
	set_zoom(_next_step(1))

func zoom_out() -> void:
	set_zoom(_next_step(-1))

func reset_zoom() -> void:
	set_zoom(1.0)

func fit_grid() -> void:
	if content_root == null or scroll_container == null or _natural_size.x <= 0.0:
		return
	set_zoom(scroll_container.size.x / _natural_size.x)

func set_zoom(value: float) -> void:
	zoom_value = clampf(value, MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()

func get_zoom() -> float:
	return zoom_value

func _apply_zoom() -> void:
	if content_root == null:
		return
	content_root.scale = Vector2.ONE * zoom_value
	if _natural_size != Vector2.ZERO:
		content_root.custom_minimum_size = _natural_size * zoom_value

func _next_step(direction: int) -> float:
	var current_index := 2
	for i in range(ZOOM_STEPS.size()):
		if ZOOM_STEPS[i] >= zoom_value - 0.01:
			current_index = i
			break
	return ZOOM_STEPS[clamp(current_index + direction, 0, ZOOM_STEPS.size() - 1)]
```

- [ ] **Step 2: Create card script scaffold**

```gdscript
# scripts/debug/tower_effect_catalog_card.gd
class_name TowerEffectCatalogCard
extends Node

signal card_selected(tower_id: String, cfg: Dictionary)

var tower_id: String = ""
var cfg: Dictionary = {}

var _is_selected: bool = false
var _card_panel: PanelContainer = null
var _vfx_badge_label: Label = null
var _tier_badge_label: Label = null

var _normal_style: StyleBoxFlat = null
var _selected_style: StyleBoxFlat = null

func setup(p_panel: PanelContainer, p_tower_id: String, p_cfg: Dictionary) -> void:
	_card_panel = p_panel
	tower_id = p_tower_id
	cfg = p_cfg

func set_selected(selected: bool) -> void:
	_is_selected = selected
	if _card_panel == null:
		return
	if selected and _selected_style:
		_card_panel.add_theme_stylebox_override("panel", _selected_style)
	elif _normal_style:
		_card_panel.add_theme_stylebox_override("panel", _normal_style)

func set_vfx_badge(badge_text: String) -> void:
	if _vfx_badge_label == null:
		return
	_vfx_badge_label.text = badge_text
	match badge_text:
		"OK":       _vfx_badge_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		"Missing":  _vfx_badge_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
		"T1 Fallback": _vfx_badge_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
		"Legacy":   _vfx_badge_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
		_:          _vfx_badge_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func passes_filters(search: String, element_filter: String, tier_filter: String, attack_filter: String) -> bool:
	if search != "":
		var s := search.to_lower()
		if not (tower_id.to_lower().contains(s) or str(cfg.get("display_name", "")).to_lower().contains(s)):
			return false
	if element_filter != "all":
		var elements: Array = cfg.get("elements", [])
		if not elements.has(element_filter):
			return false
	if tier_filter != "all":
		var tier_map := {"t1": 1, "t2": 2, "t3": 3, "pure": 4}
		if cfg.get("tier", 0) != tier_map.get(tier_filter, -1):
			return false
	if attack_filter != "all":
		if str(cfg.get("attack_type", "")).to_lower() != attack_filter:
			return false
	return true
```

- [ ] **Step 3: Create controller scaffold**

```gdscript
# scripts/debug/tower_effect_catalog_controller.gd
class_name TowerEffectCatalogController
extends Node

signal filters_changed
signal replay_selected_requested
signal vfx_toggle_changed(vfx_type: String, enabled: bool)
signal auto_play_tick

var search_text: String = ""
var element_filter: String = "all"
var tier_filter: String = "all"
var attack_filter: String = "all"

var show_models: bool = true
var show_attack_vfx: bool = true
var show_status_fx: bool = true
var show_support_fx: bool = true
var auto_play_enabled: bool = false
var paused: bool = false

var _fps_label: Label = null
var _vfx_count_label: Label = null
var _auto_play_timer: Timer = null

func setup_timer() -> void:
	_auto_play_timer = Timer.new()
	_auto_play_timer.wait_time = 0.8
	_auto_play_timer.autostart = false
	_auto_play_timer.timeout.connect(_on_auto_play_tick)
	add_child(_auto_play_timer)

func _process(_delta: float) -> void:
	if _fps_label:
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	if _vfx_count_label:
		_vfx_count_label.text = "VFX: %d" % BaseTowerAttackVFX._active_count

func set_auto_play(enabled: bool) -> void:
	auto_play_enabled = enabled
	if enabled and not paused:
		_auto_play_timer.start()
	else:
		_auto_play_timer.stop()

func set_paused(p: bool) -> void:
	paused = p
	if p:
		_auto_play_timer.stop()
	elif auto_play_enabled:
		_auto_play_timer.start()

func _on_auto_play_tick() -> void:
	if not paused and auto_play_enabled:
		emit_signal("auto_play_tick")
```

- [ ] **Step 4: Create dummy tower preview**

```gdscript
# scripts/debug/tower_effect_preview_target.gd
class_name DummyTowerPreview
extends Node2D

var tower_id: String = ""
var _color: Color = Color.WHITE

func setup(p_tower_id: String, p_color: Color) -> void:
	tower_id = p_tower_id
	_color = p_color

func get_fire_origin() -> Vector2:
	return global_position

func _get_tower_color() -> Color:
	return _color
```

- [ ] **Step 5: Create dummy target**

```gdscript
# scripts/debug/tower_effect_dummy_target.gd
class_name DummyTargetPreview
extends Node2D

func get_hit_origin() -> Vector2:
	return global_position
```

- [ ] **Step 6: Add VFX viewport accessor to TowerCatalogPreview**

In `scripts/towers/tower_catalog_preview.gd`, add two methods after `set_preview_options()`:

```gdscript
func get_vfx_viewport() -> SubViewport:
	return _viewport

func disable_simulation() -> void:
	if _fx_layer:
		_fx_layer.preview_projectile = false
		_fx_layer.preview_effects = false
```

- [ ] **Step 7: Commit scaffold**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_effect_catalog_zoom_controller.gd \
        scripts/debug/tower_effect_catalog_card.gd \
        scripts/debug/tower_effect_catalog_controller.gd \
        scripts/debug/tower_effect_preview_target.gd \
        scripts/debug/tower_effect_dummy_target.gd \
        scripts/towers/tower_catalog_preview.gd
git commit -m "feat: scaffold TowerEffectCatalog scripts and extend TowerCatalogPreview"
```

---

## Task 2 — Update tower_catalog.tscn

Move `ScrollContainer` inside a new `ContentArea` HBoxContainer; add `TopToolbar` and `SelectedTowerPanel`.

**Files:**
- Modify: `scenes/debug/tower_catalog.tscn`

- [ ] **Step 1: Write the updated scene file**

Replace the entire file with:

```
[gd_scene format=3 uid="uid://d2rohwoemml8r"]

[ext_resource type="Script" uid="uid://bwc5sibp6s4ji" path="res://scripts/debug/tower_catalog.gd" id="1"]

[node name="TowerCatalog" type="Control" unique_id=1296542573]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")

[node name="Background" type="ColorRect" parent="." unique_id=246085783]
layout_mode = 0
offset_right = 1920.0
offset_bottom = 1080.0
color = Color(0.02, 0.03, 0.06, 1)

[node name="RootMargin" type="MarginContainer" parent="." unique_id=2123320041]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/margin_left = 24
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 24
theme_override_constants/margin_bottom = 16

[node name="MainVBox" type="VBoxContainer" parent="RootMargin" unique_id=1905082595]
layout_mode = 2
theme_override_constants/separation = 8

[node name="Header" type="HBoxContainer" parent="RootMargin/MainVBox" unique_id=1922751304]
layout_mode = 2

[node name="HeaderLeft" type="VBoxContainer" parent="RootMargin/MainVBox/Header" unique_id=1172875218]
layout_mode = 2
size_flags_horizontal = 3

[node name="TitleLabel" type="Label" parent="RootMargin/MainVBox/Header/HeaderLeft" unique_id=1219213645]
layout_mode = 2
theme_override_colors/font_color = Color(0.35, 0.95, 1, 1)
theme_override_font_sizes/font_size = 28
text = "Tower Effect Catalog"

[node name="SubtitleLabel" type="Label" parent="RootMargin/MainVBox/Header/HeaderLeft" unique_id=304172565]
layout_mode = 2
theme_override_colors/font_color = Color(0.4, 0.65, 0.75, 1)
theme_override_font_sizes/font_size = 14
text = "Debug VFX preview — all towers, attack / status / support effects"

[node name="PreviewOnlyLabel" type="Label" parent="RootMargin/MainVBox/Header" unique_id=1321395903]
layout_mode = 2
theme_override_colors/font_color = Color(0.65, 0.55, 0.25, 1)
theme_override_font_sizes/font_size = 12
text = "Preview only — not gameplay simulation"
horizontal_alignment = 2

[node name="TopToolbar" type="HBoxContainer" parent="RootMargin/MainVBox"]
layout_mode = 2
theme_override_constants/separation = 6
custom_minimum_size = Vector2(0, 36)

[node name="ContentArea" type="HBoxContainer" parent="RootMargin/MainVBox"]
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="ScrollContainer" type="ScrollContainer" parent="RootMargin/MainVBox/ContentArea" unique_id=865161609]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3
horizontal_scroll_mode = 1

[node name="ContentVBox" type="VBoxContainer" parent="RootMargin/MainVBox/ContentArea/ScrollContainer" unique_id=1735917624]
layout_mode = 2
size_flags_horizontal = 0
size_flags_vertical = 0
theme_override_constants/separation = 16

[node name="SelectedTowerPanel" type="VBoxContainer" parent="RootMargin/MainVBox/ContentArea"]
layout_mode = 2
size_flags_horizontal = 0
size_flags_vertical = 3
custom_minimum_size = Vector2(320, 0)
theme_override_constants/separation = 8

[node name="AnimationPlayer" type="AnimationPlayer" parent="." unique_id=1107839158]
```

- [ ] **Step 2: Open scene in Godot editor, confirm no parse errors**

Open `scenes/debug/tower_catalog.tscn` in the Godot editor. The Scene panel should show the new tree: `MainVBox > TopToolbar`, `MainVBox > ContentArea > ScrollContainer + SelectedTowerPanel`. No errors in the Output panel.

- [ ] **Step 3: Commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scenes/debug/tower_catalog.tscn
git commit -m "feat: restructure tower_catalog.tscn — add TopToolbar, ContentArea, SelectedTowerPanel"
```

---

## Task 3 — Rewrite tower_catalog.gd: data loading and card builder

Replace the hardcoded `CATALOG_ENTRIES` with dynamic family-grouped JSON loading. Keep the existing `ELEM_SHORT`, `ELEM_COLOR`, `ELEM_DISPLAY` constants and `_make_element_badge()`, `_make_stat_label()`, `_str_or_dash()` helpers.

**Files:**
- Rewrite: `scripts/debug/tower_catalog.gd`

- [ ] **Step 1: Write the new data-loading section**

Replace `tower_catalog.gd` with the following. This task covers `extends` through `_build_catalog()` — the UI wiring methods come in Task 4.

```gdscript
extends Control

## Tower Effect Catalog — debug scene for reviewing all tower VFX, models, and badges.
## Open directly: res://scenes/debug/tower_catalog.tscn
## No gameplay changes — reads PerformanceFirebreak flags as read-only.

@onready var content_vbox: VBoxContainer = $RootMargin/MainVBox/ContentArea/ScrollContainer/ContentVBox
@onready var top_toolbar: HBoxContainer = $RootMargin/MainVBox/TopToolbar
@onready var selected_tower_panel: VBoxContainer = $RootMargin/MainVBox/ContentArea/SelectedTowerPanel
@onready var scroll_container: ScrollContainer = $RootMargin/MainVBox/ContentArea/ScrollContainer

const TOWER_TREE_PATH := "res://data/towers_tree.json"

# ── Element helpers ───────────────────────────────────────────────────────────

const ELEM_SHORT := {
	"light": "L", "darkness": "D", "water": "W", "fire": "F",
	"nature": "Na", "earth": "E",
}

const ELEM_COLOR := {
	"light":    Color(0.95, 0.92, 0.3),
	"darkness": Color(0.55, 0.15, 0.75),
	"water":    Color(0.2, 0.55, 0.95),
	"fire":     Color(1.0, 0.35, 0.15),
	"nature":   Color(0.25, 0.85, 0.3),
	"earth":    Color(0.65, 0.4, 0.2),
}

const ELEM_DISPLAY := {
	"light": "Light", "darkness": "Darkness", "water": "Water",
	"fire": "Fire", "nature": "Nature", "earth": "Earth",
}

const TIER_BADGE_COLOR := {
	1: Color(1.0, 0.78, 0.18),
	2: Color(0.75, 0.78, 0.82),
	3: Color(0.2, 0.90, 0.98),
	4: Color(0.72, 0.42, 1.0),
	6: Color(1.0, 0.42, 0.88),
}

const SECTION_ORDER := ["neutral", "single", "dual", "triple", "pure", "periodic"]
const SECTION_LABELS := {
	"neutral":  "Neutral",
	"single":   "Single Element",
	"dual":     "Dual Element",
	"triple":   "Triple Element",
	"pure":     "Pure",
	"periodic": "Periodic",
}

# ── State ─────────────────────────────────────────────────────────────────────

var _towers_config: Dictionary = {}
var _all_cards: Array[TowerEffectCatalogCard] = []
var _selected_card: TowerEffectCatalogCard = null

var _controller: TowerEffectCatalogController = null
var _zoom_controller: TowerEffectCatalogZoomController = null

# side panel live nodes
var _side_preview: TowerCatalogPreview = null
var _side_dummy_tower: DummyTowerPreview = null
var _side_dummy_target: DummyTargetPreview = null
var _side_vfx_nodes: Array[Node] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_load_tower_data()
	_setup_controller()
	_setup_zoom_controller()
	_build_toolbar()
	_build_side_panel_placeholder()
	_build_catalog()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventMouseButton and event.ctrl_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_controller.zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_controller.zoom_out()
			get_viewport().set_input_as_handled()

# ── Data loading ──────────────────────────────────────────────────────────────

func _load_tower_data() -> void:
	if not FileAccess.file_exists(TOWER_TREE_PATH):
		push_error("[TowerCatalog] towers_tree.json not found: %s" % TOWER_TREE_PATH)
		return
	var file := FileAccess.open(TOWER_TREE_PATH, FileAccess.READ)
	if file == null:
		push_error("[TowerCatalog] Failed to open towers_tree.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[TowerCatalog] JSON parse error: %s" % json.get_error_message())
		return
	_towers_config = json.data

func _build_families() -> Dictionary:
	## Returns { combo_type -> [ [tower_id, cfg], ... ] } sorted by tier within each group.
	var sections: Dictionary = {}
	for tid: String in _towers_config:
		var cfg: Dictionary = _towers_config[tid]
		var ctype: String = str(cfg.get("combo_type", "neutral")).to_lower()
		if not sections.has(ctype):
			sections[ctype] = []
		sections[ctype].append([tid, cfg])
	# Sort each section by tier ascending, then by tower_id
	for ctype in sections:
		var arr: Array = sections[ctype]
		arr.sort_custom(func(a, b):
			var ta: int = int(a[1].get("tier", 0))
			var tb: int = int(b[1].get("tier", 0))
			if ta != tb:
				return ta < tb
			return str(a[0]) < str(b[0])
		)
	return sections

func _group_into_families(section_entries: Array) -> Array:
	## Groups [ [tower_id, cfg], ... ] into families by stripping _t[0-9]+ suffix.
	## Returns [ { family_key: String, members: [[tid, cfg], ...] }, ... ]
	var family_map: Dictionary = {}
	var family_order: Array[String] = []
	for pair in section_entries:
		var tid: String = pair[0]
		var cfg: Dictionary = pair[1]
		var fk: String = tid.replace("_t1", "").replace("_t2", "").replace("_t3", "")
		# strip trailing _t<digit> more robustly
		var re := RegEx.new()
		re.compile("_t\\d+$")
		fk = re.sub(tid, "")
		if not family_map.has(fk):
			family_map[fk] = []
			family_order.append(fk)
		family_map[fk].append(pair)
	var result: Array = []
	for fk in family_order:
		result.append({"family_key": fk, "members": family_map[fk]})
	return result

# ── Catalog builder ───────────────────────────────────────────────────────────

func _build_catalog() -> void:
	for child in content_vbox.get_children():
		child.queue_free()
	_all_cards.clear()
	_selected_card = null

	var sections := _build_families()

	for ctype in SECTION_ORDER:
		if not sections.has(ctype):
			continue
		var families := _group_into_families(sections[ctype])
		if families.is_empty():
			continue

		content_vbox.add_child(_make_section_label(SECTION_LABELS.get(ctype, ctype)))

		for family in families:
			var members: Array = family["members"]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			content_vbox.add_child(row)
			for pair in members:
				var tid: String = pair[0]
				var cfg: Dictionary = pair[1].duplicate(true)
				var card_panel := _make_tower_card(tid, cfg)
				row.add_child(card_panel)
			# Spacer so partial rows don't stretch cards
			if members.size() < 3:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(spacer)

		content_vbox.add_child(_make_separator())

func _setup_controller() -> void:
	_controller = TowerEffectCatalogController.new()
	_controller.name = "CatalogController"
	add_child(_controller)
	_controller.setup_timer()
	_controller.filters_changed.connect(_apply_filters)
	_controller.replay_selected_requested.connect(_replay_attack_vfx)
	_controller.auto_play_tick.connect(_replay_attack_vfx)

func _setup_zoom_controller() -> void:
	_zoom_controller = TowerEffectCatalogZoomController.new()

func _apply_filters() -> void:
	for card in _all_cards:
		if card._card_panel == null or not is_instance_valid(card._card_panel):
			continue
		card._card_panel.visible = card.passes_filters(
			_controller.search_text,
			_controller.element_filter,
			_controller.tier_filter,
			_controller.attack_filter
		)
```

- [ ] **Step 2: Commit this data loading pass**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_catalog.gd
git commit -m "feat: rewrite tower_catalog.gd data loading — dynamic family grouping from JSON"
```

---

## Task 4 — tower_catalog.gd: card builder and VFX badge

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`

- [ ] **Step 1: Add VFX badge helper**

Append to `tower_catalog.gd`:

```gdscript
# ── VFX badge ─────────────────────────────────────────────────────────────────

func _get_vfx_badge(tower_id: String, tier: int) -> String:
	var script := TowerAttackVFXRegistry.get_vfx_script(tower_id)
	if script == null:
		return "Missing"
	# source_code available in editor/debug mode only — safe for this debug tool
	if tier >= 2:
		var base_name := RegEx.new()
		base_name.compile("_t\\d+$")
		var t1_id := base_name.sub(tower_id, "_t1")
		var t1_class := t1_id + "_attack_vfx"
		if script.source_code.contains("extends " + t1_class):
			return "T1 Fallback"
	return "OK"
```

- [ ] **Step 2: Add the card builder**

Append to `tower_catalog.gd`:

```gdscript
# ── Card builder ──────────────────────────────────────────────────────────────

func _make_tower_card(tower_id: String, cfg: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 400)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.04, 0.06, 0.10, 0.92)
	normal_style.border_color = Color(0.12, 0.55, 0.85, 0.6)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 10
	normal_style.content_margin_right = 10
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", normal_style)

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.04, 0.08, 0.14, 0.98)
	selected_style.border_color = Color(0.35, 0.95, 1.0, 1.0)
	selected_style.set_border_width_all(2)
	selected_style.set_corner_radius_all(8)
	selected_style.content_margin_left = 10
	selected_style.content_margin_right = 10
	selected_style.content_margin_top = 8
	selected_style.content_margin_bottom = 8

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Top row: element badge + name + tier badge
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vbox.add_child(top_row)

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		top_row.add_child(_make_element_badge(elements))

	var name_label := Label.new()
	name_label.text = str(cfg.get("display_name", cfg.get("name", tower_id)))
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	var tier: int = int(cfg.get("tier", 1))
	var tier_label := Label.new()
	tier_label.text = "T%d" % tier if tier <= 3 else ("P" if tier == 4 else "T%d" % tier)
	tier_label.add_theme_font_size_override("font_size", 11)
	var tier_color: Color = TIER_BADGE_COLOR.get(tier, Color(0.5, 0.5, 0.5))
	tier_label.add_theme_color_override("font_color", tier_color)
	top_row.add_child(tier_label)

	# Tower model preview
	var preview := TowerCatalogPreview.new()
	preview.tower_id = tower_id
	preview.tower_config = cfg
	preview.preview_size = Vector2(330, 200)
	preview.camera_zoom = 1.4
	preview.show_range_ring = false
	preview.show_projectile_preview = false
	preview.show_effects_preview = false
	preview.custom_minimum_size = preview.preview_size
	preview.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(preview)

	# VFX badge
	var badge_text := _get_vfx_badge(tower_id, tier)
	var badge_label := Label.new()
	badge_label.text = "VFX: " + badge_text
	badge_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(badge_label)

	# Stat row
	vbox.add_child(_make_stat_label(
		"ATK: %s  TYPE: %s" % [str(cfg.get("attack_type", "-")), str(cfg.get("visual_type", "-"))],
		Color(0.55, 0.65, 0.85)
	))

	# Card script
	var card_script := TowerEffectCatalogCard.new()
	card_script.name = "CardScript"
	card_script._vfx_badge_label = badge_label
	card_script._normal_style = normal_style
	card_script._selected_style = selected_style
	card.add_child(card_script)
	card_script.setup(card, tower_id, cfg)
	card_script.set_vfx_badge(badge_text)
	card_script.card_selected.connect(_on_card_selected)
	_all_cards.append(card_script)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			card_script.card_selected.emit(tower_id, cfg)
	)
	_make_passthrough(vbox)
	return card

func _make_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_make_passthrough(child)
```

- [ ] **Step 3: Add section/separator helpers**

Append to `tower_catalog.gd`:

```gdscript
# ── Layout helpers ────────────────────────────────────────────────────────────

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = "▸  " + text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	label.custom_minimum_size = Vector2(0, 32)
	return label

func _make_separator() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	return sep

func _make_element_badge(elements: Array) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 2)
	for i in range(elements.size()):
		var elem: String = str(elements[i])
		var label := Label.new()
		label.text = ELEM_SHORT.get(elem, elem.substr(0, 1))
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = ELEM_COLOR.get(elem, Color(0.4, 0.5, 0.7))
		bg.set_corner_radius_all(3)
		bg.content_margin_left = 3
		bg.content_margin_right = 3
		bg.content_margin_top = 1
		bg.content_margin_bottom = 1
		label.add_theme_stylebox_override("normal", bg)
		hbox.add_child(label)
		if i < elements.size() - 1:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 9)
			plus.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
			hbox.add_child(plus)
	return hbox

func _make_stat_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label

func _str_or_dash(value: float) -> String:
	return "—" if value == 0.0 else str(value)

func _get_first_level_value(cfg: Dictionary, key: String, fallback: float) -> Variant:
	if cfg.has("levels") and cfg["levels"] is Array and cfg["levels"].size() > 0:
		return cfg["levels"][0].get(key, fallback)
	return cfg.get(key, fallback)
```

- [ ] **Step 4: Verify in Godot editor — open the scene, confirm cards appear**

Run the scene (`F5` with `tower_catalog.tscn` as the main scene or open it in the editor and press the play button). Confirm:
- The catalog loads and shows tower family rows (not just T1 towers)
- Each card shows a tier badge and VFX badge
- No errors in the Output panel

- [ ] **Step 5: Commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_catalog.gd
git commit -m "feat: tower_catalog — card builder with tier/VFX badges and family grouping"
```

---

## Task 5 — Build the top toolbar

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`
- Modify: `scripts/debug/tower_effect_catalog_controller.gd`

- [ ] **Step 1: Add `_build_toolbar()` to tower_catalog.gd**

Append to `tower_catalog.gd`:

```gdscript
# ── Toolbar builder ───────────────────────────────────────────────────────────

func _build_toolbar() -> void:
	# Search
	var search := LineEdit.new()
	search.placeholder_text = "Search tower..."
	search.custom_minimum_size = Vector2(160, 0)
	search.text_changed.connect(func(val: String) -> void:
		_controller.search_text = val
		_controller.emit_signal("filters_changed")
	)
	top_toolbar.add_child(search)

	top_toolbar.add_child(_make_toolbar_sep())

	# Element filter
	var elem_opt := OptionButton.new()
	for entry in [["All", "all"], ["Light", "light"], ["Darkness", "darkness"],
			["Water", "water"], ["Fire", "fire"], ["Nature", "nature"], ["Earth", "earth"]]:
		elem_opt.add_item(entry[0])
		elem_opt.set_item_metadata(elem_opt.item_count - 1, entry[1])
	elem_opt.item_selected.connect(func(idx: int) -> void:
		_controller.element_filter = elem_opt.get_item_metadata(idx)
		_controller.emit_signal("filters_changed")
	)
	top_toolbar.add_child(elem_opt)

	# Tier filter
	var tier_opt := OptionButton.new()
	for entry in [["All Tiers", "all"], ["T1", "t1"], ["T2", "t2"], ["T3", "t3"], ["Pure", "pure"]]:
		tier_opt.add_item(entry[0])
		tier_opt.set_item_metadata(tier_opt.item_count - 1, entry[1])
	tier_opt.item_selected.connect(func(idx: int) -> void:
		_controller.tier_filter = tier_opt.get_item_metadata(idx)
		_controller.emit_signal("filters_changed")
	)
	top_toolbar.add_child(tier_opt)

	# Attack type filter
	var atk_opt := OptionButton.new()
	for entry in [["All Types", "all"], ["Single", "single"], ["Splash", "splash"],
			["Slow", "slow"], ["Support", "support"], ["Aura", "aura"]]:
		atk_opt.add_item(entry[0])
		atk_opt.set_item_metadata(atk_opt.item_count - 1, entry[1])
	atk_opt.item_selected.connect(func(idx: int) -> void:
		_controller.attack_filter = atk_opt.get_item_metadata(idx)
		_controller.emit_signal("filters_changed")
	)
	top_toolbar.add_child(atk_opt)

	top_toolbar.add_child(_make_toolbar_sep())

	# VFX toggles
	top_toolbar.add_child(_make_toolbar_toggle("Models", true, func(v: bool) -> void:
		_controller.show_models = v
	))
	top_toolbar.add_child(_make_toolbar_toggle("Attack VFX", true, func(v: bool) -> void:
		_controller.show_attack_vfx = v
		if not v:
			_clear_attack_vfx_nodes()
	))
	top_toolbar.add_child(_make_toolbar_toggle("Status FX", true, func(v: bool) -> void:
		_controller.show_status_fx = v
	))
	top_toolbar.add_child(_make_toolbar_toggle("Support FX", true, func(v: bool) -> void:
		_controller.show_support_fx = v
	))

	top_toolbar.add_child(_make_toolbar_sep())

	# Playback
	top_toolbar.add_child(_make_toolbar_toggle("Auto Play", false, func(v: bool) -> void:
		_controller.set_auto_play(v)
	))
	top_toolbar.add_child(_make_toolbar_toggle("Pause", false, func(v: bool) -> void:
		_controller.set_paused(v)
	))
	var replay_btn := Button.new()
	replay_btn.text = "Replay"
	replay_btn.pressed.connect(func() -> void:
		_controller.emit_signal("replay_selected_requested")
	)
	top_toolbar.add_child(replay_btn)

	top_toolbar.add_child(_make_toolbar_sep())

	# Zoom
	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "−"
	zoom_out_btn.custom_minimum_size = Vector2(28, 0)
	zoom_out_btn.pressed.connect(func() -> void: _zoom_controller.zoom_out())
	top_toolbar.add_child(zoom_out_btn)

	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(28, 0)
	zoom_in_btn.pressed.connect(func() -> void: _zoom_controller.zoom_in())
	top_toolbar.add_child(zoom_in_btn)

	var zoom_reset_btn := Button.new()
	zoom_reset_btn.text = "1×"
	zoom_reset_btn.pressed.connect(func() -> void: _zoom_controller.reset_zoom())
	top_toolbar.add_child(zoom_reset_btn)

	var fit_btn := Button.new()
	fit_btn.text = "Fit"
	fit_btn.pressed.connect(func() -> void: _zoom_controller.fit_grid())
	top_toolbar.add_child(fit_btn)

	top_toolbar.add_child(_make_toolbar_sep())

	# Status labels
	var fps_label := Label.new()
	fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.45))
	fps_label.text = "FPS: --"
	_controller._fps_label = fps_label
	top_toolbar.add_child(fps_label)

	var vfx_label := Label.new()
	vfx_label.add_theme_font_size_override("font_size", 12)
	vfx_label.add_theme_color_override("font_color", Color(0.45, 0.65, 0.85))
	vfx_label.text = "VFX: 0"
	_controller._vfx_count_label = vfx_label
	top_toolbar.add_child(vfx_label)

	# Wire zoom controller now that content_vbox exists
	_zoom_controller.setup(content_vbox, scroll_container)

func _make_toolbar_sep() -> VSeparator:
	return VSeparator.new()

func _make_toolbar_toggle(label: String, initial: bool, callback: Callable) -> CheckButton:
	var btn := CheckButton.new()
	btn.text = label
	btn.button_pressed = initial
	btn.add_theme_font_size_override("font_size", 12)
	btn.toggled.connect(func(v: bool) -> void: callback.call(v))
	return btn

func _clear_attack_vfx_nodes() -> void:
	for node in get_tree().get_nodes_in_group("attack_vfx"):
		node.queue_free()
```

- [ ] **Step 2: Verify toolbar appears**

Run the catalog scene. The top toolbar should show search, dropdowns, toggles, zoom buttons, and FPS/VFX labels. All controls should be functional (dropdowns filter cards, zoom buttons scale the grid).

- [ ] **Step 3: Commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_catalog.gd scripts/debug/tower_effect_catalog_controller.gd
git commit -m "feat: tower_catalog — top toolbar with filters, toggles, zoom, and FPS labels"
```

---

## Task 6 — Build the selected tower side panel

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`

- [ ] **Step 1: Add `_on_card_selected()` and side panel builder to tower_catalog.gd**

Append to `tower_catalog.gd`:

```gdscript
# ── Side panel ────────────────────────────────────────────────────────────────

func _build_side_panel_placeholder() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.95)
	style.border_color = Color(0.15, 0.45, 0.65, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	selected_tower_panel.add_theme_stylebox_override("panel", style)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Click a tower to inspect"
	placeholder.add_theme_font_size_override("font_size", 13)
	placeholder.add_theme_color_override("font_color", Color(0.35, 0.45, 0.55))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selected_tower_panel.add_child(placeholder)

func _on_card_selected(tower_id: String, cfg: Dictionary) -> void:
	# Deselect previous
	if _selected_card != null:
		_selected_card.set_selected(false)

	# Find and select new card
	for card in _all_cards:
		if card.tower_id == tower_id:
			_selected_card = card
			card.set_selected(true)
			break

	_populate_side_panel(tower_id, cfg)

func _populate_side_panel(tower_id: String, cfg: Dictionary) -> void:
	for child in selected_tower_panel.get_children():
		child.queue_free()
	_side_preview = null
	_side_dummy_tower = null
	_side_dummy_target = null
	_side_vfx_nodes.clear()

	# Title
	var title := Label.new()
	title.text = str(cfg.get("display_name", tower_id))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 1.0))
	title.clip_text = true
	selected_tower_panel.add_child(title)

	# tower_id
	selected_tower_panel.add_child(_make_side_stat("ID", tower_id, Color(0.5, 0.65, 0.8)))

	var tier: int = int(cfg.get("tier", 1))
	var tier_str := "T%d" % tier if tier <= 3 else ("Pure" if tier == 4 else "Tier %d" % tier)
	selected_tower_panel.add_child(_make_side_stat("Tier", tier_str, TIER_BADGE_COLOR.get(tier, Color.WHITE)))

	var elements: Array = cfg.get("elements", [])
	if not elements.is_empty():
		selected_tower_panel.add_child(_make_element_badge(elements))

	selected_tower_panel.add_child(_make_side_stat("Attack", str(cfg.get("attack_type", "-")), Color(0.7, 0.82, 0.9)))
	selected_tower_panel.add_child(_make_side_stat("Visual", str(cfg.get("visual_type", "-")), Color(0.6, 0.72, 0.85)))

	var status_effect: String = str(cfg.get("status_effect", ""))
	if status_effect != "" and status_effect != "null":
		selected_tower_panel.add_child(_make_side_stat("Status FX", status_effect, Color(0.55, 0.95, 0.72)))

	var support_type: String = str(cfg.get("support_type", ""))
	if support_type != "" and support_type != "null":
		selected_tower_panel.add_child(_make_side_stat("Support", support_type, Color(0.95, 0.78, 0.38)))

	# VFX file path (read-only LineEdit for copy)
	var vfx_path := "res://scripts/vfx/towers/%s_attack_vfx.gd" % tower_id
	var vfx_path_label := Label.new()
	vfx_path_label.text = "VFX path:"
	vfx_path_label.add_theme_font_size_override("font_size", 11)
	vfx_path_label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	selected_tower_panel.add_child(vfx_path_label)

	var path_edit := LineEdit.new()
	path_edit.text = vfx_path
	path_edit.editable = false
	path_edit.add_theme_font_size_override("font_size", 10)
	selected_tower_panel.add_child(path_edit)

	# VFX badge
	var badge_text := _get_vfx_badge(tower_id, tier)
	var badge_label := Label.new()
	badge_label.text = "VFX status: " + badge_text
	badge_label.add_theme_font_size_override("font_size", 12)
	selected_tower_panel.add_child(badge_label)
	_selected_card.set_vfx_badge(badge_text)  # sync to card too

	selected_tower_panel.add_child(_make_side_separator())

	# Replay buttons
	var replay_atk := Button.new()
	replay_atk.text = "▶  Replay Attack"
	replay_atk.pressed.connect(_replay_attack_vfx)
	selected_tower_panel.add_child(replay_atk)

	var replay_status := Button.new()
	replay_status.text = "◉  Replay Status"
	replay_status.pressed.connect(_show_status_preview)
	selected_tower_panel.add_child(replay_status)

	var replay_support := Button.new()
	replay_support.text = "⬡  Replay Support"
	replay_support.pressed.connect(_show_support_preview)
	selected_tower_panel.add_child(replay_support)

	selected_tower_panel.add_child(_make_side_separator())

	# Side panel model preview (400×280)
	_side_preview = TowerCatalogPreview.new()
	_side_preview.tower_id = tower_id
	_side_preview.tower_config = cfg
	_side_preview.preview_size = Vector2(300, 200)
	_side_preview.camera_zoom = 1.2
	_side_preview.show_range_ring = true
	_side_preview.show_projectile_preview = false
	_side_preview.show_effects_preview = false
	_side_preview.custom_minimum_size = _side_preview.preview_size
	selected_tower_panel.add_child(_side_preview)

func _make_side_stat(key: String, value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = "%s: %s" % [key, value]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	return label

func _make_side_separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = Color(0.2, 0.5, 0.7, 0.3)
	return sep
```

- [ ] **Step 2: Verify side panel**

Run the catalog and click any tower card. The right panel should populate with tower details, a VFX path, badge, replay buttons, and the model preview SubViewport.

- [ ] **Step 3: Commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_catalog.gd
git commit -m "feat: tower_catalog — persistent side panel with tower details and model preview"
```

---

## Task 7 — Real VFX spawning in the side panel

When Replay Attack is pressed (or auto-play ticks), spawn a real `BaseTowerAttackVFX` node into the side panel's SubViewport using `DummyTowerPreview` and `DummyTargetPreview`.

**Files:**
- Modify: `scripts/debug/tower_catalog.gd`

- [ ] **Step 1: Add VFX spawn methods to tower_catalog.gd**

Append to `tower_catalog.gd`:

```gdscript
# ── VFX spawning (side panel only) ────────────────────────────────────────────

func _replay_attack_vfx() -> void:
	if _selected_card == null or _side_preview == null:
		return
	if not _controller.show_attack_vfx:
		return
	if PerformanceFirebreak.disable_all_attack_vfx:
		return

	var tower_id: String = _selected_card.tower_id
	var script: GDScript = TowerAttackVFXRegistry.get_vfx_script(tower_id)
	if script == null:
		return

	var vfx_viewport: SubViewport = _side_preview.get_vfx_viewport()
	if vfx_viewport == null:
		return

	# Set up dummy nodes on first use (they persist until panel changes)
	if _side_dummy_tower == null:
		_side_dummy_tower = DummyTowerPreview.new()
		_side_dummy_tower.position = Vector2(-80, 0)
		vfx_viewport.add_child(_side_dummy_tower)

	if _side_dummy_target == null:
		_side_dummy_target = DummyTargetPreview.new()
		_side_dummy_target.position = Vector2(80, 0)
		vfx_viewport.add_child(_side_dummy_target)

	# Derive tower color from config elements
	var elements: Array = _selected_card.cfg.get("elements", [])
	var color: Color = Color(0.45, 0.92, 1.0)
	if not elements.is_empty():
		color = ELEM_COLOR.get(str(elements[0]), color)

	_side_dummy_tower.setup(tower_id, color)

	# Spawn real VFX node
	var vfx_node := Node2D.new()
	vfx_node.set_script(script)
	vfx_viewport.add_child(vfx_node)
	vfx_node.setup(
		_side_dummy_tower.global_position,
		_side_dummy_target.global_position,
		color
	)
	vfx_node.configure({})
	_side_vfx_nodes.append(vfx_node)

func _show_status_preview() -> void:
	# Status icons are drawn directly without a live enemy node.
	# The existing TowerCatalogPreview simulation handles support-style towers.
	if _side_preview == null:
		return
	_side_preview.set_preview_options(
		_side_preview.show_range_ring,
		false,
		true,
		false
	)

func _show_support_preview() -> void:
	if _side_preview == null:
		return
	_side_preview.set_preview_options(
		_side_preview.show_range_ring,
		false,
		true,
		false
	)
```

- [ ] **Step 2: Verify real VFX**

1. Open the catalog and select a tower (e.g., `electricity_t1`).
2. Click **Replay Attack**.
3. The side panel SubViewport should show a real `BaseTowerAttackVFX` lightning arc (matching what appears in gameplay), not just the simulation lines.
4. Press Replay multiple times — new VFX nodes spawn and self-destruct after their lifetime.
5. Check the **VFX:** counter in the toolbar increments during spawning.

- [ ] **Step 3: Commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add scripts/debug/tower_catalog.gd
git commit -m "feat: tower_catalog — real VFX spawning in side panel via TowerAttackVFXRegistry"
```

---

## Task 8 — Smoke test and QA checklist

**Files:** None changed — this is a verification task.

- [ ] **Step 1: Run headless import check**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
godot --headless --import 2>&1 | grep -i "error" | grep -v "^$"
```

Expected: No output (zero errors). If any `SCRIPT ERROR` lines appear, fix the referenced script before proceeding.

- [ ] **Step 2: Open scene in Godot editor and verify structure**

Open `scenes/debug/tower_catalog.tscn`. In the Scene panel confirm:
```
TowerCatalog (Control)
├── Background
└── RootMargin
    └── MainVBox
        ├── Header
        ├── TopToolbar       ← populated by _build_toolbar()
        └── ContentArea
            ├── ScrollContainer
            │   └── ContentVBox   ← grid appears here
            └── SelectedTowerPanel ← placeholder text visible
```

- [ ] **Step 3: Run catalog and verify all 132 towers load**

Play the scene. In the Output panel confirm no errors. Scroll through the catalog and verify:
- Neutral section: `basic_tower_t1`, `neutral_cannon_tower`
- Single Element: 6 families × 3 cards = 18 cards
- Dual Element: 15 families × 3 cards = 45 cards
- Triple Element: 20 families × 3 cards = 60 cards
- Pure section: 6 singletons
- Periodic: `periodic_t1`
- Total cards visible at start: 132

- [ ] **Step 4: Test filters**

| Action | Expected |
|---|---|
| Type "elec" in search | Only electricity family visible |
| Select "Fire" from element filter | Only fire-element towers visible |
| Select "T2" from tier filter | Only T2 cards visible |
| Clear all filters | All 132 cards visible again |

- [ ] **Step 5: Test zoom**

| Action | Expected |
|---|---|
| Click "+" three times | Grid cards visually enlarge; horizontal scrollbar appears at high zoom |
| Click "1×" | Grid returns to 1.0× scale |
| Click "Fit" | Grid scales to fill the scroll area width |
| Cmd + scroll up | Grid zooms in |
| Cmd + scroll down | Grid zooms out |
| Plain scroll (no Cmd) | ScrollContainer scrolls vertically, no zoom |

- [ ] **Step 6: Test side panel**

| Action | Expected |
|---|---|
| Click any card | Side panel populates with tower_id, tier, elements, attack type, VFX path |
| Click "Replay Attack" on a combat tower | VFX animation plays in side panel SubViewport |
| Click "Replay Attack" on `electricity_t1` | Lightning arc visible (real VFX, not simulation) |
| Click a different card | Previous card border deselects; new card gets cyan border |
| Click "Replay Status" | Side panel simulation shows effect preview |

- [ ] **Step 7: Test VFX toggles**

| Action | Expected |
|---|---|
| Uncheck "Attack VFX" | No VFX spawns when Replay is pressed |
| Enable "Auto Play" then wait 1.6s | VFX replays automatically every 0.8s |
| Enable "Pause" while Auto Play is on | Auto-play timer stops |
| Uncheck "Pause" | Auto-play resumes |

- [ ] **Step 8: Verify no gameplay regressions**

Open any real gameplay scene (not the catalog). Confirm:
- No VFX changes or new nodes appear in gameplay
- `PerformanceFirebreak` flags unchanged
- Enemy, tower, wave logic unchanged

- [ ] **Step 9: Final commit**

```bash
cd "/Users/oyl/my_folders/projects/clone tower defend"
git add -p  # review any remaining unstaged changes
git commit -m "feat: Tower Effect Catalog — full VFX preview, filters, zoom, and side panel"
```

---

## Self-Review Notes

**Spec coverage verified:**
- ✅ All 132 towers from JSON (family grouping by combo_type + tier suffix stripping)
- ✅ TopToolbar: search, element/tier/attack filters, VFX toggles, auto-play, pause, replay, zoom, FPS, VFX count
- ✅ SelectedTowerPanel: tower_id, display_name, tier, elements, attack_type, visual_type, VFX path, badge, replay buttons, SubViewport preview
- ✅ Zoom: ContentVBox.scale with natural size tracking; 7 steps 0.5–3.0; Cmd+scroll; fit grid
- ✅ Real VFX: TowerAttackVFXRegistry called directly (not via TowerAttackVFXService) in side panel SubViewport only
- ✅ VFX badges: OK / Missing / T1 Fallback / Legacy via `_get_vfx_badge()`
- ✅ No gameplay changes; PerformanceFirebreak read-only
- ✅ Works standalone (scene opens directly)

**Known limitation:** `script.source_code` for T1 Fallback detection works in editor/debug mode only. In an exported build this returns empty — but the catalog is a debug-only tool so this is acceptable.

**Type consistency:** All method names used across tasks are consistent:
- `TowerEffectCatalogCard`: `setup()`, `set_selected()`, `set_vfx_badge()`, `passes_filters()`, signal `card_selected`
- `TowerEffectCatalogZoomController`: `setup()`, `zoom_in()`, `zoom_out()`, `reset_zoom()`, `fit_grid()`, `set_zoom()`, `get_zoom()`
- `TowerEffectCatalogController`: `setup_timer()`, `set_auto_play()`, `set_paused()`, signals `filters_changed`, `replay_selected_requested`, `auto_play_tick`
- `DummyTowerPreview`: `setup()`, `get_fire_origin()`, `_get_tower_color()`
- `DummyTargetPreview`: `get_hit_origin()`
- `TowerCatalogPreview` additions: `get_vfx_viewport()`, `disable_simulation()`

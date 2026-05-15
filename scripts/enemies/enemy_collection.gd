extends Node2D

const ENEMY_SCRIPT := preload("res://scripts/enemies/enemy.gd")
# แก้ path นี้ให้ตรงกับไฟล์จริงของคุณ

const ENEMY_DEFS := [
	{"id": "basic", "name": "Basic", "visual_type": "basic", "hp": 30, "speed": 0, "reward_gold": 5, "base_damage": 1, "tags": []},
	{"id": "fast", "name": "Fast", "visual_type": "fast", "hp": 24, "speed": 0, "reward_gold": 6, "base_damage": 1, "tags": []},
	{"id": "tank", "name": "Tank", "visual_type": "tank", "hp": 80, "speed": 0, "reward_gold": 10, "base_damage": 2, "tags": []},
	{"id": "bulwark", "name": "Bulwark", "visual_type": "bulwark", "hp": 100, "speed": 0, "reward_gold": 12, "base_damage": 2, "tags": ["shield"]},
	{"id": "hunter", "name": "Hunter", "visual_type": "hunter", "hp": 55, "speed": 0, "reward_gold": 9, "base_damage": 2, "tags": ["anti_hero"]},
	{"id": "swarm", "name": "Swarm", "visual_type": "swarm", "hp": 16, "speed": 0, "reward_gold": 3, "base_damage": 1, "tags": ["swarm"]},
	{"id": "runner", "name": "Runner", "visual_type": "runner", "hp": 28, "speed": 0, "reward_gold": 6, "base_damage": 1, "tags": []},
	{"id": "shieldbearer", "name": "Shieldbearer", "visual_type": "shieldbearer", "hp": 60, "speed": 0, "reward_gold": 8, "base_damage": 1, "tags": ["shield"]},
	{"id": "healer", "name": "Healer", "visual_type": "healer", "hp": 40, "speed": 0, "reward_gold": 8, "base_damage": 1, "tags": []},
	{"id": "splitter", "name": "Splitter", "visual_type": "splitter", "hp": 45, "speed": 0, "reward_gold": 8, "base_damage": 1, "tags": []},
	{"id": "cloaked", "name": "Cloaked", "visual_type": "cloaked", "hp": 32, "speed": 0, "reward_gold": 8, "base_damage": 1, "tags": ["stealth"], "skill": "stealth"},
	{"id": "flyer", "name": "Flyer", "visual_type": "flyer", "hp": 30, "speed": 0, "reward_gold": 7, "base_damage": 1, "category": "air", "tags": []},
	{"id": "fast_flyer", "name": "Fast Flyer", "visual_type": "fast_flyer", "hp": 24, "speed": 0, "reward_gold": 8, "base_damage": 1, "category": "air", "tags": []},
	{"id": "armored_flyer", "name": "Armored Flyer", "visual_type": "armored_flyer", "hp": 70, "speed": 0, "reward_gold": 12, "base_damage": 2, "category": "air", "tags": []},
	{"id": "disruptor", "name": "Disruptor", "visual_type": "disruptor", "hp": 50, "speed": 0, "reward_gold": 10, "base_damage": 1, "tags": []}
]

var _pending_setup: Array = []

var _detail_layer: CanvasLayer
var _detail_overlay: Control
var _detail_title: Label
var _detail_stats: Label
var _detail_preview_root: Node2D
var _detail_enemy: PathFollow2D
var _detail_path: Path2D
var _selected_enemy_index: int = -1
var _detail_zoom: float = 3.0

func _ready() -> void:
	
	_spawn_gallery()
	_build_detail_viewer()

	await get_tree().process_frame

	for item in _pending_setup:
		var enemy = item.enemy
		var config = item.config
		
		enemy.is_gallery_preview = true
		
		enemy.setup(config)
		enemy.progress_ratio = 0.5

		# ใส่ sample status บางตัว เพื่อให้เห็น effect เพิ่มขึ้น
		match config.id:
			"shieldbearer", "bulwark":
				enemy.apply_shield(9999.0, 0.30)
			"cloaked":
				# setup() ทำ opacity ให้แล้ว
				pass
			"fast":
				enemy.apply_slow(0.20, 9999.0)

func _spawn_gallery() -> void:
	var cols := 4
	var card_w := 240.0
	var card_h := 180.0
	var start_x := 120.0
	var start_y := 100.0

	for i in range(ENEMY_DEFS.size()):
		var data = ENEMY_DEFS[i]
		
		

		var row := i / cols
		var col := i % cols
		var cell_pos := Vector2(start_x + col * card_w, start_y + row * card_h)

		var cell := Node2D.new()
		cell.position = cell_pos
		add_child(cell)

		# พื้นหลัง card
		var bg := ColorRect.new()
		bg.position = Vector2(-80, -55)
		bg.size = Vector2(160, 110)
		bg.color = Color(0.07, 0.09, 0.13, 0.85)
		cell.add_child(bg)
		
		var click_button := Button.new()
		click_button.position = Vector2(-80, -55)
		click_button.size = Vector2(160, 110)
		click_button.text = ""
		click_button.flat = true
		click_button.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var empty_style := StyleBoxEmpty.new()
		click_button.add_theme_stylebox_override("normal", empty_style)
		click_button.add_theme_stylebox_override("pressed", empty_style)
		click_button.add_theme_stylebox_override("focus", empty_style)
		
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.2, 0.8, 1.0, 0.08)
		hover_style.border_color = Color(0.2, 0.8, 1.0, 0.45)
		hover_style.set_border_width_all(1)
		click_button.add_theme_stylebox_override("hover", hover_style)

		var enemy_index := i
		click_button.pressed.connect(func() -> void:
			_show_detail_index(enemy_index)
		)
		cell.add_child(click_button)

		# path holder (เพราะ enemy.gd extends PathFollow2D)
		var path := Path2D.new()
		cell.add_child(path)

		var curve := Curve2D.new()
		curve.add_point(Vector2(-10, 0))
		curve.add_point(Vector2(10, 0))
		path.curve = curve

		# enemy instance
		var enemy := PathFollow2D.new()
		enemy.name = "Enemy"

		enemy.set_script(ENEMY_SCRIPT)
		enemy.is_gallery_preview = true

		path.add_child(enemy)

		# label ชื่อ
		var label := Label.new()
		label.text = data.name + " (" + data.visual_type + ")"
		label.position = Vector2(-72, 62)
		label.size = Vector2(144, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)

		_pending_setup.append({
			"enemy": enemy,
			"config": data
		})
		
func _build_detail_viewer() -> void:
	_detail_layer = CanvasLayer.new()
	_detail_layer.layer = 100
	add_child(_detail_layer)

	_detail_overlay = Control.new()
	_detail_overlay.visible = false
	_detail_overlay.anchor_right = 1.0
	_detail_overlay.anchor_bottom = 1.0
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_layer.add_child(_detail_overlay)

	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_detail_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.size = Vector2(680, 560)
	panel.position = (get_viewport_rect().size - panel.size) * 0.5
	_detail_overlay.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.10, 0.96)
	panel_style.border_color = Color(0.15, 0.8, 1.0, 0.75)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	_detail_title = Label.new()
	_detail_title.text = "Enemy Detail"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_detail_title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_enemy_detail)
	header.add_child(close_btn)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	root.add_child(content)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(390, 390)
	content.add_child(preview_panel)

	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.02, 0.03, 0.06, 0.95)
	preview_style.border_color = Color(0.1, 0.55, 0.9, 0.7)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(12)
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = false
	viewport_container.custom_minimum_size = Vector2(380, 380)
	preview_panel.add_child(viewport_container)

	var sub_viewport := SubViewport.new()
	sub_viewport.size = Vector2i(380, 380)
	sub_viewport.transparent_bg = true
	sub_viewport.disable_3d = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(sub_viewport)

	_detail_preview_root = Node2D.new()
	_detail_preview_root.position = Vector2(190, 190)
	sub_viewport.add_child(_detail_preview_root)

	var info_box := VBoxContainer.new()
	info_box.custom_minimum_size = Vector2(230, 390)
	info_box.add_theme_constant_override("separation", 10)
	content.add_child(info_box)

	_detail_stats = Label.new()
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_stats.add_theme_font_size_override("font_size", 16)
	info_box.add_child(_detail_stats)

	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	info_box.add_child(zoom_label)

	var zoom_row := HBoxContainer.new()
	info_box.add_child(zoom_row)

	var zoom_minus := Button.new()
	zoom_minus.text = "-"
	zoom_minus.pressed.connect(func() -> void:
		_set_detail_zoom(_detail_zoom - 0.5)
	)
	zoom_row.add_child(zoom_minus)

	var zoom_plus := Button.new()
	zoom_plus.text = "+"
	zoom_plus.pressed.connect(func() -> void:
		_set_detail_zoom(_detail_zoom + 0.5)
	)
	zoom_row.add_child(zoom_plus)

	var nav_row := HBoxContainer.new()
	info_box.add_child(nav_row)

	var prev_btn := Button.new()
	prev_btn.text = "Prev"
	prev_btn.pressed.connect(_show_prev_enemy)
	nav_row.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Next"
	next_btn.pressed.connect(_show_next_enemy)
	nav_row.add_child(next_btn)


func _show_detail_index(index: int) -> void:
	if index < 0 or index >= ENEMY_DEFS.size():
		return

	_selected_enemy_index = index
	_detail_zoom = 3.0

	var config: Dictionary = ENEMY_DEFS[index]
	_update_detail_text(config)
	_spawn_detail_enemy(config)

	_detail_overlay.visible = true


func _update_detail_text(config: Dictionary) -> void:
	var name := str(config.get("name", "Enemy"))
	var id := str(config.get("id", "unknown"))
	var visual_type := str(config.get("visual_type", id))
	var hp := str(config.get("hp", "-"))
	var speed := str(config.get("speed", "-"))
	var reward := str(config.get("reward_gold", "-"))
	var damage := str(config.get("base_damage", "-"))
	var category := str(config.get("category", "land"))
	var tags: Array = config.get("tags", [])

	_detail_title.text = "%s (%s)" % [name, id]

	var role := _get_enemy_role_text(id)

	_detail_stats.text = ""
	_detail_stats.text += "Type: %s\n" % visual_type
	_detail_stats.text += "Category: %s\n" % category
	_detail_stats.text += "Role: %s\n\n" % role
	_detail_stats.text += "HP: %s\n" % hp
	_detail_stats.text += "Speed: %s\n" % speed
	_detail_stats.text += "Reward: %s gold\n" % reward
	_detail_stats.text += "Base Damage: %s\n" % damage
	_detail_stats.text += "Tags: %s\n\n" % ", ".join(tags)

	_detail_stats.text += _get_enemy_ability_text(id)


func _get_enemy_role_text(id: String) -> String:
	match id:
		"basic":
			return "Standard balanced unit"
		"fast":
			return "Constant-speed pressure unit"
		"runner":
			return "Dash escape / panic burst unit"
		"tank":
			return "High HP frontline unit"
		"bulwark":
			return "Shield aura protector"
		"shieldbearer":
			return "Shield support unit"
		"hunter":
			return "Aggressive anti-hero unit"
		"swarm":
			return "Small fast swarm unit"
		"healer":
			return "Healing support unit"
		"splitter":
			return "Splits after death"
		"cloaked":
			return "Stealth / targeting disruption"
		"flyer", "fast_flyer", "armored_flyer":
			return "Air unit"
		"disruptor":
			return "Tower disruption aura"
		_:
			return "Special enemy"


func _get_enemy_ability_text(id: String) -> String:
	match id:
		"bulwark":
			return "Ability:\nProjects a large shield field around itself."
		"shieldbearer":
			return "Ability:\nProtects nearby enemies with shield reduction."
		"healer":
			return "Ability:\nHeals nearby allies over time."
		"cloaked":
			return "Ability:\nHarder to target while other enemies are nearby."
		"disruptor":
			return "Ability:\nDisrupts nearby towers and reduces their effectiveness."
		"splitter":
			return "Ability:\nSplits into smaller units when destroyed."
		"hunter":
			return "Ability:\nCan threaten hero units or priority targets."
		"swarm":
			return "Ability:\nMoves as a fast, flickering cyber swarm."
		"runner":
			return "Ability:\nMedium baseline speed, short dash bursts, reduced dash damage, and panic sprint under 40% HP."
		"fast":
			return "Ability:\nAlways fast and fragile. Tests the player's fire-rate coverage."
		_:
			return "Ability:\nNo special ability preview data."


func _spawn_detail_enemy(config: Dictionary) -> void:
	_clear_detail_enemy()

	_detail_path = Path2D.new()

	var curve := Curve2D.new()
	curve.add_point(Vector2(-8, 0))
	curve.add_point(Vector2(8, 0))
	_detail_path.curve = curve

	_detail_preview_root.add_child(_detail_path)

	_detail_enemy = PathFollow2D.new()
	_detail_enemy.name = "DetailEnemy"

	_detail_enemy.set_script(ENEMY_SCRIPT)
	_detail_enemy.is_gallery_preview = true

	_detail_path.add_child(_detail_enemy)

	_detail_enemy.setup(config)
	_detail_enemy.progress_ratio = 0.5
	_detail_enemy.scale = Vector2.ONE * _detail_zoom
	_detail_enemy.set_process(true)
	_detail_enemy.set_physics_process(false)

	match str(config.get("id", "")):
		"shieldbearer", "bulwark":
			_detail_enemy.apply_shield(9999.0, 0.30)
		"fast":
			_detail_enemy.apply_slow(0.20, 9999.0)
		"cloaked":
			_detail_enemy.modulate.a = 0.45


func _clear_detail_enemy() -> void:
	if _detail_path and is_instance_valid(_detail_path):
		_detail_path.queue_free()

	_detail_path = null
	_detail_enemy = null


func _set_detail_zoom(value: float) -> void:
	_detail_zoom = clampf(value, 1.5, 6.0)

	if _detail_enemy and is_instance_valid(_detail_enemy):
		_detail_enemy.scale = Vector2.ONE * _detail_zoom


func _show_prev_enemy() -> void:
	if ENEMY_DEFS.is_empty():
		return

	var next_index := _selected_enemy_index - 1
	if next_index < 0:
		next_index = ENEMY_DEFS.size() - 1

	_show_detail_index(next_index)


func _show_next_enemy() -> void:
	if ENEMY_DEFS.is_empty():
		return

	var next_index := _selected_enemy_index + 1
	if next_index >= ENEMY_DEFS.size():
		next_index = 0

	_show_detail_index(next_index)


func _close_enemy_detail() -> void:
	if _detail_overlay:
		_detail_overlay.visible = false

	_clear_detail_enemy()


func _unhandled_input(event: InputEvent) -> void:
	if _detail_overlay and _detail_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_enemy_detail()
			get_viewport().set_input_as_handled()

extends Node2D

const EFFECT_DEFS := [
	{
		"id": "spawn_portal",
		"name": "Spawn Portal",
		"script": "res://scripts/effects/spawn_effect.gd",
		"category": "spawn",
		"desc": "Enemy spawn portal / materialization effect.",
		"setup": "spawn_portal"
	},
	{
		"id": "spawn_swarm",
		"name": "Swarm Materialize",
		"script": "res://scripts/effects/spawn_effect.gd",
		"category": "spawn",
		"desc": "Swarm cyber materialization effect.",
		"setup": "spawn_swarm"
	},
	{
		"id": "impact_basic",
		"name": "Basic Impact",
		"script": "res://scripts/effects/impact_effect.gd",
		"category": "impact",
		"desc": "Generic tower bullet impact.",
		"setup": "impact_basic"
	},
	{
		"id": "enemy_heal_received",
		"name": "Heal Received",
		"script": "res://scripts/effects/enemy_impact_vfx.gd",
		"category": "enemy",
		"desc": "Holy / tech healing particles landing on target.",
		"setup": "enemy_heal_received"
	},
	{
		"id": "enemy_shield_spark",
		"name": "Shield Spark",
		"script": "res://scripts/effects/enemy_impact_vfx.gd",
		"category": "enemy",
		"desc": "Shield block impact spark.",
		"setup": "enemy_shield_spark"
	},
	{
		"id": "enemy_split_burst",
		"name": "Split Burst",
		"script": "res://scripts/effects/enemy_impact_vfx.gd",
		"category": "enemy",
		"desc": "Splitter enemy burst effect.",
		"setup": "enemy_split_burst"
	},
	{
		"id": "aura_healer",
		"name": "Healer Aura",
		"script": "res://scripts/effects/enemy_aura_vfx.gd",
		"category": "aura",
		"desc": "Healing support radius preview.",
		"setup": "aura_healer"
	},
	{
		"id": "aura_shield",
		"name": "Shield Aura",
		"script": "res://scripts/effects/enemy_aura_vfx.gd",
		"category": "aura",
		"desc": "Bulwark / shieldbearer protection aura.",
		"setup": "aura_shield"
	},
	{
		"id": "aura_disrupt",
		"name": "Disruptor Aura",
		"script": "res://scripts/effects/enemy_aura_vfx.gd",
		"category": "aura",
		"desc": "EMP disruption radius preview.",
		"setup": "aura_disrupt"
	},
	{
		"id": "beam_heal_cast",
		"name": "Heal Cast Beam",
		"script": "res://scripts/effects/enemy_beam_vfx.gd",
		"category": "beam",
		"desc": "Healer cast beam / holy light.",
		"setup": "beam_heal_cast"
	},
	{
		"id": "status_shield",
		"name": "Shield Status Icon",
		"script": "res://scripts/effects/enemy_status_icon_vfx.gd",
		"category": "status",
		"desc": "Floating shield status icon.",
		"setup": "status_shield"
	},
	{
		"id": "status_cloak",
		"name": "Cloak Status Icon",
		"script": "res://scripts/effects/enemy_status_icon_vfx.gd",
		"category": "status",
		"desc": "Floating cloak / stealth status icon.",
		"setup": "status_cloak"
	},
	{
		"id": "death_pop",
		"name": "Death Pop",
		"script": "res://scripts/effects/death_pop_effect.gd",
		"category": "death",
		"desc": "Enemy death pop effect.",
		"setup": "death_pop"
	},
	{
		"id": "swarm_death",
		"name": "Swarm Death",
		"script": "res://scripts/effects/death_pop_effect.gd",
		"category": "death",
		"desc": "Swarm disintegration / cyber particles.",
		"setup": "swarm_death"
	},
	{
		"id": "splash",
		"name": "Splash",
		"script": "res://scripts/effects/splash_effect.gd",
		"category": "tower",
		"desc": "Cannon splash damage radius.",
		"setup": "splash"
	},
	{
		"id": "muzzle_flash",
		"name": "Muzzle Flash",
		"script": "res://scripts/effects/muzzle_flash.gd",
		"category": "tower",
		"desc": "Tower muzzle flash effect.",
		"setup": "muzzle_flash"
	},
	{
		"id": "lightning_arc",
		"name": "Lightning Arc",
		"script": "res://scripts/effects/lightning_arc.gd",
		"category": "tower",
		"desc": "Chain lightning arc preview.",
		"setup": "lightning_arc"
	},
	{
		"id": "sawblade_aoe",
		"name": "Sawblade AoE",
		"script": "res://scripts/effects/sawblade_aoe_effect.gd",
		"category": "tower",
		"desc": "Rotating sawblade area attack.",
		"setup": "sawblade_aoe"
	},
	{
		"id": "damage_number",
		"name": "Damage Number",
		"script": "res://scripts/effects/damage_number.gd",
		"category": "ui",
		"desc": "Floating damage number.",
		"setup": "damage_number"
	}
]

var _cards_root: Node2D
var _detail_layer: CanvasLayer
var _detail_overlay: Control
var _detail_title: Label
var _detail_desc: Label
var _detail_preview_root: Node2D
var _detail_effect: Node2D
var _selected_index: int = -1
var _detail_zoom: float = 1.0
var _replay_timer: Timer


func _ready() -> void:
	_build_background()
	_spawn_gallery()
	_build_detail_viewer()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.size = get_viewport_rect().size
	bg.color = Color(0.28, 0.29, 0.29, 1.0)
	add_child(bg)


func _spawn_gallery() -> void:
	_cards_root = Node2D.new()
	_cards_root.name = "EffectCards"
	add_child(_cards_root)

	var columns := 4
	var cell_w := 240.0
	var cell_h := 160.0
	var start := Vector2(120, 90)

	for i in EFFECT_DEFS.size():
		var def: Dictionary = EFFECT_DEFS[i]
		var col := i % columns
		var row := i / columns

		var card := Control.new()
		card.position = start + Vector2(col * cell_w, row * cell_h)
		card.size = Vector2(200, 130)
		_cards_root.add_child(card)

		var bg := ColorRect.new()
		bg.position = Vector2(-100, -60)
		bg.size = Vector2(200, 120)
		bg.color = Color(0.07, 0.09, 0.13, 0.9)
		card.add_child(bg)

		var preview_root := Node2D.new()
		preview_root.position = Vector2(0, -10)
		card.add_child(preview_root)

		_spawn_gallery_card_effect(preview_root, def, 0.72)

		var label := Label.new()
		label.position = Vector2(-95, 48)
		label.size = Vector2(190, 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = "%s\n(%s)" % [str(def.get("name", "")), str(def.get("category", ""))]
		label.add_theme_font_size_override("font_size", 13)
		card.add_child(label)

		var click_button := Button.new()
		click_button.position = Vector2(-100, -60)
		click_button.size = Vector2(200, 120)
		click_button.text = ""
		click_button.flat = true
		click_button.mouse_filter = Control.MOUSE_FILTER_STOP

		var empty := StyleBoxEmpty.new()
		click_button.add_theme_stylebox_override("normal", empty)
		click_button.add_theme_stylebox_override("pressed", empty)
		click_button.add_theme_stylebox_override("focus", empty)

		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.2, 0.8, 1.0, 0.08)
		hover.border_color = Color(0.2, 0.8, 1.0, 0.55)
		hover.set_border_width_all(1)
		click_button.add_theme_stylebox_override("hover", hover)

		var index := i
		click_button.pressed.connect(func() -> void:
			_show_detail_index(index)
		)
		card.add_child(click_button)


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
	panel.size = Vector2(760, 560)
	panel.position = (get_viewport_rect().size - panel.size) * 0.5
	_detail_overlay.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.97)
	style.border_color = Color(0.15, 0.8, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	_detail_title = Label.new()
	_detail_title.text = "Effect Detail"
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.add_theme_font_size_override("font_size", 24)
	header.add_child(_detail_title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_detail)
	header.add_child(close_btn)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	root.add_child(content)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(440, 420)
	content.add_child(preview_panel)

	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.02, 0.03, 0.06, 0.95)
	preview_style.border_color = Color(0.1, 0.55, 0.9, 0.7)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(12)
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	var sub_container := SubViewportContainer.new()
	sub_container.custom_minimum_size = Vector2(430, 410)
	preview_panel.add_child(sub_container)

	var sub := SubViewport.new()
	sub.size = Vector2i(430, 410)
	sub.transparent_bg = true
	sub.disable_3d = true
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_container.add_child(sub)

	_detail_preview_root = Node2D.new()
	_detail_preview_root.position = Vector2(215, 205)
	sub.add_child(_detail_preview_root)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(250, 420)
	info.add_theme_constant_override("separation", 10)
	content.add_child(info)

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 16)
	info.add_child(_detail_desc)

	var zoom_row := HBoxContainer.new()
	info.add_child(zoom_row)

	var zoom_minus := Button.new()
	zoom_minus.text = "Zoom -"
	zoom_minus.pressed.connect(func() -> void:
		_set_detail_zoom(_detail_zoom - 0.25)
	)
	zoom_row.add_child(zoom_minus)

	var zoom_plus := Button.new()
	zoom_plus.text = "Zoom +"
	zoom_plus.pressed.connect(func() -> void:
		_set_detail_zoom(_detail_zoom + 0.25)
	)
	zoom_row.add_child(zoom_plus)

	var replay_btn := Button.new()
	replay_btn.text = "Replay"
	replay_btn.pressed.connect(_replay_detail_effect)
	info.add_child(replay_btn)

	var nav_row := HBoxContainer.new()
	info.add_child(nav_row)

	var prev_btn := Button.new()
	prev_btn.text = "Prev"
	prev_btn.pressed.connect(_show_prev)
	nav_row.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Next"
	next_btn.pressed.connect(_show_next)
	nav_row.add_child(next_btn)

	_replay_timer = Timer.new()
	_replay_timer.wait_time = 0.9
	_replay_timer.one_shot = false
	_replay_timer.timeout.connect(_replay_detail_effect)
	add_child(_replay_timer)


func _show_detail_index(index: int) -> void:
	if index < 0 or index >= EFFECT_DEFS.size():
		return

	_selected_index = index
	_detail_zoom = 1.0

	var def: Dictionary = EFFECT_DEFS[index]
	_detail_title.text = "%s (%s)" % [str(def.get("name", "")), str(def.get("id", ""))]
	_detail_desc.text = "Category: %s\n\n%s\n\nScript:\n%s" % [
		str(def.get("category", "")),
		str(def.get("desc", "")),
		str(def.get("script", ""))
	]

	_detail_overlay.visible = true
	_replay_detail_effect()

	if _replay_timer:
		if _effect_is_one_shot(def):
			_replay_timer.wait_time = _get_effect_replay_interval(def)
			_replay_timer.start()
		else:
			_replay_timer.stop()


func _spawn_effect_preview(parent: Node2D, def: Dictionary, scale_factor: float = 1.0) -> Node2D:
	var script_path := str(def.get("script", ""))
	var script_res := load(script_path)

	if script_res == null:
		push_warning("[EffectGallery] Missing effect script: %s" % script_path)
		return null

	var node := Node2D.new()
	node.set_script(script_res)
	node.scale = Vector2.ONE * scale_factor
	parent.add_child(node)

	_apply_effect_setup(node, def)

	return node


func _apply_effect_setup(node: Node, def: Dictionary) -> void:
	var setup_key := str(def.get("setup", ""))

	match setup_key:
		"spawn_portal":
			if node.has_method("setup"):
				node.setup(Color(0.25, 0.85, 1.0, 0.85), 36.0, "portal")

		"spawn_swarm":
			if node.has_method("setup"):
				node.setup(Color(0.0, 0.9, 1.0, 0.85), 34.0, "swarm")

		"impact_basic":
			if node.has_method("setup"):
				node.setup(Color(0.35, 0.9, 1.0, 1.0), 1.6)

		"enemy_heal_received":
			if node.has_method("setup"):
				node.setup("heal_received", Color(0.8, 1.0, 0.55, 1.0), 0.75, 15.0, "+15")

		"enemy_shield_spark":
			if node.has_method("setup"):
				node.setup("shield_spark", Color(0.25, 0.85, 1.0, 1.0), 0.65, 8.0, "BLOCK")

		"enemy_split_burst":
			if node.has_method("setup"):
				node.setup("split_burst", Color(0.9, 0.35, 1.0, 1.0), 0.75, 3.0, "x3")

		"aura_healer":
			if node.has_method("setup"):
				node.setup("heal", 92.0, 1)
			if node.has_method("set_exact_radius_visible"):
				node.set_exact_radius_visible(true)

		"aura_shield":
			if node.has_method("setup"):
				node.setup("shield", 96.0, 1)
			if node.has_method("set_exact_radius_visible"):
				node.set_exact_radius_visible(true)

		"aura_disrupt":
			if node.has_method("setup"):
				node.setup("emp", 112.0, 1)
			if node.has_method("set_exact_radius_visible"):
				node.set_exact_radius_visible(true)

		"beam_heal_cast":
			if node.has_method("play_heal_cast"):
				node.play_heal_cast(0.65)

		"status_shield":
			if node.has_method("setup"):
				node.setup("shield", Color(0.25, 0.85, 1.0, 1.0), "SHIELD")

		"status_cloak":
			if node.has_method("setup"):
				node.setup("cloaked", Color(0.7, 0.45, 1.0, 1.0), "CLOAK")

		"death_pop":
			if node.has_method("setup"):
				node.setup("default", Color(1.0, 0.35, 0.25, 0.9), 0.55, 10)

		"swarm_death":
			if node.has_method("setup"):
				node.setup("swarm_death", Color(0.0, 0.95, 1.0, 0.9), 0.65, 16)

		"splash":
			if node.has_method("setup"):
				node.setup(76.0, Color(1.0, 0.45, 0.1, 0.6))

		"muzzle_flash":
			if node.has_method("setup"):
				node.setup(Color(0.35, 0.9, 1.0, 1.0), 2.0)

		"lightning_arc":
			if node.has_method("setup"):
				node.setup(Vector2(-70, 0), Vector2(70, 0), Color(0.45, 0.85, 1.0, 1.0))

		"sawblade_aoe":
			if node.has_method("setup"):
				node.setup(Color(1.0, 0.35, 0.35, 1.0), 86.0, 0.55)

		"damage_number":
			if node.has_method("setup"):
				node.setup(128, Color(1.0, 0.95, 0.45, 1.0))

	node.set_process(true)
	node.queue_redraw()


func _replay_detail_effect() -> void:
	if _selected_index < 0 or _selected_index >= EFFECT_DEFS.size():
		return

	for child in _detail_preview_root.get_children():
		child.queue_free()

	var def: Dictionary = EFFECT_DEFS[_selected_index]
	_detail_effect = _spawn_effect_preview(_detail_preview_root, def, _detail_zoom)


func _set_detail_zoom(value: float) -> void:
	_detail_zoom = clampf(value, 0.5, 3.0)

	if _detail_effect and is_instance_valid(_detail_effect):
		_detail_effect.scale = Vector2.ONE * _detail_zoom


func _show_prev() -> void:
	var next_index := _selected_index - 1
	if next_index < 0:
		next_index = EFFECT_DEFS.size() - 1
	_show_detail_index(next_index)


func _show_next() -> void:
	var next_index := _selected_index + 1
	if next_index >= EFFECT_DEFS.size():
		next_index = 0
	_show_detail_index(next_index)


func _close_detail() -> void:
	_detail_overlay.visible = false

	if _replay_timer:
		_replay_timer.stop()

	for child in _detail_preview_root.get_children():
		child.queue_free()

	_detail_effect = null


func _unhandled_input(event: InputEvent) -> void:
	if _detail_overlay and _detail_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_detail()
			get_viewport().set_input_as_handled()
			
			
func _prepare_effect_required_children(node: Node2D, def: Dictionary) -> void:
	var setup_key := str(def.get("setup", ""))
	var id := str(def.get("id", ""))

	if setup_key == "damage_number" or id == "damage_number":
		var label := Label.new()
		label.name = "Label"
		label.text = "-128"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-40, -18)
		label.size = Vector2(80, 36)
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		node.add_child(label)
		
func _spawn_gallery_card_effect(parent: Node2D, def: Dictionary, scale_factor: float = 1.0) -> void:
	var holder := Node2D.new()
	holder.name = "EffectLoopHolder"
	parent.add_child(holder)

	var replay := func() -> void:
		for child in holder.get_children():
			child.queue_free()

		_spawn_effect_preview(holder, def, scale_factor)

	replay.call()

	if _effect_is_one_shot(def):
		var timer := Timer.new()
		timer.wait_time = _get_effect_replay_interval(def)
		timer.one_shot = false
		timer.autostart = true
		timer.timeout.connect(replay)
		holder.add_child(timer)


func _effect_is_one_shot(def: Dictionary) -> bool:
	var setup_key := str(def.get("setup", ""))

	match setup_key:
		"aura_healer", "aura_shield", "aura_disrupt", "status_shield", "status_cloak":
			return false
		_:
			return true


func _get_effect_replay_interval(def: Dictionary) -> float:
	var setup_key := str(def.get("setup", ""))

	match setup_key:
		"lightning_arc":
			return 0.55
		"muzzle_flash":
			return 0.65
		"impact_basic":
			return 0.75
		"splash":
			return 0.85
		"damage_number":
			return 1.1
		"death_pop", "swarm_death":
			return 1.15
		"spawn_portal", "spawn_swarm":
			return 1.1
		"beam_heal_cast":
			return 0.9
		"enemy_heal_received", "enemy_shield_spark", "enemy_split_burst":
			return 0.9
		"sawblade_aoe":
			return 0.75
		_:
			return 1.0

extends Node2D

signal clicked(tower: Node2D)
signal shot_fired(tower, target, timestamp)
signal fire_rate_modifier_changed(tower, source, value)
signal target_selected(tower, target, reason)
signal target_rejected(tower, target, reason)

const ENEMY_CATEGORY_LAND := "land"
const ENEMY_CATEGORY_AIR := "air"
const DEFAULT_TARGET_CATEGORIES: Array[String] = [ENEMY_CATEGORY_LAND]

var tower_id: String
var display_name: String
var visual_type: String = "basic"
var attack_type: String = "single"
var description: String = ""
var cost: int
var damage: float
var attack_range: float
var fire_timer: float = 0.0
var idle_rotation: float = 0.0
var fire_rate: float # Seconds between shots
var projectile_speed: float = 500.0
var splash_radius: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var slow_radius: float = 0.0
var vulnerability_percent: float = 0.0
var vulnerability_duration: float = 0.0
var chain_jumps: int = 0
var chain_range: float = 0.0
var chain_falloff: float = 1.0
var target_categories: Array[String] = DEFAULT_TARGET_CATEGORIES.duplicate()
var grid_cell: Vector2i

# Level tracking
var upgrade_id: String = ""
var level_index: int = 0
var levels: Array = []
var config: Dictionary = {}
var is_selected: bool = false
var use_sprite: bool = false
var total_invested_gold: int = 0
var next_upgrade_ids: Array[String] = []
var tree_tier: int = 1
var branch_id: String = ""
var combo_type: String = "neutral"
var elements: Array[String] = []
var required_element_level: int = 0

const TOWER_SELL_REFUND_RATE := 0.7

@export var use_external_sprite: bool = false

# New sprite references
var base_sprite: Sprite2D = null
var turret_pivot: Node2D = null
var turret_sprite: Sprite2D = null
var muzzle: Marker2D = null

const TOWER_VISUAL_SIZE := 56.0
const TURRET_VISUAL_SIZE := 44.0

@export var aim_turn_speed: float = 12.0
@export var turret_angle_offset_degrees: float = 0.0
@export var AIM_ROTATION_OFFSET: float = 0.0 # Offset for sprite orientation (degrees)

# Targeting variables
var current_target: Node2D = null
var target_mode: String = "first"
var debug_draw_range: bool = false
var _target_scan_timer: float = 0.0
const TARGET_SCAN_INTERVAL: float = 0.1
# Pre-allocated targeting arrays — cleared and reused each scan to avoid per-frame GC pressure
var _visible_targets: Array = []
var _cloaked_targets: Array = []
var _enemies_in_range_cache: Array = []
var _stale_fire_rate_keys: Array = []
var debug_draw_target_line: bool = false

# Aim Visuals
@export var show_aim_indicator: bool = true
var aim_visual: Node2D = null
var aim_line: Line2D = null
var target_marker: Node2D = null
var aim_alpha: float = 0.0 # For smooth fading

# Shooting variables
var shoot_cooldown: float = 0.0
var fire_rate_modifiers: Dictionary = {}
var damage_modifiers: Dictionary = {}
var support_mode: String = ""
var support_bonus: float = 0.0
var support_max_targets: int = 4
var support_tick_timer: float = 0.0
const SUPPORT_REFRESH_INTERVAL: float = 0.18
var _active_supported_towers: Array = []
var _stale_damage_modifier_keys: Array = []
var projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
var muzzle_flash_scene: PackedScene = preload("res://scenes/effects/MuzzleFlash.tscn")
var projectile_container: Node2D = null

@onready var range_area: Area2D = $RangeArea
@onready var collision_shape: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var head: Node2D = $Head # Re-used as pivot
@onready var click_area: Area2D = $ClickArea
@onready var body: ColorRect = $Body
@onready var level_badge: Label = $LevelBadge
@onready var glow: Node2D = $Glow
@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")
@onready var audio_manager := get_tree().current_scene.get_node_or_null("AudioManager")

# Visual references (Legacy ColorRects)
@onready var barrel1: ColorRect = $Head/Barrel1
@onready var barrel2: ColorRect = $Head/Barrel2
@onready var barrel3: ColorRect = $Head/Barrel3
@onready var core: ColorRect = $Head/Core

func setup(p_config: Dictionary, cell: Vector2i) -> void:
	config = p_config
	tower_id = config.get("id", "")
	upgrade_id = tower_id
	display_name = config.get("name", config.get("display_name", "Unknown Tower"))
	visual_type = config.get("visual_type", "basic")
	attack_type = config.get("attack_type", "single")
	description = config.get("description", "")
	cost = config.get("cost", 0)
	total_invested_gold = cost
	next_upgrade_ids = _extract_string_array(config.get("next_upgrade_ids", []))
	tree_tier = config.get("tier", 1)
	branch_id = config.get("branch_id", "")
	combo_type = str(config.get("combo_type", "neutral"))
	elements = _extract_string_array(config.get("elements", []))
	required_element_level = int(config.get("required_element_level", 0))
	support_mode = str(config.get("support_mode", ""))
	support_bonus = float(config.get("support_bonus", 0.0))
	support_max_targets = int(config.get("support_max_targets", 4))
	projectile_speed = config.get("projectile_speed", 500.0)
	target_categories = _normalize_target_categories(config.get("target_categories", DEFAULT_TARGET_CATEGORIES))
	grid_cell = cell
	
	if config.has("levels"):
		levels = config["levels"]
		level_index = 0
		apply_level_stats()
	else:
		damage = config.get("damage", 10.0)
		attack_range = config.get("range", 160.0)
		fire_rate = config.get("fire_rate", 1.0)
		splash_radius = config.get("splash_radius", 0.0)
		slow_duration = config.get("slow_duration", 0.0)
		vulnerability_percent = config.get("vulnerability_percent", 0.0)
		vulnerability_duration = config.get("vulnerability_duration", 0.0)
		chain_jumps = config.get("chain_jumps", 0)
		chain_range = config.get("chain_range", 0.0)
		chain_falloff = config.get("chain_falloff", 1.0)
		_update_range_collision()
	
	_ensure_sprite_node()
	apply_level_visuals()

func _ensure_sprite_node() -> void:
	if base_sprite == null:
		base_sprite = get_node_or_null("BaseSprite")
		if base_sprite == null:
			base_sprite = Sprite2D.new()
			base_sprite.name = "BaseSprite"
			add_child(base_sprite)
			move_child(base_sprite, 0) # Behind others
	
	if turret_pivot == null:
		# Repurpose 'head' if possible, or use get_node_or_null
		turret_pivot = get_node_or_null("TurretPivot")
		if turret_pivot == null:
			if head:
				turret_pivot = head
			else:
				turret_pivot = Node2D.new()
				turret_pivot.name = "TurretPivot"
				add_child(turret_pivot)
	
	if turret_sprite == null:
		turret_sprite = turret_pivot.get_node_or_null("TurretSprite")
		if turret_sprite == null:
			turret_sprite = Sprite2D.new()
			turret_sprite.name = "TurretSprite"
			turret_pivot.add_child(turret_sprite)

	if muzzle == null:
		muzzle = turret_pivot.get_node_or_null("Muzzle")
		if muzzle == null:
			muzzle = Marker2D.new()
			muzzle.name = "Muzzle"
			muzzle.position = Vector2(32, 0)
			turret_pivot.add_child(muzzle)

func apply_level_stats() -> void:
	var data = get_current_level_data()
	if not data.is_empty():
		target_categories = _normalize_target_categories(data.get("target_categories", config.get("target_categories", DEFAULT_TARGET_CATEGORIES)))
		damage = data.get("damage", 10.0)
		attack_range = data.get("range", 160.0)
		fire_rate = data.get("fire_rate", 1.0)
		splash_radius = data.get("splash_radius", 0.0)
		slow_percent = data.get("slow_percent", 0.0)
		slow_duration = data.get("slow_duration", 0.0)
		slow_radius = data.get("slow_radius", 0.0)
		vulnerability_percent = data.get("vulnerability_percent", 0.0)
		vulnerability_duration = data.get("vulnerability_duration", 0.0)
		chain_jumps = data.get("chain_jumps", 0)
		chain_range = data.get("chain_range", 0.0)
		chain_falloff = data.get("chain_falloff", 1.0)
		support_mode = str(data.get("support_mode", config.get("support_mode", support_mode)))
		support_bonus = float(data.get("support_bonus", config.get("support_bonus", support_bonus)))
		support_max_targets = int(data.get("support_max_targets", config.get("support_max_targets", support_max_targets)))
		_update_range_collision()
		apply_level_visuals()
		queue_redraw()

func apply_level_visuals() -> void:
	_ensure_sprite_node()
	if not is_inside_tree(): return
	
	if level_badge:
		level_badge.text = "T" + str(tree_tier)
	
	# Hide legacy ColorRect nodes
	if body: body.visible = false
	if head: 
		# We still want head (pivot) to be visible if we draw procedural turret on it
		# but hide the children if we use sprites
		for child in head.get_children():
			if child is ColorRect:
				child.visible = false
	if glow: glow.visible = false
	
	# Handle external sprites
	if use_external_sprite:
		_load_external_sprites()
	else:
		use_sprite = false
		if base_sprite: base_sprite.visible = false
		if turret_sprite: turret_sprite.visible = false
	
	# Update muzzle based on tower type
	if muzzle:
		var muzzle_dist = 28.0
		if visual_type == "cannon": muzzle_dist = 36.0
		muzzle.position = Vector2(muzzle_dist, 0)

	# Reset base scale
	var base_scale = Vector2.ONE
	if visual_type == "rapid": base_scale = Vector2(0.8, 0.8)
	elif visual_type == "cannon": base_scale = Vector2(1.1, 1.1)
	scale = base_scale
	
	# Ensure visuals are created
	_ensure_aim_visual()
	queue_redraw()

func _load_external_sprites() -> void:
	var base_tex_path = "res://assets/sprites/towers/%s_tower_base_lv1.png" % visual_type
	var turret_tex_path = "res://assets/sprites/towers/%s_tower_turret_lv1.png" % visual_type
	var single_tex_path = "res://assets/sprites/towers/%s_tower_lv1.png" % visual_type
	
	var has_split = FileAccess.file_exists(base_tex_path) and FileAccess.file_exists(turret_tex_path)
	var has_single = FileAccess.file_exists(single_tex_path)
	
	if has_split:
		base_sprite.texture = load(base_tex_path)
		turret_sprite.texture = load(turret_tex_path)
		_fit_sprite_to_size(base_sprite, TOWER_VISUAL_SIZE)
		_fit_sprite_to_size(turret_sprite, TURRET_VISUAL_SIZE)
		base_sprite.visible = true
		turret_sprite.visible = true
		use_sprite = true
	elif has_single:
		base_sprite.texture = load(single_tex_path)
		_fit_sprite_to_size(base_sprite, TOWER_VISUAL_SIZE)
		base_sprite.visible = true
		turret_sprite.visible = false
		use_sprite = true
	else:
		use_sprite = false
		if base_sprite: base_sprite.visible = false
		if turret_sprite: turret_sprite.visible = false

func _fit_sprite_to_size(p_sprite: Sprite2D, target_size: float) -> void:
	if p_sprite == null or p_sprite.texture == null:
		return

	var tex_size := p_sprite.texture.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return

	var max_side : float = max(tex_size.x, tex_size.y)
	var scale_factor : float = target_size / max_side
	p_sprite.scale = Vector2.ONE * scale_factor
	p_sprite.centered = true
	p_sprite.position = Vector2.ZERO
	# Note: _ensure_aim_visual is now called in apply_level_visuals
	queue_redraw()

func _ensure_aim_visual() -> void:
	if not show_aim_indicator:
		if aim_visual: aim_visual.visible = false
		return
		
	if aim_visual == null:
		aim_visual = Node2D.new()
		aim_visual.name = "AimVisual"
		aim_visual.z_index = 50 # Ensure it's above most elements
		add_child(aim_visual)
		
		aim_line = Line2D.new()
		aim_line.name = "AimLine"
		# Setup gradient for a modern look
		var gradient = Gradient.new()
		var v_color = _get_tower_color()
		gradient.set_color(0, Color(v_color.r, v_color.g, v_color.b, 0.0))
		gradient.set_color(1, Color(v_color.r, v_color.g, v_color.b, 0.8))
		aim_line.gradient = gradient
		aim_line.width = 4.0
		aim_visual.add_child(aim_line)
		
		# Setup Target Marker
		target_marker = Node2D.new()
		target_marker.name = "TargetMarker"
		var marker_script = load("res://scripts/ui/target_marker.gd")
		if marker_script:
			target_marker.set_script(marker_script)
		aim_visual.add_child(target_marker)

	# Set color based on tower type
	var visual_color = _get_tower_color()
	if aim_line:
		aim_line.default_color = visual_color
		# Update gradient as well
		if aim_line.gradient:
			aim_line.gradient.set_color(0, Color(visual_color.r, visual_color.g, visual_color.b, 0.0))
			aim_line.gradient.set_color(1, Color(visual_color.r, visual_color.g, visual_color.b, 0.8))
	if target_marker: target_marker.color = visual_color
	
	aim_visual.visible = true

func _get_element_color(element_id: String) -> Color:
	match element_id:
		"light": return Color(1.0, 0.9, 0.35)
		"darkness": return Color(0.55, 0.25, 1.0)
		"water": return Color(0.35, 0.85, 1.0)
		"fire": return Color(1.0, 0.32, 0.12)
		"nature": return Color(0.25, 1.0, 0.45)
		"earth": return Color(0.95, 0.65, 0.28)
		_: return Color.WHITE

func _get_tower_color() -> Color:
	if not elements.is_empty():
		if combo_type == "periodic":
			return Color(0.9, 0.95, 1.0)
		return _get_element_color(elements[0])
	match visual_type:
		"basic": return Color(0.2, 0.8, 1.0) # Cyan
		"rapid": return Color(0.0, 1.0, 0.8) # Teal
		"cannon": return Color(1.0, 0.4, 0.1) # Amber/Orange-Red
		"slow": return Color(0.6, 1.0, 1.0) # Frost Cyan
		"sniper": return Color(0.1, 0.5, 1.0) # Electric Blue
		"lightning": return Color(0.5, 0.4, 1.0) # Neon Blue-Violet
		"sawblade": return Color(0.9, 0.1, 0.1) # Industrial Red
		_: return Color.WHITE

func _draw() -> void:
	# 1. Selection / Range Highlight
	if is_selected:
		# STANDARD: Draw world-unit range circle by compensating for GLOBAL scale
		var visual_range = attack_range / global_scale.x
		var local_origin = to_local(get_range_origin())
		
		# Inner Fill
		draw_circle(local_origin, visual_range, Color(0.2, 0.9, 1.0, 0.08))
		
		# Pulse Ring
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.005) * 0.1
		draw_arc(local_origin, visual_range, 0, TAU, 64, Color(0.2, 0.9, 1.0, 0.3 * pulse), 3.0)
		
		# Solid Outer Edge
		draw_arc(local_origin, visual_range, 0, TAU, 64, Color(0.2, 0.9, 1.0, 0.5), 1.5)
		
		# Tick marks for a technical feel
		for i in range(8):
			var a = i * PI/4 + (Time.get_ticks_msec() * 0.0002)
			var p1 = local_origin + Vector2.RIGHT.rotated(a) * (visual_range - 8)
			var p2 = local_origin + Vector2.RIGHT.rotated(a) * (visual_range + 4)
			draw_line(p1, p2, Color(0.2, 0.9, 1.0, 0.7), 2.0)
		
		if is_support_tower():
			var support_color := Color(0.35, 1.0, 0.85, 0.22)
			if support_mode == "damage":
				support_color = Color(1.0, 0.55, 0.2, 0.22)
			draw_circle(local_origin, visual_range, support_color)
			draw_arc(local_origin, visual_range, 0, TAU, 64, Color(support_color.r, support_color.g, support_color.b, 0.8), 2.0)
		else:
			_draw_selected_buff_badges(local_origin)
			
	elif debug_draw_range:
		var visual_range = attack_range / global_scale.x
		var local_origin = to_local(get_range_origin())
		draw_arc(local_origin, visual_range, 0, TAU, 32, Color(1, 1, 1, 0.1), 1.0)

	if not use_sprite:
		# 2. Base Plate (Static)
		_draw_base_plate()
		
		# 3. Turret (Rotated)
		if turret_pivot:
			draw_set_transform(Vector2.ZERO, turret_pivot.rotation, Vector2.ONE)
			_draw_turret_top()

func _draw_selected_buff_badges(local_origin: Vector2) -> void:
	var bonuses := get_active_support_bonuses()
	if bonuses.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := 13
	var y := local_origin.y - 48.0
	for bonus in bonuses:
		var label := ""
		var color := Color(0.5, 1.0, 0.75, 0.95)
		if str(bonus.get("type", "")) == "damage":
			label = "+%d%% DMG" % int(bonus.get("percent", 0))
			color = Color(1.0, 0.65, 0.28, 0.95)
		else:
			label = "+%d%% SPD" % int(bonus.get("percent", 0))
			color = Color(0.35, 1.0, 0.8, 0.95)
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var rect := Rect2(local_origin.x - size.x * 0.5 - 6.0, y - 14.0, size.x + 12.0, 18.0)
		draw_rect(rect, Color(0.03, 0.07, 0.10, 0.82), true)
		draw_rect(rect, color, false, 1.0)
		draw_string(font, Vector2(local_origin.x - size.x * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		y -= 20.0

func _draw_base_plate() -> void:
	var lvl = tree_tier
	var base_color = Color(0.08, 0.12, 0.18, 1.0)
	var accent_color = Color(0.2, 0.6, 1.0, 0.4)
	if not elements.is_empty():
		var ec := _get_tower_color()
		accent_color = Color(ec.r, ec.g, ec.b, 0.48)
	
	match visual_type:
		"cannon":
			base_color = Color(0.12, 0.08, 0.08, 1.0)
			accent_color = Color(1.0, 0.3, 0.1, 0.4)
		"slow":
			base_color = Color(0.08, 0.12, 0.15, 1.0)
			accent_color = Color(0.6, 0.9, 1.0, 0.4)
		"rapid":
			base_color = Color(0.05, 0.12, 0.1, 1.0)
			accent_color = Color(0.0, 1.0, 0.7, 0.4)
	if not elements.is_empty():
		var element_accent := _get_tower_color()
		accent_color = Color(element_accent.r, element_accent.g, element_accent.b, 0.5)

	# Main Base Rect
	draw_rect(Rect2(-24, -24, 48, 48), base_color)
	draw_rect(Rect2(-24, -24, 48, 48), accent_color, false, 1.0)
	
	# Corner Ticks
	var s = 6.0
	var p = 22.0
	draw_line(Vector2(-p, -p), Vector2(-p+s, -p), accent_color)
	draw_line(Vector2(-p, -p), Vector2(-p, -p+s), accent_color)
	draw_line(Vector2(p, -p), Vector2(p-s, -p), accent_color)
	draw_line(Vector2(p, -p), Vector2(p, -p+s), accent_color)
	
	# Level Details
	if lvl >= 2:
		draw_rect(Rect2(-18, -18, 36, 36), Color(accent_color.r, accent_color.g, accent_color.b, 0.15))
	if lvl >= 3:
		draw_arc(Vector2.ZERO, 20, 0, TAU, 32, accent_color, 1.5)

func _draw_turret_top() -> void:
	var lvl = tree_tier
	var main_color = Color(0.3, 0.8, 1.0, 1.0)
	var core_color = Color(0.6, 0.9, 1.0, 1.0)
	if not elements.is_empty():
		main_color = _get_tower_color()
		core_color = main_color.lightened(0.45)
	var size = 20.0
	
	match visual_type:
		"basic":
			# Barrel
			draw_rect(Rect2(0, -6, 26 + lvl * 4, 12), main_color)
			draw_rect(Rect2(2, -4, 22 + lvl * 4, 8), Color(0,0,0,0.5))
			# Core
			draw_circle(Vector2.ZERO, 15, main_color)
			draw_circle(Vector2.ZERO, 10, Color.BLACK)
			draw_circle(Vector2.ZERO, 6, core_color)
			
		"rapid":
			if elements.is_empty():
				main_color = Color(0.3, 1.0, 0.6, 1.0)
				core_color = Color(0.7, 1.0, 0.8, 1.0)
			# Twin Barrels
			draw_rect(Rect2(4, -10, 20 + lvl * 2, 6), main_color)
			draw_rect(Rect2(4, 4, 20 + lvl * 2, 6), main_color)
			# Arrow body
			var pts = PackedVector2Array([Vector2(-14, -16), Vector2(16, 0), Vector2(-14, 16), Vector2(-8, 0)])
			draw_colored_polygon(pts, main_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
			draw_circle(Vector2(-2, 0), 4, core_color)
			
		"cannon":
			if elements.is_empty():
				main_color = Color(1.0, 0.5, 0.2, 1.0)
				core_color = Color(1.0, 0.8, 0.6, 1.0)
			# Heavy Barrel
			draw_rect(Rect2(-6, -14, 32 + lvl * 4, 28), main_color)
			draw_rect(Rect2(-2, -10, 26 + lvl * 4, 20), Color.BLACK)
			# Plates
			draw_rect(Rect2(-14, -16, 14, 32), main_color)
			draw_rect(Rect2(-10, -12, 6, 24), core_color)
			
		"slow":
			if elements.is_empty():
				main_color = Color(0.6, 0.9, 1.0, 1.0)
				core_color = Color(0.9, 1.0, 1.0, 1.0)
			# Shard
			var pts = PackedVector2Array([Vector2(0, -20 - lvl*2), Vector2(16, 0), Vector2(0, 20 + lvl*2), Vector2(-16, 0)])
			draw_colored_polygon(pts, main_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
			# Crystal Core
			draw_rect(Rect2(-6, -6, 12, 12), core_color)
			# Aura ring
			draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r, main_color.g, main_color.b, 0.2), 2.0)
			
		"sniper":
			if elements.is_empty():
				main_color = Color(0.1, 0.6, 1.0, 1.0)
				core_color = Color(0.6, 0.9, 1.0, 1.0)
			# Long thin barrel
			draw_rect(Rect2(0, -4, 40 + lvl * 6, 8), main_color)
			draw_rect(Rect2(36 + lvl * 6, -5, 6, 10), Color.BLACK)
			# Sleek Body
			var pts = PackedVector2Array([Vector2(-18, -12), Vector2(12, -8), Vector2(12, 8), Vector2(-18, 12)])
			draw_colored_polygon(pts, main_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
			draw_circle(Vector2(-4, 0), 5, core_color)
			
		"lightning":
			if elements.is_empty():
				main_color = Color(0.5, 0.4, 1.0, 1.0)
				core_color = Color(0.8, 0.7, 1.0, 1.0)
			# Tesla Coil look
			draw_circle(Vector2.ZERO, 16, main_color)
			draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color.WHITE, 1.5)
			# Spikes
			for i in range(4):
				var a = i * PI/2 + (idle_rotation * 0.3)
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 24, main_color, 3.0)
				draw_circle(Vector2(cos(a), sin(a)) * 24, 4, core_color)
			
			# Electrical Crackle (Jagged lines around tower)
			for i in range(2):
				var crackle_pts = PackedVector2Array()
				var start_a = randf() * TAU
				var dist = randf_range(18, 30)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a) * 12)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a + 0.2) * dist)
				crackle_pts.append(Vector2.RIGHT.rotated(start_a - 0.2) * (dist + 5))
				draw_polyline(crackle_pts, core_color, 1.0)
				
		"sawblade":
			var blade_size = size + lvl * 2.0
			# Base
			draw_circle(Vector2.ZERO, blade_size * 0.7, Color(0.3, 0.3, 0.3))
			# Saw blade
			var teeth = 12
			var pts = []
			for i in range(teeth * 2):
				var angle = (float(i) / (teeth * 2)) * TAU + idle_rotation
				var r = blade_size * (1.0 if i % 2 == 0 else 0.7)
				pts.append(Vector2.RIGHT.rotated(angle) * r)
			draw_colored_polygon(PackedVector2Array(pts), Color(0.9, 0.1, 0.1))
			draw_circle(Vector2.ZERO, blade_size * 0.3, Color(0.5, 0.5, 0.5))
			
	# Level Indicators (Glow dots)
	for i in range(lvl):
		var offset = -12 + i * 8
		draw_circle(Vector2(offset, 0), 2, Color.WHITE)

func _update_range_collision() -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = attack_range

func get_current_level_data() -> Dictionary:
	if level_index >= 0 and level_index < levels.size():
		return levels[level_index]
	return {}

func get_next_level_data() -> Dictionary:
	if level_index + 1 < levels.size():
		return levels[level_index + 1]
	return {}
func can_upgrade() -> bool:
	return not next_upgrade_ids.is_empty()


func is_branch_point() -> bool:
	return next_upgrade_ids.size() > 1


## Returns the upgrade cost to advance to the single next upgrade.
## For branch points (multiple next_upgrade_ids), returns -1 — each branch
## target config carries its own upgrade_cost.
func get_upgrade_cost() -> int:
	if next_upgrade_ids.is_empty():
		return -1
	if next_upgrade_ids.size() > 1:
		return -1
	var next_id: String = next_upgrade_ids[0]
	var bm := _get_build_manager()
	if bm == null:
		return -1
	var next_config: Dictionary = bm.towers_config.get(next_id, {})
	return _get_config_upgrade_cost(next_config)


## Reads upgrade_cost from a config dict. This is the cost to upgrade INTO
## the tower represented by the config.
func _get_config_upgrade_cost(p_config: Dictionary) -> int:
	if p_config.is_empty():
		return -1
	if p_config.has("levels") and p_config["levels"].size() > 0:
		var cost_val = p_config["levels"][0].get("upgrade_cost", -1)
		if cost_val > 0:
			return cost_val
	return p_config.get("upgrade_cost", -1)


func get_sell_refund() -> int:
	var rate: float = 0.70
	match tree_tier:
		1: rate = 0.75
		2: rate = 0.70
		3: rate = 0.65
		4: rate = 0.60
		5: rate = 0.55
	return floori(float(total_invested_gold) * rate)


## Upgrade to the next tier. Looks up the next config from the tower tree and
## replaces all tower properties.
func upgrade() -> bool:
	if not can_upgrade():
		if OS.is_debug_build():
			print("[UPGRADE] cannot upgrade tower=%s — no next upgrades" % upgrade_id)
		return false
	if next_upgrade_ids.is_empty():
		return false

	var next_id: String = next_upgrade_ids[0]
	var bm := _get_build_manager()
	if bm == null:
		push_error("[UPGRADE] BuildManager not found for tower=%s" % upgrade_id)
		return false

	var next_config: Dictionary = bm.towers_config.get(next_id, {})
	if next_config.is_empty():
		push_error("[UPGRADE] Config not found for next_id=%s (current=%s)" % [next_id, upgrade_id])
		return false

	if OS.is_debug_build():
		print("[UPGRADE] current=%s target=%s cost=%d gold_available=%d" % [upgrade_id, next_id, _get_config_upgrade_cost(next_config), _get_current_gold()])

	return upgrade_to(next_id, next_config)


## Upgrade to a specific tower ID (branch selection or linear tree upgrade).
## Reads upgrade cost from the target config — each entry's upgrade_cost is the
## cost to upgrade INTO it.
func upgrade_to(target_tower_id: String, new_config: Dictionary) -> bool:
	var upgrade_cost := _get_config_upgrade_cost(new_config)
	if upgrade_cost <= 0:
		push_error("[UPGRADE] Invalid upgrade_cost=%d for tower=%s target=%s" % [upgrade_cost, upgrade_id, target_tower_id])
		return false

	# Apply new config
	config = new_config
	tower_id = target_tower_id
	upgrade_id = target_tower_id
	display_name = new_config.get("name", new_config.get("display_name", "Tower"))
	visual_type = new_config.get("visual_type", "basic")
	attack_type = new_config.get("attack_type", "single")
	description = new_config.get("description", "")
	cost = new_config.get("cost", 0)
	projectile_speed = new_config.get("projectile_speed", 500.0)
	target_categories = _normalize_target_categories(new_config.get("target_categories", DEFAULT_TARGET_CATEGORIES))

	if new_config.has("levels"):
		levels = new_config["levels"]
		level_index = 0
	else:
		levels = []
		level_index = 0
		damage = new_config.get("damage", 10.0)
		attack_range = new_config.get("range", 160.0)
		fire_rate = new_config.get("fire_rate", 1.0)
		splash_radius = new_config.get("splash_radius", 0.0)
		slow_percent = new_config.get("slow_percent", 0.0)
		slow_duration = new_config.get("slow_duration", 0.0)
		slow_radius = new_config.get("slow_radius", 0.0)
		vulnerability_percent = new_config.get("vulnerability_percent", 0.0)
		vulnerability_duration = new_config.get("vulnerability_duration", 0.0)
		chain_jumps = new_config.get("chain_jumps", 0)
		chain_range = new_config.get("chain_range", 0.0)
		chain_falloff = new_config.get("chain_falloff", 1.0)

	next_upgrade_ids = _extract_string_array(new_config.get("next_upgrade_ids", []))
	tree_tier = new_config.get("tier", tree_tier + 1)
	branch_id = new_config.get("branch_id", branch_id)
	combo_type = str(new_config.get("combo_type", combo_type))
	elements = _extract_string_array(new_config.get("elements", elements))
	required_element_level = int(new_config.get("required_element_level", required_element_level))
	support_mode = str(new_config.get("support_mode", ""))
	support_bonus = float(new_config.get("support_bonus", 0.0))
	support_max_targets = int(new_config.get("support_max_targets", 4))
	_clear_support_targets()

	total_invested_gold += upgrade_cost
	apply_level_stats()
	play_upgrade_effect()

	if level_badge:
		level_badge.text = "T%d" % tree_tier

	# Clear current target so tower re-evaluates with new stats/type
	current_target = null

	if OS.is_debug_build():
		print("[UPGRADE] applied id=%s tier=%d branch=%s invested=%d next=%s" % [upgrade_id, tree_tier, branch_id, total_invested_gold, str(next_upgrade_ids)])

	return true


func _get_build_manager() -> Node:
	return get_tree().current_scene.get_node_or_null("BuildManager")


func _get_current_gold() -> int:
	var gm := get_tree().current_scene.get_node_or_null("GameManager")
	if gm and "gold" in gm:
		return gm.gold
	return -1


func _extract_string_array(raw: Variant) -> Array[String]:
	var out: Array[String] = []
	if not (raw is Array):
		return out
	for item in raw as Array:
		out.append(str(item))
	return out

func play_upgrade_effect() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	
	var base_scale = Vector2.ONE
	if visual_type == "rapid": base_scale = Vector2(0.8, 0.8)
	elif visual_type == "cannon": base_scale = Vector2(1.2, 1.2)
	
	tween.tween_property(self, "scale", base_scale * 1.3, 0.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", base_scale, 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Spawn impact effect as a "flash"
	var impact_scene = preload("res://scenes/effects/ImpactEffect.tscn")
	if impact_scene:
		var effect = impact_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		effect.setup(Color(1, 1, 0.5, 0.8), 2.0)

func set_selected(value: bool) -> void:
	is_selected = value
	apply_level_visuals()
	queue_redraw()

func get_info() -> Dictionary:
	var can_up := can_upgrade()
	var up_cost := -1
	if can_up:
		up_cost = get_upgrade_cost()
	return {
		"id": tower_id,
		"upgrade_id": upgrade_id,
		"name": display_name,
		"tier": tree_tier,
		"branch_id": branch_id,
		"combo_type": combo_type,
		"elements": elements.duplicate(),
		"required_element_level": required_element_level,
		"is_max_tier": next_upgrade_ids.is_empty(),
		"is_branch_point": is_branch_point(),
		"next_upgrade_ids": next_upgrade_ids.duplicate(),
		"damage": damage,
		"effective_damage": get_effective_damage(),
		"damage_bonus_percent": get_damage_bonus_percent(),
		"range": attack_range,
		"fire_rate": fire_rate,
		"effective_fire_rate": get_effective_fire_rate(),
		"attack_speed_bonus_percent": get_attack_speed_bonus_percent(),
		"active_support_bonuses": get_active_support_bonuses(),
		"support_mode": support_mode,
		"support_bonus": support_bonus,
		"support_max_targets": support_max_targets,
		"upgrade_cost": up_cost,
		"can_upgrade": can_up,
		"total_invested_gold": total_invested_gold,
		"sell_refund": get_sell_refund(),
		"attack_type": attack_type,
		"splash_radius": splash_radius,
		"slow_percent": slow_percent,
		"slow_duration": slow_duration,
		"slow_radius": slow_radius,
		"vulnerability_percent": vulnerability_percent,
		"vulnerability_duration": vulnerability_duration,
		"chain_jumps": chain_jumps,
		"chain_range": chain_range,
		"target_categories": target_categories.duplicate(),
		"target_mode": target_mode
	}

func get_tower_id() -> String:
	return tower_id

func get_grid_cell() -> Vector2i:
	return grid_cell

func get_tower_level() -> int:
	return level_index + 1

func get_fire_origin() -> Vector2:
	if muzzle:
		return muzzle.global_position
	return global_position

func get_attack_range() -> float:
	return attack_range

func get_range_origin() -> Vector2:
	# STANDARD: Range guide must stay locked to the tower base
	return global_position

func get_targeting_origin() -> Vector2:
	# Used for rotation calculation source
	return global_position

func _exit_tree() -> void:
	_clear_support_targets()

func set_projectile_container(container: Node2D) -> void:
	projectile_container = container

func _ready() -> void:
	_disable_control_mouse_filter(self)
	
	if click_area:
		click_area.input_pickable = true
		click_area.input_event.connect(_on_click_area_input_event)
		# Ensure click area is reasonable (around 30px radius)
		var shape = click_area.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is RectangleShape2D:
			shape.shape.size = Vector2(60, 60)
	
	apply_level_visuals()
	queue_redraw()

func _disable_control_mouse_filter(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_disable_control_mouse_filter(child)

func _on_click_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if game_manager != null and (game_manager.is_paused or game_manager.is_game_over):
		return
		
	if is_support_tower():
		support_tick_timer -= delta
		if support_tick_timer <= 0.0:
			support_tick_timer = SUPPORT_REFRESH_INTERVAL
			_refresh_support_targets()
		if is_selected or debug_draw_range:
			queue_redraw()
		return
		
	_target_scan_timer -= delta
	if not is_valid_target(current_target):
		current_target = null
	if current_target == null or _target_scan_timer <= 0.0:
		_target_scan_timer = TARGET_SCAN_INTERVAL
		update_target()
	_update_aim_indicator(delta)
	
	idle_rotation += delta * 15.0 # Constant spin for visual flair
	if (visual_type == "sawblade" or visual_type == "lightning") and Engine.get_process_frames() % 2 == 0:
		queue_redraw()
	
	# Smooth visual rotation
	if turret_pivot:
		if is_valid_target(current_target):
			# STANDARD: Use targeting origin (usually center) for rotation calculation 
			# to avoid feedback loops if muzzle is offset and rotating
			var source_pos = get_targeting_origin()
			var target_pos = current_target.global_position
			if current_target.has_method("get_aim_point"):
				target_pos = current_target.get_aim_point()
			elif current_target.has_method("get_hit_origin"):
				target_pos = current_target.get_hit_origin()
			
			var direction = target_pos - source_pos
			var angle_to_target = direction.angle()
			
			var desired_angle = angle_to_target + deg_to_rad(turret_angle_offset_degrees) + deg_to_rad(AIM_ROTATION_OFFSET)
			
			# Rotation Speed Check
			var final_rot = lerp_angle(turret_pivot.rotation, desired_angle, min(1.0, aim_turn_speed * delta))
			turret_pivot.rotation = final_rot
		else:
			# Optional: slow return to zero or stay
			pass

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	
	if is_valid_target(current_target) and shoot_cooldown <= 0:
		shoot()
		shoot_cooldown = get_effective_fire_rate()
	
	# Redraw needed for selection highlight, range, OR procedural turret rotation
	if is_selected or debug_draw_range or (not use_sprite and is_valid_target(current_target)):
		queue_redraw()

func _update_aim_indicator(delta: float) -> void:
	if not show_aim_indicator or aim_visual == null:
		return
		
	var target_active = is_valid_target(current_target)
	
	pass # aim indicator active
	
	# Smooth Fading
	var target_alpha = 1.0 if target_active else 0.0
	aim_alpha = lerp(aim_alpha, target_alpha, 15.0 * delta)
	
	if aim_alpha < 0.01 and not target_active:
		aim_visual.modulate.a = 0.0
		return
	
	aim_visual.modulate.a = aim_alpha
	
	if is_instance_valid(current_target): # Use raw valid check here to allow fading even if slightly out of range
		var muzzle_pos = get_fire_origin()
		var target_pos = current_target.global_position
		if current_target.has_method("get_aim_point"):
			target_pos = current_target.get_aim_point()
		elif current_target.has_method("get_hit_origin"):
			target_pos = current_target.get_hit_origin()
		
		var local_muzzle = to_local(muzzle_pos)
		var local_target = to_local(target_pos)
		
		# Update Line
		if aim_line:
			aim_line.clear_points()
			aim_line.add_point(local_muzzle)
			# Add a midpoint for a more 'energy' feel
			var mid = (local_muzzle + local_target) * 0.5
			var perp = (local_target - local_muzzle).rotated(PI/2).normalized()
			var wobble = perp * sin(Time.get_ticks_msec() * 0.02) * 2.0
			aim_line.add_point(mid + wobble)
			aim_line.add_point(local_target)
			
		# Update Marker
		if target_marker:
			target_marker.position = local_target
			target_marker.visible = true
	else:
		# Target lost - clear visuals immediately to avoid "swinging stale beam" artifact
		if aim_line:
			aim_line.clear_points()
		if target_marker:
			target_marker.visible = false

func shoot() -> void:
	if attack_type == "aura":
		_perform_aura_attack()
		return
		
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		var container = projectile_container if projectile_container else get_tree().current_scene
		container.add_child(projectile)
		
		# STANDARD: Use fire origin anchor for projectile spawn
		var spawn_pos = get_fire_origin()
		projectile.global_position = spawn_pos
		
		pass # shoot debug removed for performance
		
		# Configure projectile based on tower type
		var proj_scale = 1.0
		var proj_color = Color(1, 1, 1, 1)
		var sfx_name = "tower_shoot_basic"
		
		if visual_type == "rapid":
			proj_scale = 0.7
			proj_color = Color(0.5, 1.0, 0.7, 1.0)
			sfx_name = "tower_shoot_rapid"
		elif visual_type == "cannon":
			proj_scale = 1.8
			proj_color = Color(1.0, 0.5, 0.5, 1.0)
			sfx_name = "tower_shoot_cannon"
		elif visual_type == "slow":
			proj_scale = 1.1
			proj_color = Color(0.4, 0.8, 1.0, 1.0) # Cyan
			sfx_name = "tower_shoot_slow"
		elif visual_type == "sniper":
			proj_scale = 0.9
			proj_color = Color(1.0, 0.9, 0.4, 1.0)
			sfx_name = "tower_shoot_sniper"
		elif visual_type == "lightning":
			proj_scale = 1.0
			proj_color = Color(0.5, 0.8, 1.0, 1.0)
			sfx_name = "tower_shoot_slow"
		
		var radius = splash_radius if attack_type == "splash" else slow_radius
		projectile.setup(current_target, int(round(get_effective_damage())), projectile_speed, attack_type, radius, slow_percent, slow_duration, target_categories, tower_id, vulnerability_percent, vulnerability_duration)
		
		if attack_type == "chain":
			if projectile.has_method("setup_chain"):
				projectile.setup_chain(chain_jumps, chain_range, chain_falloff)
		projectile.scale = Vector2(proj_scale, proj_scale)
		projectile.modulate = proj_color
		
		# VISUAL POLISH: Recoil and Flash
		play_fire_recoil()
		spawn_muzzle_flash(proj_color)
		
		if audio_manager:
			audio_manager.play_sfx(sfx_name)
	shot_fired.emit(self, current_target, Time.get_ticks_msec() / 1000.0)

func _perform_aura_attack() -> void:
	var enemies = get_enemies_in_range()
	var tower_color = _get_tower_color()
	
	# Visual effect for aura
	var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
	if not container: container = get_tree().current_scene
	
	if visual_type == "sawblade":
		var effect = Node2D.new()
		effect.set_script(load("res://scripts/effects/sawblade_aoe_effect.gd"))
		container.add_child(effect)
		effect.global_position = global_position
		if effect.has_method("setup"):
			effect.setup(tower_color, attack_range)
	elif muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		container.add_child(flash)
		flash.global_position = global_position
		if flash.has_method("setup"):
			flash.setup(tower_color, attack_range / 30.0) # Scale with range

	for enemy in enemies:
		if is_instance_valid(enemy):
			var enemy_pos = enemy.global_position
			enemy.take_damage(get_effective_damage(), enemy_pos, tower_id)
			
			# Apply damage-amplification debuff when configured
			if vulnerability_percent > 0 and enemy.has_method("apply_vulnerability"):
				enemy.apply_vulnerability(1.0 + vulnerability_percent, vulnerability_duration)
				
			# Small impact effect on each enemy
			var impact_scene = preload("res://scenes/effects/ImpactEffect.tscn")
			if impact_scene:
				var effect = impact_scene.instantiate()
				get_tree().current_scene.add_child(effect)
				effect.global_position = enemy_pos
				if effect.has_method("setup"):
					effect.setup(tower_color, 0.6)
	
	if not enemies.is_empty() and audio_manager:
		audio_manager.play_sfx("tower_shoot_sawblade")

func play_fire_recoil() -> void:
	# Recoil effect: Kick the turret sprite or pivot backward
	var target_node = turret_sprite if turret_sprite else turret_pivot
	if target_node == null: return
	
	# STANDARD: Use a fresh tween for every shot, but limit magnitude to avoid drift
	var tween = create_tween()
	var recoil_dist = 6.0
	if visual_type == "cannon": recoil_dist = 12.0
	elif visual_type == "rapid": recoil_dist = 3.0
	
	var original_pos = target_node.position
	
	if visual_type == "sawblade":
		# Vibrating 'spin' recoil
		tween.tween_property(target_node, "position", original_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2)), 0.05)
		tween.tween_property(target_node, "position", original_pos, 0.05)
		return

	# Kick back (opposite of muzzle direction, which is X+)
	var recoil_vec = Vector2(-recoil_dist, 0)
	if visual_type == "sniper": recoil_vec = Vector2(-15.0, 0) # Stronger kick for sniper
	
	tween.tween_property(target_node, "position", original_pos + recoil_vec, 0.05)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Snap back
	var snap_time = 0.15
	if visual_type == "cannon": snap_time = 0.25
	elif visual_type == "sniper": snap_time = 0.3
	
	tween.tween_property(target_node, "position", original_pos, snap_time)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func spawn_muzzle_flash(color: Color) -> void:
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		# STANDARD: effects in MapRoot/EffectsContainer
		var container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if not container: container = get_tree().current_scene
		
		container.add_child(flash)
		flash.global_position = get_fire_origin()
		flash.global_rotation = turret_pivot.global_rotation if turret_pivot else global_rotation
		
		if flash.has_method("setup"):
			var flash_scale = 1.0
			if visual_type == "cannon": flash_scale = 1.6
			elif visual_type == "rapid": flash_scale = 0.6
			elif visual_type == "sniper": flash_scale = 1.2
			elif visual_type == "lightning": flash_scale = 1.4
			flash.setup(color, flash_scale)

func update_target() -> void:
	var next_target := find_target()
	if next_target != current_target:
		current_target = next_target
		if current_target:
			target_selected.emit(self, current_target, "selected_%s" % target_mode)

func is_valid_target(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy): return false
	if not enemy.has_method("is_alive") or not enemy.is_alive(): return false
	if not can_target_enemy(enemy):
		target_rejected.emit(self, enemy, "category_not_targetable")
		return false
	
	# STANDARD: Use canonical range origin and global distance check
	var target_pos = enemy.global_position
	if enemy.has_method("get_aim_point"):
		target_pos = enemy.get_aim_point()
	elif enemy.has_method("get_hit_origin"):
		target_pos = enemy.get_hit_origin()
	var dist = get_range_origin().distance_to(target_pos)
	return dist <= attack_range

func can_target_enemy(enemy: Variant) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if not enemy.has_method("get_enemy_category"):
		return true
	return target_categories.has(str(enemy.get_enemy_category()).to_lower())

func _normalize_target_categories(raw_categories) -> Array[String]:
	var normalized: Array[String] = []
	if raw_categories is Array:
		for category in raw_categories:
			var value = str(category).strip_edges().to_lower()
			if (value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR) and not normalized.has(value):
				normalized.append(value)
	elif raw_categories != null:
		var value = str(raw_categories).strip_edges().to_lower()
		if value == ENEMY_CATEGORY_LAND or value == ENEMY_CATEGORY_AIR:
			normalized.append(value)
	if normalized.is_empty():
		normalized.append(ENEMY_CATEGORY_LAND)
	return normalized

func find_target() -> Node2D:
	var enemies = get_enemies_in_range()
	if enemies.is_empty(): return null
	
	_visible_targets.clear()
	_cloaked_targets.clear()

	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_cloaked") and enemy.is_cloaked():
			_cloaked_targets.append(enemy)
		else:
			_visible_targets.append(enemy)

	var target_pool = enemies
	if _visible_targets.size() > 0:
		target_pool = _visible_targets
		if OS.is_debug_build() and _cloaked_targets.size() > 0:
			print("[Targeting] Tower ", visual_type, " found ", _visible_targets.size(), " visible targets and ", _cloaked_targets.size(), " cloaked target. Targeting visible first.")
		var preferred = select_first_target(_visible_targets)
		for cloaked in _cloaked_targets:
			target_rejected.emit(self, cloaked, "cloaked_deferred_visible_target_exists")
			if cloaked.has_method("notify_stealth_deferred"):
				cloaked.notify_stealth_deferred(preferred)
	elif _cloaked_targets.size() > 0:
		target_pool = _cloaked_targets
		for cloaked in _cloaked_targets:
			if cloaked.has_method("notify_stealth_targetable"):
				cloaked.notify_stealth_targetable()
		if OS.is_debug_build():
			print("[Targeting] Tower ", visual_type, " has only cloaked targets. Cloaked target allowed.")

	match target_mode:
		"first":
			return select_first_target(target_pool)
		"last":
			return select_last_target(target_pool)
		"nearest", "closest":
			return select_nearest_target(target_pool)
		"strongest":
			return select_strongest_target(target_pool)
		"weakest":
			return select_weakest_target(target_pool)
		"fastest":
			return select_fastest_target(target_pool)
		"air_first":
			return select_priority_type_target(target_pool, ["flyer", "fast_flyer", "armored_flyer"])
		"support_first":
			return select_priority_type_target(target_pool, ["healer", "disruptor"])
		"shield_first":
			return select_priority_type_target(target_pool, ["shieldbearer", "bulwark"])
		_:
			return select_first_target(target_pool)

func get_enemies_in_range() -> Array:
	_enemies_in_range_cache.clear()
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_valid_target(enemy):
			_enemies_in_range_cache.append(enemy)
	return _enemies_in_range_cache

func apply_fire_rate_modifier(source: Node, multiplier: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	# multiplier < 1.0 slows the tower down; multiplier > 1.0 speeds it up.
	var value := clampf(multiplier, 0.05, 5.0)
	if not fire_rate_modifiers.has(key) or abs(float(fire_rate_modifiers[key].get("value", 1.0)) - value) > 0.001:
		fire_rate_modifiers[key] = {"source": source, "value": value}
		fire_rate_modifier_changed.emit(self, source, value)
		if is_selected:
			queue_redraw()
		if OS.is_debug_build():
			print("[TowerFireRateModifier] tower=%s source=%s multiplier=%.2f effective_interval=%.2f" % [tower_id, str(source.name), value, get_effective_fire_rate()])

func remove_fire_rate_modifier(source: Node) -> void:
	if source == null:
		return
	var key := source.get_instance_id()
	if fire_rate_modifiers.has(key):
		fire_rate_modifiers.erase(key)
		fire_rate_modifier_changed.emit(self, source, 1.0)
		if is_selected:
			queue_redraw()
		if OS.is_debug_build():
			print("[EnemyFeature][TowerDisruptionRemoved] tower=%s source=%s effective_interval=%.2f" % [tower_id, str(source.name), get_effective_fire_rate()])

func get_effective_fire_rate() -> float:
	var total_multiplier := 1.0
	_stale_fire_rate_keys.clear()
	for key in fire_rate_modifiers.keys():
		var entry: Dictionary = fire_rate_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			_stale_fire_rate_keys.append(key)
			continue
		total_multiplier *= clampf(float(entry.get("value", 1.0)), 0.05, 5.0)
	for key in _stale_fire_rate_keys:
		fire_rate_modifiers.erase(key)
	return fire_rate / maxf(total_multiplier, 0.05)

func apply_damage_modifier(source: Node, multiplier: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	var value := maxf(1.0, multiplier)
	damage_modifiers[key] = {"source": source, "value": value}
	if is_selected:
		queue_redraw()

func remove_damage_modifier(source: Node) -> void:
	if source == null:
		return
	var key := source.get_instance_id()
	if damage_modifiers.has(key):
		damage_modifiers.erase(key)
		if is_selected:
			queue_redraw()

func get_effective_damage() -> float:
	var strongest_multiplier := 1.0
	_stale_damage_modifier_keys.clear()
	for key in damage_modifiers.keys():
		var entry: Dictionary = damage_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			_stale_damage_modifier_keys.append(key)
			continue
		strongest_multiplier = maxf(strongest_multiplier, maxf(1.0, float(entry.get("value", 1.0))))
	for key in _stale_damage_modifier_keys:
		damage_modifiers.erase(key)
	return damage * strongest_multiplier

func get_damage_bonus_percent() -> int:
	var effective := get_effective_damage()
	if damage <= 0.0:
		return 0
	return int(round(((effective / damage) - 1.0) * 100.0))

func get_attack_speed_bonus_percent() -> int:
	var effective := get_effective_fire_rate()
	if fire_rate <= 0.0:
		return 0
	return int(round(((fire_rate / effective) - 1.0) * 100.0))

func get_active_support_bonuses() -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	for key in damage_modifiers.keys():
		var dmg_entry: Dictionary = damage_modifiers[key]
		var dmg_source: Node = dmg_entry.get("source", null)
		if is_instance_valid(dmg_source):
			var mult := float(dmg_entry.get("value", 1.0))
			if mult > 1.001:
				bonuses.append({"type": "damage", "percent": int(round((mult - 1.0) * 100.0)), "source": _support_source_name(dmg_source)})
	for key in fire_rate_modifiers.keys():
		var spd_entry: Dictionary = fire_rate_modifiers[key]
		var spd_source: Node = spd_entry.get("source", null)
		if is_instance_valid(spd_source):
			var mult := float(spd_entry.get("value", 1.0))
			if mult > 1.001:
				bonuses.append({"type": "attack_speed", "percent": int(round((mult - 1.0) * 100.0)), "source": _support_source_name(spd_source)})
	return bonuses

func _support_source_name(source: Variant) -> String:
	if source == null or not is_instance_valid(source):
		return "Support Tower"
	if source.has_method("get_tower_display_name"):
		return str(source.get_tower_display_name())
	var display_value: Variant = source.get("display_name")
	if display_value != null:
		return str(display_value)
	return "Support Tower"

func get_tower_display_name() -> String:
	return display_name

func is_support_tower() -> bool:
	return attack_type == "support" or support_mode != ""

func _refresh_support_targets() -> void:
	if not is_support_tower():
		_clear_support_targets()
		return
	var candidates: Array = []
	var towers: Array = get_tree().get_nodes_in_group("placed_towers")
	for candidate in towers:
		if candidate == self or not is_instance_valid(candidate):
			continue
		if candidate.has_method("is_support_tower") and candidate.is_support_tower():
			continue
		if not (candidate is Node2D):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= attack_range:
			candidates.append({"tower": candidate, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0))
	)
	var next_targets: Array = []
	var limit: int = max(1, support_max_targets)
	for i in range(min(limit, candidates.size())):
		var candidate_tower = candidates[i].get("tower")
		if candidate_tower != null and is_instance_valid(candidate_tower):
			next_targets.append(candidate_tower)
	for old_tower in _active_supported_towers.duplicate():
		if old_tower == null or not is_instance_valid(old_tower):
			continue
		if not next_targets.has(old_tower):
			_remove_support_from_tower(old_tower)
	for next_tower in next_targets:
		_apply_support_to_tower(next_tower)
	_active_supported_towers = next_targets

func _apply_support_to_tower(target_tower: Variant) -> void:
	if target_tower == null or not is_instance_valid(target_tower):
		return
	match support_mode:
		"attack_speed":
			if target_tower.has_method("apply_fire_rate_modifier"):
				var multiplier := 1.0 + maxf(0.0, support_bonus)
				target_tower.apply_fire_rate_modifier(self, multiplier)
		"damage":
			if target_tower.has_method("apply_damage_modifier"):
				target_tower.apply_damage_modifier(self, 1.0 + maxf(0.0, support_bonus))

func _remove_support_from_tower(target_tower: Variant) -> void:
	if target_tower == null or not is_instance_valid(target_tower):
		return
	match support_mode:
		"attack_speed":
			if target_tower.has_method("remove_fire_rate_modifier"):
				target_tower.remove_fire_rate_modifier(self)
		"damage":
			if target_tower.has_method("remove_damage_modifier"):
				target_tower.remove_damage_modifier(self)

func _clear_support_targets() -> void:
	# Support targets can already be freed when this tower exits the tree.
	# Keep this untyped/guarded so Godot does not try to pass a freed Object
	# into a typed Node parameter before our validity checks can run.
	for target_tower in _active_supported_towers.duplicate():
		if target_tower != null and is_instance_valid(target_tower):
			_remove_support_from_tower(target_tower)
	_active_supported_towers.clear()

func select_first_target(enemies: Array) -> Node2D:
	var best_target = null
	var max_weighted_prog = -1.0
	for enemy in enemies:
		if enemy.has_method("get_path_progress"):
			var prog = enemy.get_path_progress()
			var priority = 1.0
			if enemy.has_method("get_priority_score"):
				priority = enemy.get_priority_score()
				
			var weighted_prog = prog * priority
			if weighted_prog > max_weighted_prog:
				max_weighted_prog = weighted_prog
				best_target = enemy
	return best_target

func select_last_target(enemies: Array) -> Node2D:
	var best_target = null
	var min_progress = INF
	for enemy in enemies:
		if enemy.has_method("get_path_progress"):
			var prog = enemy.get_path_progress()
			if prog < min_progress:
				min_progress = prog
				best_target = enemy
	return best_target

func select_nearest_target(enemies: Array) -> Node2D:
	var best_target = null
	var min_dist = INF
	var source_pos = get_range_origin()
	for enemy in enemies:
		# STANDARD: Use global position distance check from range origin
		var dist = source_pos.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			best_target = enemy
	return best_target

func select_strongest_target(enemies: Array) -> Node2D:
	var best_target = null
	var max_hp = -1.0
	for enemy in enemies:
		if enemy.has_method("get_current_hp"):
			var hp = enemy.get_current_hp()
			if hp > max_hp:
				max_hp = hp
				best_target = enemy
	return best_target

func select_weakest_target(enemies: Array) -> Node2D:
	var best_target = null
	var min_hp = INF
	for enemy in enemies:
		if enemy.has_method("get_current_hp"):
			var hp = enemy.get_current_hp()
			if hp < min_hp:
				min_hp = hp
				best_target = enemy
	return best_target

func select_fastest_target(enemies: Array) -> Node2D:
	var best_target = null
	var max_speed = -1.0
	for enemy in enemies:
		if enemy.has_method("get_movement_speed"):
			var spd = enemy.get_movement_speed()
			if spd > max_speed:
				max_speed = spd
				best_target = enemy
		elif enemy.has_method("get_speed"):
			var spd = enemy.get_speed()
			if spd > max_speed:
				max_speed = spd
				best_target = enemy
	if best_target == null:
		best_target = select_first_target(enemies)
	return best_target

## Prioritises enemies whose `enemy_type` appears in `priority_types`.
## Within the priority group, picks the one furthest along the path.
## Falls back to select_first_target if no priority match is in range.
func select_priority_type_target(enemies: Array, priority_types: Array) -> Node2D:
	var priority_pool: Array = []
	for enemy in enemies:
		var etype = ""
		if enemy.has_method("get_enemy_type"):
			etype = enemy.get_enemy_type()
		elif "enemy_type" in enemy:
			etype = str(enemy.enemy_type)
		if etype in priority_types:
			priority_pool.append(enemy)
	if priority_pool.is_empty():
		return select_first_target(enemies)
	return select_first_target(priority_pool)

func set_target_mode(mode: String) -> void:
	var supported = ["first", "last", "nearest", "closest", "strongest", "weakest",
					"fastest", "air_first", "support_first", "shield_first"]
	if mode in supported:
		target_mode = mode
		current_target = null
		update_target()
		queue_redraw()

func get_target_mode() -> String:
	return target_mode

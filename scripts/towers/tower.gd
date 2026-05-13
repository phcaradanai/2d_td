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
var _stale_damage_keys: Array = []

# Element TD-style Trickery clone support.
# Trickery does not attack creeps directly. It temporarily projects a clone of
# one nearby non-support tower by giving that tower bonus clone damage.
var clone_damage_multiplier: float = 0.0
var clone_duration: float = 0.0
var clone_interval: float = 15.0
var clone_current_target: Node2D = null
var _clone_active_time_left: float = 0.0
var _clone_scan_time_left: float = 0.0
var _clone_recent_target_cooldowns: Dictionary = {} # tower instance id -> seconds remaining before this Trickery can clone it again
const CLONE_SCAN_INTERVAL := 0.25
const TRICKERY_RECENT_TARGET_COOLDOWN := 60.0
var _clone_last_target_instance_id: int = 0
var clone_manual_target: Node2D = null
var _clone_timer_started: bool = false

# Manual Trickery targeting UX. Drag from a selected Trickery tower to the
# non-support tower you want to clone. This is cheaper and clearer than keeping
# click badges visible on every possible target.
var _trickery_dragging_target: bool = false
var _trickery_drag_world_pos: Vector2 = Vector2.ZERO
var _trickery_drag_hover_target: Node2D = null
const TRICKERY_DRAG_TARGET_RADIUS := 36.0

# Element TD-style Well / Blacksmith support auras.
# Well buffs attack speed; Blacksmith buffs damage. They support up to 4
# nearby non-support towers and do not attack creeps directly.
var support_type: String = ""
var support_value: float = 0.0
var support_limit: int = 4
var support_targets: Array = []
var _support_scan_timer: float = 0.0
const SUPPORT_SCAN_INTERVAL := 0.25
const BUFF_BADGE_FONT_SIZE := 10
const BUFF_BADGE_PADDING := Vector2(6.0, 3.0)
const SUPPORT_BADGE_SIZE := Vector2(108.0, 20.0)
const SUPPORT_COOLDOWN_RING_RADIUS := 12.0
const SUPPORT_OVERLAY_Z_INDEX := 2000
const CLONE_FIRE_FLASH_MS := 180
const SUPPORT_OVERLAY_MAX_TARGET_HINTS := 8

var _normal_z_index: int = 0
var _normal_z_as_relative: bool = true
var _selection_z_lift_active: bool = false
var _clone_visual_fire_until_msec: int = 0
var _clone_visual_fire_target_global: Vector2 = Vector2.ZERO

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
	projectile_speed = config.get("projectile_speed", 500.0)
	target_categories = _normalize_target_categories(config.get("target_categories", DEFAULT_TARGET_CATEGORIES))
	if tower_id == "basic_tower_t1" or display_name == "Neutral Arrow Tower":
		target_categories = [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]
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
		clone_damage_multiplier = float(config.get("clone_damage_multiplier", 0.0))
		clone_duration = float(config.get("clone_duration", 0.0))
		clone_interval = float(config.get("clone_interval", 15.0))
		support_type = str(config.get("support_type", "")).to_lower()
		support_value = float(config.get("support_value", 0.0))
		support_limit = int(config.get("support_limit", 4))
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
		if tower_id == "basic_tower_t1" or display_name == "Neutral Arrow Tower":
			target_categories = [ENEMY_CATEGORY_LAND, ENEMY_CATEGORY_AIR]
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
		clone_damage_multiplier = float(data.get("clone_damage_multiplier", config.get("clone_damage_multiplier", 0.0)))
		clone_duration = float(data.get("clone_duration", config.get("clone_duration", 0.0)))
		clone_interval = float(data.get("clone_interval", config.get("clone_interval", 15.0)))
		support_type = str(data.get("support_type", config.get("support_type", support_type))).to_lower()
		support_value = float(data.get("support_value", config.get("support_value", support_value)))
		support_limit = int(data.get("support_limit", config.get("support_limit", support_limit)))
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
		"trickery": return Color(0.75, 0.45, 1.0) # Hologram violet
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
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Support preview overlays are intentionally selection-only and are drawn LAST.
	# Drawing after the tower body keeps badges/ghosts as a top-up layer instead
	# of letting the tower base/turret cover them. The selected support tower also
	# gets a temporary z-index lift in set_selected(), so overlays stay above
	# sibling towers on the map.
	_draw_selected_support_overlays()

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
				
		"trickery":
			# Hologram prism. This is a support tower, not a direct attack.
			main_color = Color(0.72, 0.42, 1.0, 1.0)
			core_color = Color(0.95, 0.82, 1.0, 1.0)
			var prism = PackedVector2Array([Vector2(0, -22), Vector2(18, -4), Vector2(10, 18), Vector2(-10, 18), Vector2(-18, -4)])
			draw_colored_polygon(prism, Color(main_color.r, main_color.g, main_color.b, 0.55))
			draw_polyline(prism + PackedVector2Array([prism[0]]), core_color, 1.5)
			draw_circle(Vector2.ZERO, 8, Color(0.15, 0.05, 0.25, 0.9))
			draw_circle(Vector2.ZERO, 4 + sin(idle_rotation) * 1.5, core_color)
			for i in range(3):
				var a = idle_rotation * 0.7 + i * TAU / 3.0
				draw_line(Vector2.RIGHT.rotated(a) * 12, Vector2.RIGHT.rotated(a) * 22, Color(0.9, 0.7, 1.0, 0.65), 1.5)

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


func get_next_upgrade_id() -> String:
	if next_upgrade_ids.is_empty():
		return ""
	return str(next_upgrade_ids[0])


func get_next_upgrade_config() -> Dictionary:
	var next_id := get_next_upgrade_id()
	if next_id.is_empty():
		return {}
	var bm := _get_build_manager()
	if bm == null:
		return {}
	return bm.towers_config.get(next_id, {})


func can_upgrade() -> bool:
	if get_next_upgrade_id().is_empty():
		return false
	if get_next_upgrade_config().is_empty():
		return false
	return true


func is_branch_point() -> bool:
	return next_upgrade_ids.size() > 1


## Returns the upgrade cost to advance to the single next upgrade.
## For branch points (multiple next_upgrade_ids), returns -1 — each branch
## target config carries its own upgrade_cost.
func get_upgrade_cost() -> int:
	if get_next_upgrade_id().is_empty():
		return -1
	if next_upgrade_ids.size() > 1:
		return -1
	var next_config := get_next_upgrade_config()
	if next_config.is_empty():
		return -1
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
	if str(config.get("sell_refund_mode", "")) == "nearly_full" or combo_type == "neutral":
		return max(0, total_invested_gold - int(config.get("sell_refund_loss", 1)))
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

	var next_id := get_next_upgrade_id()
	if next_id.is_empty():
		return false

	var next_config := get_next_upgrade_config()
	if next_config.is_empty():
		push_error("[UPGRADE] Config not found for next_id=%s (current=%s)" % [next_id, upgrade_id])
		return false
	if not _is_upgrade_config_unlocked(next_config):
		if OS.is_debug_build():
			print("[UPGRADE] blocked by element gate current=%s target=%s" % [upgrade_id, next_id])
		return false

	if OS.is_debug_build():
		print("[UPGRADE] current=%s target=%s cost=%d gold_available=%d" % [upgrade_id, next_id, _get_config_upgrade_cost(next_config), _get_current_gold()])

	return upgrade_to(next_id, next_config)


## Upgrade to a specific tower ID (branch selection or linear tree upgrade).
## Reads upgrade cost from the target config — each entry's upgrade_cost is the
## cost to upgrade INTO it.
func upgrade_to(target_tower_id: String, new_config: Dictionary) -> bool:
	_clear_support_targets()
	_remove_clone_from_current_target()
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
		clone_damage_multiplier = float(new_config.get("clone_damage_multiplier", 0.0))
		clone_duration = float(new_config.get("clone_duration", 0.0))
		clone_interval = float(new_config.get("clone_interval", 15.0))
		support_type = str(new_config.get("support_type", "")).to_lower()
		support_value = float(new_config.get("support_value", 0.0))
		support_limit = int(new_config.get("support_limit", 4))

	next_upgrade_ids = _extract_string_array(new_config.get("next_upgrade_ids", []))
	tree_tier = new_config.get("tier", tree_tier + 1)
	branch_id = new_config.get("branch_id", branch_id)
	combo_type = str(new_config.get("combo_type", combo_type))
	elements = _extract_string_array(new_config.get("elements", elements))
	required_element_level = int(new_config.get("required_element_level", required_element_level))

	total_invested_gold += upgrade_cost
	apply_level_stats()
	play_upgrade_effect()

	if level_badge:
		level_badge.text = "T%d" % tree_tier

	# Clear old Trickery clone link when changing identity.
	clone_manual_target = null
	_remove_clone_from_current_target()

	# Clear current target so tower re-evaluates with new stats/type
	current_target = null

	if OS.is_debug_build():
		print("[UPGRADE] applied id=%s tier=%d branch=%s invested=%d next=%s" % [upgrade_id, tree_tier, branch_id, total_invested_gold, str(next_upgrade_ids)])

	return true


func _get_build_manager() -> Node:
	return get_tree().current_scene.get_node_or_null("BuildManager")


func _get_element_progression_manager() -> Node:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("ElementProgressionManager")


func _is_upgrade_config_unlocked(next_config: Dictionary) -> bool:
	if next_config.is_empty():
		return false
	var element_manager := _get_element_progression_manager()
	if element_manager == null or not element_manager.has_method("can_build_tower"):
		return true
	return bool(element_manager.call("can_build_tower", next_config))


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
	if not value and _trickery_dragging_target:
		_cancel_trickery_drag_targeting()
	is_selected = value
	_update_support_overlay_z_lift()
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
		"range": attack_range,
		"fire_rate": fire_rate,
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
		"clone_damage_multiplier": clone_damage_multiplier,
		"clone_duration": clone_duration,
		"clone_interval": clone_interval,
		"clone_target_name": _get_clone_target_name(),
		"clone_manual_target_name": _get_manual_clone_target_name(),
		"clone_active_time_left": _clone_active_time_left,
		"support_type": support_type,
		"support_value": support_value,
		"support_limit": support_limit,
		"support_target_count": _count_valid_support_targets(),
		"effective_damage": get_effective_damage(),
		"effective_fire_rate": get_effective_fire_rate(),
		"active_damage_bonus_percent": get_active_damage_bonus_percent(),
		"active_damage_bonus_tag": get_active_damage_bonus_tag(),
		"active_fire_rate_bonus_percent": get_active_fire_rate_bonus_percent(),
		"active_fire_rate_bonus_tag": get_active_fire_rate_bonus_tag(),
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
		if is_selected and _is_trickery_clone_support():
			_begin_trickery_drag_targeting(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		clicked.emit(self)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not _trickery_dragging_target:
		return
	if not is_selected or not _is_trickery_clone_support():
		_cancel_trickery_drag_targeting()
		return

	if event is InputEventMouseMotion:
		_update_trickery_drag_targeting(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_trickery_drag_targeting(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_trickery_drag_targeting()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if game_manager != null and (game_manager.is_paused or game_manager.is_game_over):
		return

	if _is_support_aura():
		_process_support_aura(delta)
		idle_rotation += delta * 4.0
		if turret_pivot:
			turret_pivot.rotation += delta * 0.4
		if is_selected:
			queue_redraw()
		return

	if _is_trickery_clone_support():
		_process_trickery_clone_support(delta)
		idle_rotation += delta * 5.0
		if turret_pivot and is_instance_valid(clone_current_target):
			var dir := clone_current_target.global_position - get_targeting_origin()
			if dir.length_squared() > 0.001:
				turret_pivot.rotation = lerp_angle(turret_pivot.rotation, dir.angle(), min(1.0, aim_turn_speed * delta))
		if is_selected:
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
	if _is_support_aura() or _is_trickery_clone_support():
		return
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
		projectile.setup(current_target, int(round(get_effective_damage())), projectile_speed, attack_type, radius, slow_percent, slow_duration, target_categories, tower_id)
		
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

	var clone_source := _get_active_clone_source()
	if is_instance_valid(clone_source) and clone_source.has_method("notify_clone_target_fired"):
		clone_source.notify_clone_target_fired(self, current_target)
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
			enemy.take_damage(damage, enemy_pos, tower_id)
			
			# Apply vulnerability if sawblade
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


func _is_support_aura() -> bool:
	var lower_support := support_type.to_lower()
	return attack_type == "support_aura" or lower_support == "attack_speed" or lower_support == "damage"

func _get_support_color() -> Color:
	if support_type == "attack_speed":
		return Color(0.35, 0.85, 1.0, 1.0)
	if support_type == "damage":
		return Color(1.0, 0.55, 0.25, 1.0)
	return Color(0.65, 0.85, 1.0, 1.0)

func _draw_selected_support_overlays() -> void:
	# Keep support overlays selection-only. This prevents visual clutter and avoids
	# redrawing badges on every buffed tower during normal gameplay.
	if is_selected and _is_trickery_clone_support():
		_draw_trickery_selection_overlay()

	if is_selected and _is_support_aura():
		var support_color := _get_support_color()
		var pulse_support := 0.38 + sin(Time.get_ticks_msec() * 0.006) * 0.16
		for support_target in support_targets:
			if is_instance_valid(support_target):
				var support_local := to_local(support_target.global_position)
				draw_line(Vector2.ZERO, support_local, Color(support_color.r, support_color.g, support_color.b, pulse_support), 2.8)
				draw_circle(support_local, 11.0, Color(support_color.r, support_color.g, support_color.b, 0.14))
				_draw_support_target_badge(support_local, support_color)

func _draw_trickery_selection_overlay() -> void:
	var clone_color := Color(0.86, 0.55, 1.0, 1.0)

	if is_instance_valid(clone_current_target):
		var target_local := to_local(clone_current_target.global_position)
		var pulse_clone := 0.50 + sin(Time.get_ticks_msec() * 0.008) * 0.20
		draw_line(Vector2.ZERO, target_local, Color(0.78, 0.45, 1.0, pulse_clone), 3.2)
		draw_circle(target_local, 13.0, Color(0.78, 0.45, 1.0, 0.16))
		draw_arc(target_local, 16.0, 0, TAU, 36, Color(0.9, 0.72, 1.0, 0.65), 2.2)
		_draw_trickery_clone_ghost(target_local)
		_draw_clone_target_badge(target_local)

	var overlay_candidates := _get_trickery_overlay_candidates()
	var drawn := 0
	for candidate in overlay_candidates:
		if drawn >= SUPPORT_OVERLAY_MAX_TARGET_HINTS:
			break
		if not is_instance_valid(candidate):
			continue
		if candidate == clone_current_target:
			continue
		var local_pos := to_local(candidate.global_position)
		if _is_clone_recently_used(candidate):
			_draw_trickery_cooldown_indicator(local_pos, candidate)
			drawn += 1
		elif _is_valid_clone_target(candidate):
			var candidate_alpha := 0.22
			if _trickery_dragging_target:
				candidate_alpha = 0.40
				if candidate == _trickery_drag_hover_target:
					candidate_alpha = 0.72
			draw_circle(local_pos, 11.0, Color(clone_color.r, clone_color.g, clone_color.b, candidate_alpha * 0.25))
			draw_arc(local_pos, 14.0, 0, TAU, 32, Color(0.88, 0.65, 1.0, candidate_alpha), 1.6)
			if _trickery_dragging_target and candidate == _trickery_drag_hover_target:
				_draw_buff_badge(local_pos + Vector2(0, -36), "DROP", Color(0.72, 0.95, 1.0, 1.0))
			drawn += 1

	if _trickery_dragging_target:
		var drag_local := to_local(_trickery_drag_world_pos)
		draw_line(Vector2.ZERO, drag_local, Color(0.72, 0.95, 1.0, 0.78), 2.8)
		draw_circle(drag_local, 8.0, Color(0.72, 0.95, 1.0, 0.35))
		if is_instance_valid(_trickery_drag_hover_target):
			draw_line(drag_local, to_local(_trickery_drag_hover_target.global_position), Color(0.95, 0.80, 1.0, 0.58), 1.6)
	else:
		_draw_buff_badge(Vector2(0, -52), "DRAG TO LINK", Color(0.72, 0.95, 1.0, 1.0))

func _begin_trickery_drag_targeting(world_pos: Vector2) -> void:
	_trickery_dragging_target = true
	_trickery_drag_world_pos = world_pos
	_trickery_drag_hover_target = _find_clone_target_at_world(world_pos)
	queue_redraw()

func _update_trickery_drag_targeting(world_pos: Vector2) -> void:
	_trickery_drag_world_pos = world_pos
	var next_hover := _find_clone_target_at_world(world_pos)
	if next_hover != _trickery_drag_hover_target:
		_trickery_drag_hover_target = next_hover
	queue_redraw()

func _finish_trickery_drag_targeting(world_pos: Vector2) -> void:
	var target := _find_clone_target_at_world(world_pos)
	_trickery_dragging_target = false
	_trickery_drag_world_pos = world_pos
	_trickery_drag_hover_target = null
	if is_instance_valid(target):
		try_set_manual_clone_target(target)
	queue_redraw()

func _cancel_trickery_drag_targeting() -> void:
	_trickery_dragging_target = false
	_trickery_drag_hover_target = null
	queue_redraw()

func _find_clone_target_at_world(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for candidate in _get_trickery_overlay_candidates():
		if not is_instance_valid(candidate):
			continue
		if not _is_valid_clone_target(candidate):
			continue
		var dist := world_pos.distance_squared_to(candidate.global_position)
		var radius_sq := TRICKERY_DRAG_TARGET_RADIUS * TRICKERY_DRAG_TARGET_RADIUS
		if dist <= radius_sq and dist < best_dist:
			best = candidate
			best_dist = dist
	return best

func _get_trickery_overlay_candidates() -> Array:
	var candidates: Array = []
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if _is_non_cloneable_support_tower(candidate):
			continue
		if not candidate.has_method("apply_damage_modifier"):
			continue
		if global_position.distance_to(candidate.global_position) > attack_range:
			continue
		candidates.append(candidate)
	candidates.sort_custom(Callable(self, "_sort_clone_candidates"))
	return candidates

func _draw_trickery_cooldown_indicator(local_pos: Vector2, tower: Variant) -> void:
	var left := _get_clone_recent_cooldown_left(tower)
	if left <= 0.0:
		return
	var progress := 1.0 - clampf(left / max(0.1, TRICKERY_RECENT_TARGET_COOLDOWN), 0.0, 1.0)
	var center := local_pos + Vector2(0, -34)
	var r := SUPPORT_COOLDOWN_RING_RADIUS
	draw_circle(center, r + 3.0, Color(0.05, 0.04, 0.08, 0.72))
	draw_arc(center, r, 0, TAU, 28, Color(0.55, 0.45, 0.70, 0.36), 2.4)
	draw_arc(center, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 28, Color(0.90, 0.65, 1.0, 0.88), 3.0)
	draw_circle(center, 3.0, Color(0.90, 0.75, 1.0, 0.92))
	_draw_buff_badge(local_pos + Vector2(0, -60), "CD %ds" % int(ceil(left)), Color(0.78, 0.64, 1.0, 1.0))

func _update_support_overlay_z_lift() -> void:
	var should_lift := is_selected and (_is_support_aura() or _is_trickery_clone_support())
	if should_lift and not _selection_z_lift_active:
		_normal_z_index = z_index
		_normal_z_as_relative = z_as_relative
		z_as_relative = false
		z_index = SUPPORT_OVERLAY_Z_INDEX
		_selection_z_lift_active = true
	elif not should_lift and _selection_z_lift_active:
		z_index = _normal_z_index
		z_as_relative = _normal_z_as_relative
		_selection_z_lift_active = false

func _draw_support_target_badge(local_pos: Vector2, color: Color) -> void:
	var pct := int(round(support_value * 100.0))
	if pct <= 0:
		return
	var label := "+BUFF"
	if support_type == "attack_speed":
		label = "+SPD %d%%" % pct
	elif support_type == "damage":
		label = "+DMG %d%%" % pct
	_draw_buff_badge(local_pos + Vector2(0, -36), label, color)

func _draw_clone_target_badge(local_pos: Vector2) -> void:
	var pct := int(round(clone_damage_multiplier * 100.0))
	if pct <= 0:
		return
	var label := "+CLONE %d%%" % pct
	if is_instance_valid(clone_manual_target) and clone_manual_target == clone_current_target:
		label = "+CLONE %d%%" % pct
		# Separate lock dot keeps badge size identical to Well/Blacksmith badges.
		draw_circle(local_pos + Vector2(50, -30), 4.0, Color(1.0, 0.9, 1.0, 0.95))
	_draw_buff_badge(local_pos + Vector2(0, -36), label, Color(0.86, 0.55, 1.0, 1.0))

func _draw_trickery_clone_ghost(local_pos: Vector2) -> void:
	var now_ms := Time.get_ticks_msec()
	var pulse := 0.55 + sin(now_ms * 0.01) * 0.18
	# Offset the ghost away from the real tower so the player can see that the
	# clone is a separate firing projection, not just a hidden stat buff.
	var ghost_pos := local_pos + Vector2(34.0, -34.0 + sin(now_ms * 0.004) * 3.0)
	var ghost_color := Color(0.78, 0.50, 1.0, 0.34 + pulse * 0.22)
	var edge_color := Color(0.94, 0.78, 1.0, 0.72 + pulse * 0.22)
	var r := 18.0
	var points := PackedVector2Array()
	for i in range(6):
		points.append(ghost_pos + Vector2.RIGHT.rotated(PI / 6.0 + float(i) * TAU / 6.0) * r)
	var ghost_colors := PackedColorArray()
	for _i in range(points.size()):
		ghost_colors.append(ghost_color)
	draw_polygon(points, ghost_colors)
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], edge_color, 2.2)
	draw_arc(ghost_pos, r + 4.0 + pulse * 2.0, 0, TAU, 36, Color(0.88, 0.55, 1.0, 0.38), 1.5)
	draw_line(local_pos, ghost_pos, Color(0.78, 0.45, 1.0, 0.38), 1.6)
	draw_circle(ghost_pos, 5.0, Color(0.98, 0.88, 1.0, 0.78))

	# When the cloned tower fires, flash a short violet tracer from the ghost to
	# the target. This keeps the gameplay as clone-support while making the
	# "second firing point" readable during testing.
	if now_ms <= _clone_visual_fire_until_msec:
		var fire_target_local := to_local(_clone_visual_fire_target_global)
		var flash_alpha := float(_clone_visual_fire_until_msec - now_ms) / float(CLONE_FIRE_FLASH_MS)
		flash_alpha = clampf(flash_alpha, 0.0, 1.0)
		draw_line(ghost_pos, fire_target_local, Color(0.96, 0.78, 1.0, 0.85 * flash_alpha), 3.0)
		draw_circle(ghost_pos, 8.0 + (1.0 - flash_alpha) * 8.0, Color(0.95, 0.68, 1.0, 0.45 * flash_alpha))

	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, ghost_pos + Vector2(-23.0, 36.0), "CLONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.82, 1.0, 0.95))

func _draw_active_buff_badges() -> void:
	var y_offset := -44.0
	var dmg_pct := get_active_damage_bonus_percent()
	if dmg_pct > 0:
		var tag := get_active_damage_bonus_tag()
		var label := "+DMG %d%%" % dmg_pct
		var color := Color(1.0, 0.58, 0.24, 1.0)
		if tag == "clone":
			label = "+CLONE %d%%" % dmg_pct
			color = Color(0.86, 0.55, 1.0, 1.0)
		_draw_buff_badge(Vector2(0, y_offset), label, color)
		y_offset -= 17.0
	var spd_pct := get_active_fire_rate_bonus_percent()
	if spd_pct > 0:
		_draw_buff_badge(Vector2(0, y_offset), "+SPD %d%%" % spd_pct, Color(0.35, 0.85, 1.0, 1.0))

func _draw_buff_badge(local_center: Vector2, label: String, color: Color) -> void:
	if label == "":
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var rect_size := SUPPORT_BADGE_SIZE
	var rect := Rect2(local_center - rect_size * 0.5, rect_size)
	draw_rect(rect.grow(1.0), Color(color.r, color.g, color.b, 0.18), true)
	draw_rect(rect, Color(0.03, 0.05, 0.08, 0.90), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.78), false, 1.2)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, rect_size.x, BUFF_BADGE_FONT_SIZE)
	var y := rect.position.y + (rect_size.y - text_size.y) * 0.5 + text_size.y * 0.82
	draw_string(font, Vector2(rect.position.x, y), label, HORIZONTAL_ALIGNMENT_CENTER, rect_size.x, BUFF_BADGE_FONT_SIZE, Color(color.r, color.g, color.b, 1.0))

func _process_support_aura(delta: float) -> void:
	if support_value <= 0.0:
		_clear_support_targets()
		return
	_support_scan_timer -= delta
	if _support_scan_timer > 0.0:
		return
	_support_scan_timer = SUPPORT_SCAN_INTERVAL
	_refresh_support_targets()

func _refresh_support_targets() -> void:
	var candidates: Array = []
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if _is_valid_support_target(candidate):
			candidates.append(candidate)
	candidates.sort_custom(Callable(self, "_sort_support_candidates"))

	var desired: Array = []
	var limit : int = max(0, support_limit)
	for candidate in candidates:
		if desired.size() >= limit:
			break
		desired.append(candidate)

	for old_target in support_targets.duplicate():
		if not desired.has(old_target):
			_remove_support_from_tower(old_target)

	for new_target in desired:
		if not support_targets.has(new_target):
			_apply_support_to_tower(new_target)

	support_targets = desired

func _sort_support_candidates(a: Variant, b: Variant) -> bool:
	var da := INF
	var db := INF
	if is_instance_valid(a):
		da = global_position.distance_squared_to(a.global_position)
	if is_instance_valid(b):
		db = global_position.distance_squared_to(b.global_position)
	return da < db

func _is_valid_support_target(tower: Variant) -> bool:
	if tower == null or not is_instance_valid(tower):
		return false
	if tower == self:
		return false
	if _is_non_cloneable_support_tower(tower):
		return false
	if global_position.distance_to(tower.global_position) > attack_range:
		return false
	if support_type == "attack_speed":
		return tower.has_method("apply_fire_rate_modifier")
	if support_type == "damage":
		return tower.has_method("apply_damage_modifier")
	return false

func _apply_support_to_tower(tower: Variant) -> void:
	if not _is_valid_support_target(tower):
		return
	if support_type == "attack_speed" and tower.has_method("apply_fire_rate_modifier"):
		tower.apply_fire_rate_modifier(self, 1.0 + support_value, "well")
	elif support_type == "damage" and tower.has_method("apply_damage_modifier"):
		tower.apply_damage_modifier(self, 1.0 + support_value, "blacksmith")

func _remove_support_from_tower(tower: Variant) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	if support_type == "attack_speed" and tower.has_method("remove_fire_rate_modifier"):
		tower.remove_fire_rate_modifier(self)
	elif support_type == "damage" and tower.has_method("remove_damage_modifier"):
		tower.remove_damage_modifier(self)

func _clear_support_targets() -> void:
	for target in support_targets.duplicate():
		_remove_support_from_tower(target)
	support_targets.clear()

func _count_valid_support_targets() -> int:
	var count := 0
	for target in support_targets:
		if is_instance_valid(target):
			count += 1
	return count

func _is_trickery_clone_support() -> bool:
	return attack_type == "clone_support" or str(config.get("support_type", "")).to_lower() == "clone" or tower_id.begins_with("trickery_")

func _is_non_cloneable_support_tower(tower: Variant) -> bool:
	if tower == null or not is_instance_valid(tower):
		return true
	if tower == self:
		return true
	var other_attack_type := ""
	if tower.has_method("get_attack_type"):
		other_attack_type = str(tower.get_attack_type()).to_lower()
	else:
		var raw_attack_type = tower.get("attack_type")
		if raw_attack_type != null:
			other_attack_type = str(raw_attack_type).to_lower()
	var other_id := ""
	if tower.has_method("get_tower_id"):
		other_id = str(tower.get_tower_id()).to_lower()
	else:
		var raw_tower_id = tower.get("tower_id")
		if raw_tower_id != null:
			other_id = str(raw_tower_id).to_lower()
	if other_attack_type == "clone_support" or other_attack_type == "support" or other_attack_type == "support_aura":
		return true
	if other_id.begins_with("trickery") or other_id.begins_with("well") or other_id.begins_with("blacksmith"):
		return true
	return false

func _is_wave_active_for_trickery() -> bool:
	var root := get_tree().current_scene
	if root == null:
		return false
	var wave_manager := root.get_node_or_null("WaveManager")
	if wave_manager != null:
		var raw_running = wave_manager.get("is_wave_running")
		if raw_running != null:
			return bool(raw_running)
	return false

func _process_trickery_clone_support(delta: float) -> void:
	if clone_damage_multiplier <= 0.0:
		return

	# Element TD-style timing: Trickery can be linked during planning, but its
	# duration/cooldown should not be consumed while no wave is running or before
	# the cloned tower has actually started firing.
	var wave_active := _is_wave_active_for_trickery()
	if wave_active:
		_tick_clone_recent_target_cooldowns(delta)

	if is_instance_valid(clone_current_target):
		if not _is_existing_clone_target_still_valid(clone_current_target):
			var invalid_target := clone_current_target
			_remove_clone_from_current_target()
			if _clone_timer_started:
				_register_recent_clone_target(invalid_target)
		elif wave_active and _clone_timer_started:
			_clone_active_time_left -= delta
			if _clone_active_time_left <= 0.0:
				var previous_target := clone_current_target
				_remove_clone_from_current_target()
				_register_recent_clone_target(previous_target)
	else:
		clone_current_target = null
		_clone_active_time_left = 0.0
		_clone_timer_started = false

	if wave_active and clone_current_target == null:
		_clone_scan_time_left -= delta
		if _clone_scan_time_left <= 0.0:
			_clone_scan_time_left = max(0.1, clone_interval)
			if is_instance_valid(clone_manual_target) and _is_valid_clone_target(clone_manual_target):
				_assign_clone_target(clone_manual_target)
			else:
				if clone_manual_target != null and not is_instance_valid(clone_manual_target):
					clone_manual_target = null
				_assign_best_clone_target()

func _is_existing_clone_target_still_valid(tower: Variant) -> bool:
	if tower == null or not is_instance_valid(tower):
		return false
	if _is_non_cloneable_support_tower(tower):
		return false
	if not tower.has_method("apply_damage_modifier"):
		return false
	return global_position.distance_to(tower.global_position) <= attack_range

func _is_valid_clone_target(tower: Variant) -> bool:
	if not _is_existing_clone_target_still_valid(tower):
		return false
	if _is_clone_recently_used(tower):
		return false
	if _is_claimed_by_other_trickery(tower):
		return false
	if tower.has_method("get_active_damage_bonus_tag") and str(tower.get_active_damage_bonus_tag()) == "clone":
		return false
	return true

func _assign_best_clone_target() -> void:
	var candidates: Array = []
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if _is_valid_clone_target(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		return
	candidates.sort_custom(Callable(self, "_sort_clone_candidates"))
	var best: Node2D = candidates[0]
	# Prefer target variety when multiple valid non-support towers are available.
	# This avoids a Trickery tower repeatedly linking the same equally-close tower
	# while nearby towers never receive a clone.
	if candidates.size() > 1 and _clone_last_target_instance_id != 0:
		for candidate in candidates:
			if is_instance_valid(candidate) and candidate.get_instance_id() != _clone_last_target_instance_id:
				best = candidate
				break
	_assign_clone_target(best)

func _assign_clone_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not target.has_method("apply_damage_modifier"):
		return false
	if clone_current_target == target and _clone_active_time_left > 0.0:
		return true
	var previous_target := clone_current_target
	var previous_started := _clone_timer_started
	if is_instance_valid(previous_target) and previous_target != target:
		_remove_clone_from_current_target()
		if previous_started:
			_register_recent_clone_target(previous_target)
	clone_current_target = target
	_clone_active_time_left = max(0.1, clone_duration)
	_clone_timer_started = false
	_clone_last_target_instance_id = target.get_instance_id()
	target.apply_damage_modifier(self, 1.0 + clone_damage_multiplier, "clone")
	queue_redraw()
	if target.has_method("queue_redraw"):
		target.queue_redraw()
	return true

func try_set_manual_clone_target(target: Node2D) -> bool:
	if not _is_trickery_clone_support():
		return false
	if target == null or not is_instance_valid(target):
		return false
	if target == self:
		return false
	if not _is_existing_clone_target_still_valid(target):
		return false
	if _is_clone_recently_used(target):
		return false
	if _is_claimed_by_other_trickery(target) and target != clone_current_target:
		return false
	clone_manual_target = target
	_clone_scan_time_left = 0.0
	_assign_clone_target(target)
	queue_redraw()
	return true

func clear_manual_clone_target() -> void:
	clone_manual_target = null
	queue_redraw()

func _find_selected_trickery_waiting_for_target() -> Node2D:
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("try_set_manual_clone_target"):
			continue
		var selected_raw = candidate.get("is_selected")
		if selected_raw != null and bool(selected_raw):
			return candidate
	return null

func _sort_clone_candidates(a: Variant, b: Variant) -> bool:
	var da := INF
	var db := INF
	if is_instance_valid(a):
		da = global_position.distance_squared_to(a.global_position)
	if is_instance_valid(b):
		db = global_position.distance_squared_to(b.global_position)
	if not is_equal_approx(da, db):
		return da < db
	var ia := 0
	var ib := 0
	if is_instance_valid(a):
		ia = a.get_instance_id()
	if is_instance_valid(b):
		ib = b.get_instance_id()
	return ia < ib

func _tick_clone_recent_target_cooldowns(delta: float) -> void:
	if _clone_recent_target_cooldowns.is_empty():
		return
	var expired: Array = []
	for key in _clone_recent_target_cooldowns.keys():
		var left := float(_clone_recent_target_cooldowns[key]) - delta
		if left <= 0.0:
			expired.append(key)
		else:
			_clone_recent_target_cooldowns[key] = left
	for key in expired:
		_clone_recent_target_cooldowns.erase(key)

func _register_recent_clone_target(tower: Variant) -> void:
	if tower == null or not is_instance_valid(tower):
		return
	_clone_recent_target_cooldowns[tower.get_instance_id()] = TRICKERY_RECENT_TARGET_COOLDOWN

func _get_clone_recent_cooldown_left(tower: Variant) -> float:
	if tower == null or not is_instance_valid(tower):
		return 0.0
	var key : Variant = tower.get_instance_id()
	if not _clone_recent_target_cooldowns.has(key):
		return 0.0
	return max(0.0, float(_clone_recent_target_cooldowns[key]))

func _is_clone_recently_used(tower: Variant) -> bool:
	return _get_clone_recent_cooldown_left(tower) > 0.0

func _is_claimed_by_other_trickery(tower: Variant) -> bool:
	if tower == null or not is_instance_valid(tower):
		return false
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("get_clone_current_target"):
			continue
		var other_target = candidate.get_clone_current_target()
		if is_instance_valid(other_target) and other_target == tower:
			return true
	return false

func get_clone_current_target() -> Node2D:
	return clone_current_target

func notify_clone_target_fired(source_tower: Node2D, enemy_target: Node2D) -> void:
	if source_tower == null or not is_instance_valid(source_tower):
		return
	if enemy_target == null or not is_instance_valid(enemy_target):
		return
	if source_tower != clone_current_target:
		return
	# Start consuming Trickery duration only after the cloned tower actually fires.
	# This prevents the clone from expiring in planning or while enemies are out of
	# range, which felt like the support was bugged.
	_clone_timer_started = true
	_clone_visual_fire_until_msec = Time.get_ticks_msec() + CLONE_FIRE_FLASH_MS
	_clone_visual_fire_target_global = enemy_target.global_position
	queue_redraw()

func _remove_clone_from_current_target() -> void:
	if is_instance_valid(clone_current_target) and clone_current_target.has_method("remove_damage_modifier"):
		clone_current_target.remove_damage_modifier(self)
	clone_current_target = null
	_clone_active_time_left = 0.0
	_clone_timer_started = false

func _get_clone_target_name() -> String:
	if is_instance_valid(clone_current_target):
		var raw_name = clone_current_target.get("display_name")
		if raw_name != null and str(raw_name) != "":
			return str(raw_name)
		return str(clone_current_target.name)
	return ""

func _get_manual_clone_target_name() -> String:
	if is_instance_valid(clone_manual_target):
		var raw_name = clone_manual_target.get("display_name")
		if raw_name != null and str(raw_name) != "":
			return str(raw_name)
		return str(clone_manual_target.name)
	return ""

func apply_damage_modifier(source: Node, multiplier: float, tag: String = "") -> void:
	if source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	damage_modifiers[key] = {"source": source, "value": max(1.0, multiplier), "tag": tag}
	queue_redraw()

func remove_damage_modifier(source: Node) -> void:
	if source == null:
		return
	var key := source.get_instance_id()
	if damage_modifiers.has(key):
		damage_modifiers.erase(key)
		queue_redraw()

func _get_active_clone_source() -> Node2D:
	var strongest_multiplier := 1.0
	var strongest_source: Node2D = null
	for key in damage_modifiers.keys():
		var entry: Dictionary = damage_modifiers[key]
		if str(entry.get("tag", "")) != "clone":
			continue
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source) or not source is Node2D:
			continue
		var value := float(entry.get("value", 1.0))
		if value > strongest_multiplier:
			strongest_multiplier = value
			strongest_source = source as Node2D
	return strongest_source

func get_effective_damage() -> float:
	var strongest_multiplier := 1.0
	_stale_damage_keys.clear()
	for key in damage_modifiers.keys():
		var entry: Dictionary = damage_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			_stale_damage_keys.append(key)
			continue
		strongest_multiplier = max(strongest_multiplier, float(entry.get("value", 1.0)))
	for key in _stale_damage_keys:
		damage_modifiers.erase(key)
	return damage * strongest_multiplier

func get_active_damage_bonus_percent() -> int:
	var effective := get_effective_damage()
	if damage <= 0.0:
		return 0
	return max(0, int(round((effective / damage - 1.0) * 100.0)))

func get_active_damage_bonus_tag() -> String:
	var strongest_multiplier := 1.0
	var strongest_tag := ""
	for key in damage_modifiers.keys():
		var entry: Dictionary = damage_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			continue
		var value := float(entry.get("value", 1.0))
		if value > strongest_multiplier:
			strongest_multiplier = value
			strongest_tag = str(entry.get("tag", ""))
	return strongest_tag

func get_active_fire_rate_bonus_percent() -> int:
	var effective := get_effective_fire_rate()
	if fire_rate <= 0.0 or effective <= 0.0:
		return 0
	return max(0, int(round((fire_rate / effective - 1.0) * 100.0)))

func get_active_fire_rate_bonus_tag() -> String:
	var strongest_multiplier := 1.0
	var strongest_tag := ""
	for key in fire_rate_modifiers.keys():
		var entry: Dictionary = fire_rate_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			continue
		var value := float(entry.get("value", 1.0))
		if value > strongest_multiplier:
			strongest_multiplier = value
			strongest_tag = str(entry.get("tag", ""))
	return strongest_tag

func get_attack_type() -> String:
	return attack_type

func _exit_tree() -> void:
	_clear_support_targets()
	clone_manual_target = null
	_remove_clone_from_current_target()
	# Clean modifiers this tower may have applied to other towers through stale references.
	for candidate in get_tree().get_nodes_in_group("placed_towers"):
		if is_instance_valid(candidate) and candidate != self and candidate.has_method("remove_damage_modifier"):
			candidate.remove_damage_modifier(self)

func apply_fire_rate_modifier(source: Node, multiplier: float, tag: String = "") -> void:
	if source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	var value := clampf(multiplier, 0.05, 10.0)
	if not fire_rate_modifiers.has(key) or abs(float(fire_rate_modifiers[key].get("value", 1.0)) - value) > 0.001 or str(fire_rate_modifiers[key].get("tag", "")) != tag:
		fire_rate_modifiers[key] = {"source": source, "value": value, "tag": tag}
		fire_rate_modifier_changed.emit(self, source, value)
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
		queue_redraw()
		if OS.is_debug_build():
			print("[EnemyFeature][TowerDisruptionRemoved] tower=%s source=%s effective_interval=%.2f" % [tower_id, str(source.name), get_effective_fire_rate()])

func get_effective_fire_rate() -> float:
	var strongest_speed_buff := 1.0
	var strongest_slow_debuff := 1.0
	_stale_fire_rate_keys.clear()
	for key in fire_rate_modifiers.keys():
		var entry: Dictionary = fire_rate_modifiers[key]
		var source: Node = entry.get("source", null)
		if not is_instance_valid(source):
			_stale_fire_rate_keys.append(key)
			continue
		var value := clampf(float(entry.get("value", 1.0)), 0.05, 10.0)
		if value >= 1.0:
			strongest_speed_buff = max(strongest_speed_buff, value)
		else:
			strongest_slow_debuff = min(strongest_slow_debuff, value)
	for key in _stale_fire_rate_keys:
		fire_rate_modifiers.erase(key)
	var final_multiplier : float = max(0.05, strongest_speed_buff * strongest_slow_debuff)
	return fire_rate / final_multiplier

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

extends Node2D

signal clicked(tower: Node2D)

var tower_id: String
var display_name: String
var visual_type: String = "basic"
var attack_type: String = "single"
var description: String = ""
var cost: int
var damage: float
var attack_range: float
var fire_rate: float # Seconds between shots
var projectile_speed: float = 500.0
var splash_radius: float = 0.0
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var grid_cell: Vector2i

# Level tracking
var level_index: int = 0
var levels: Array = []
var config: Dictionary = {}
var is_selected: bool = false
var use_sprite: bool = false

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

# Targeting variables
var current_target: Node2D = null
var target_mode: String = "first"
var debug_draw_range: bool = false
var debug_draw_target_line: bool = false

# Shooting variables
var shoot_cooldown: float = 0.0
var projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")
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
	display_name = config.get("name", "Unknown Tower")
	visual_type = config.get("visual_type", "basic")
	attack_type = config.get("attack_type", "single")
	description = config.get("description", "")
	cost = config.get("cost", 0)
	projectile_speed = config.get("projectile_speed", 500.0)
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
		damage = data.get("damage", 10.0)
		attack_range = data.get("range", 160.0)
		fire_rate = data.get("fire_rate", 1.0)
		splash_radius = data.get("splash_radius", 0.0)
		slow_percent = data.get("slow_percent", 0.0)
		slow_duration = data.get("slow_duration", 0.0)
		_update_range_collision()
		apply_level_visuals()
		queue_redraw()

func apply_level_visuals() -> void:
	_ensure_sprite_node()
	if not is_inside_tree(): return
	
	var current_level = level_index + 1
	if level_badge:
		level_badge.text = "Lv" + str(current_level)
	
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

func _draw() -> void:
	# 1. Selection / Range Highlight
	if is_selected:
		draw_circle(Vector2.ZERO, attack_range, Color(0.1, 0.8, 1.0, 0.1))
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, Color(0.1, 0.8, 1.0, 0.4), 2.0)
	elif debug_draw_range:
		draw_circle(Vector2.ZERO, attack_range, Color(1, 1, 1, 0.05))

	if not use_sprite:
		# 2. Base Plate (Static)
		_draw_base_plate()
		
		# 3. Turret (Rotated)
		if turret_pivot:
			draw_set_transform(Vector2.ZERO, turret_pivot.rotation, Vector2.ONE)
			_draw_turret_top()
	
	# 4. Debug Target Line
	if (is_selected or debug_draw_target_line) and current_target and is_instance_valid(current_target):
		var local_target_pos = to_local(current_target.global_position)
		draw_line(Vector2.ZERO, local_target_pos, Color(1, 0, 0, 0.4), 1.5)

func _draw_base_plate() -> void:
	var lvl = level_index + 1
	var base_color = Color(0.08, 0.12, 0.18, 1.0)
	var accent_color = Color(0.2, 0.6, 1.0, 0.4)
	
	match visual_type:
		"cannon":
			base_color = Color(0.12, 0.1, 0.1, 1.0)
			accent_color = Color(1.0, 0.4, 0.1, 0.4)
		"slow":
			base_color = Color(0.1, 0.08, 0.15, 1.0)
			accent_color = Color(0.6, 0.4, 1.0, 0.4)
		"rapid":
			base_color = Color(0.08, 0.15, 0.12, 1.0)
			accent_color = Color(0.2, 1.0, 0.6, 0.4)

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
	var lvl = level_index + 1
	var main_color = Color(0.3, 0.8, 1.0, 1.0)
	var core_color = Color(0.6, 0.9, 1.0, 1.0)
	
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
			main_color = Color(1.0, 0.5, 0.2, 1.0)
			core_color = Color(1.0, 0.8, 0.6, 1.0)
			# Heavy Barrel
			draw_rect(Rect2(-6, -14, 32 + lvl * 4, 28), main_color)
			draw_rect(Rect2(-2, -10, 26 + lvl * 4, 20), Color.BLACK)
			# Plates
			draw_rect(Rect2(-14, -16, 14, 32), main_color)
			draw_rect(Rect2(-10, -12, 6, 24), core_color)
			
		"slow":
			main_color = Color(0.7, 0.5, 1.0, 1.0)
			core_color = Color(0.9, 0.8, 1.0, 1.0)
			# Shard
			var pts = PackedVector2Array([Vector2(0, -20 - lvl*2), Vector2(16, 0), Vector2(0, 20 + lvl*2), Vector2(-16, 0)])
			draw_colored_polygon(pts, main_color)
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
			# Crystal Core
			draw_rect(Rect2(-6, -6, 12, 12), core_color)
			# Aura ring
			draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r, main_color.g, main_color.b, 0.2), 2.0)
			
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
	return level_index + 1 < levels.size()

func get_upgrade_cost() -> int:
	var data = get_current_level_data()
	return data.get("upgrade_cost", 0)

func upgrade() -> bool:
	if can_upgrade():
		level_index += 1
		apply_level_stats()
		play_upgrade_effect()
		return true
	return false

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
	return {
		"id": tower_id,
		"name": display_name,
		"level": level_index + 1,
		"max_level": levels.size(),
		"damage": damage,
		"range": attack_range,
		"fire_rate": fire_rate,
		"upgrade_cost": get_upgrade_cost(),
		"can_upgrade": can_upgrade(),
		"attack_type": attack_type,
		"splash_radius": splash_radius,
		"slow_percent": slow_percent,
		"slow_duration": slow_duration,
		"target_mode": target_mode
	}

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
	if game_manager != null and game_manager.is_paused:
		return
		
	update_target()
	
	# Smooth visual rotation
	if turret_pivot:
		if is_valid_target(current_target):
			var direction = current_target.global_position - global_position
			var desired_angle = direction.angle() + deg_to_rad(turret_angle_offset_degrees)
			turret_pivot.rotation = lerp_angle(turret_pivot.rotation, desired_angle, min(1.0, aim_turn_speed * delta))
		else:
			# Idle rotation (could return to default or just stay)
			pass

	if shoot_cooldown > 0:
		shoot_cooldown -= delta
	
	if is_valid_target(current_target) and shoot_cooldown <= 0:
		shoot()
		shoot_cooldown = fire_rate
	
	queue_redraw()

func shoot() -> void:
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		var container = projectile_container if projectile_container else get_tree().current_scene
		container.add_child(projectile)
		
		# Use muzzle position if available, else tower center
		var spawn_pos = muzzle.global_position if muzzle else global_position
		projectile.global_position = spawn_pos
		
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
			
		projectile.setup(current_target, int(damage), projectile_speed, attack_type, splash_radius, slow_percent, slow_duration)
		projectile.scale = Vector2(proj_scale, proj_scale)
		projectile.modulate = proj_color
		
		if audio_manager:
			audio_manager.play_sfx(sfx_name)

func update_target() -> void:
	current_target = find_target()

func is_valid_target(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy): return false
	if not enemy.has_method("is_alive") or not enemy.is_alive(): return false
	
	# Use local distance to ensure consistency with scaled MapRoot
	var local_dist = to_local(enemy.global_position).length()
	return local_dist <= attack_range

func find_target() -> Node2D:
	var enemies = get_enemies_in_range()
	if enemies.is_empty(): return null
	
	match target_mode:
		"first":
			return select_first_target(enemies)
		"last":
			return select_last_target(enemies)
		"nearest":
			return select_nearest_target(enemies)
		"strongest":
			return select_strongest_target(enemies)
		"weakest":
			return select_weakest_target(enemies)
		_:
			return select_first_target(enemies)

func get_enemies_in_range() -> Array:
	var enemies_in_range = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_valid_target(enemy):
			enemies_in_range.append(enemy)
	return enemies_in_range

func select_first_target(enemies: Array) -> Node2D:
	var best_target = null
	var max_progress = -1.0
	for enemy in enemies:
		if enemy.has_method("get_path_progress"):
			var prog = enemy.get_path_progress()
			if prog > max_progress:
				max_progress = prog
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
	for enemy in enemies:
		var dist = to_local(enemy.global_position).length()
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

func set_target_mode(mode: String) -> void:
	var supported = ["first", "last", "nearest", "strongest", "weakest"]
	if mode in supported:
		target_mode = mode
		current_target = null
		update_target()
		queue_redraw()

func get_target_mode() -> String:
	return target_mode

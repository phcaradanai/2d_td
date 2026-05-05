extends PathFollow2D

signal died(enemy, reward_gold)
signal reached_base(enemy, damage, global_pos)

var hp: float = 30.0
var max_hp: float = 30.0
var base_speed: float = 100.0
var speed: float = 100.0
var reward_gold: int = 5
var base_damage: int = 1
var enemy_type: String = "basic"
var visual_type: String = "basic"
var display_name: String = "Enemy"

var is_active: bool = false
var reached_base_flag: bool = false
var is_dead_flag: bool = false

# Slow effect status
var active_slow_percent: float = 0.0
var slow_remaining: float = 0.0

@onready var body: ColorRect = $Body
@onready var hp_bar: ProgressBar = $HpBar
@onready var damage_number_scene: PackedScene = preload("res://scenes/effects/DamageNumber.tscn")
@onready var death_pop_scene: PackedScene = preload("res://scenes/effects/DeathPopEffect.tscn")
@onready var game_manager := get_tree().current_scene.get_node_or_null("GameManager")

func setup(config: Dictionary) -> void:
	enemy_type = config.get("id", config.get("enemy_type", "basic"))
	display_name = config.get("name", "Enemy")
	visual_type = config.get("visual_type", "basic")
	
	max_hp = config.get("max_hp", config.get("hp", 30.0))
	hp = max_hp
	base_speed = config.get("speed", 100.0)
	speed = base_speed
	reward_gold = config.get("reward_gold", 5)
	base_damage = config.get("base_damage", 1)
	
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	
	apply_visuals()
	is_active = true

var is_flashing: bool = false

func apply_visuals() -> void:
	if not is_inside_tree(): return
	if body: body.visible = false
	queue_redraw()

func _draw() -> void:
	var color = Color(0.8, 0.2, 0.2, 1.0)
	var size = 16.0
	
	match visual_type:
		"basic":
			color = Color(0.8, 0.2, 0.2, 1.0)
			_draw_drone_hexagon(color, size)
		"fast":
			color = Color(1.0, 0.8, 0.2, 1.0)
			_draw_drone_triangle(color, size * 0.7)
		"tank":
			color = Color(0.5, 0.1, 0.1, 1.0)
			_draw_drone_tank(color, size * 1.4)
			
	if is_flashing:
		# Draw white overlay
		_draw_overlay(Color(1, 1, 1, 0.6))

func _draw_drone_hexagon(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(6):
		var a : float = i * PI/3
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
	# Eye
	draw_circle(Vector2(size * 0.4, 0), 3, Color.WHITE)

func _draw_drone_triangle(color: Color, size: float) -> void:
	var pts := PackedVector2Array([Vector2(size * 1.2, 0), Vector2(-size, -size), Vector2(-size, size)])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
	# Glowing core
	draw_circle(Vector2(0, 0), 4, Color.WHITE)

func _draw_drone_tank(color: Color, size: float) -> void:
	var pts := PackedVector2Array()
	for i in range(8):
		var a : float = i * PI/4
		pts.append(Vector2(cos(a), sin(a)) * size)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5)
	# Reinforced plates
	draw_rect(Rect2(-size*0.6, -size*0.6, size*1.2, size*1.2), Color(1, 1, 1, 0.1), false, 1.0)

func _draw_overlay(color: Color) -> void:
	# Simplified overlay for flash
	draw_circle(Vector2.ZERO, 20, color)

func _ready() -> void:
	add_to_group("enemies")
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	apply_visuals()

func _process(delta: float) -> void:
	if game_manager != null and game_manager.is_paused:
		return
		
	if not is_active or is_dead_flag or reached_base_flag:
		return
		
	# Update slow timer
	if slow_remaining > 0:
		slow_remaining -= delta
		if slow_remaining <= 0:
			clear_slow()
		
	progress += speed * delta
	
	if progress_ratio >= 1.0:
		reach_base()

func apply_slow(percent: float, duration: float) -> void:
	# Stronger slow overrides weaker slow, or refreshes if same/stronger
	if percent >= active_slow_percent:
		active_slow_percent = percent
		slow_remaining = duration
		update_effective_speed()
		update_visual_feedback()
	elif duration > slow_remaining and percent == active_slow_percent:
		# Refresh duration if same strength but longer duration
		slow_remaining = duration

func clear_slow() -> void:
	active_slow_percent = 0.0
	slow_remaining = 0.0
	update_effective_speed()
	update_visual_feedback()

func update_effective_speed() -> void:
	var slow_factor = 1.0 - active_slow_percent
	# Clamp minimum speed to 25% of base_speed
	slow_factor = max(slow_factor, 0.25)
	speed = base_speed * slow_factor

func update_visual_feedback() -> void:
	if body:
		if active_slow_percent > 0:
			# Tint body slightly cyan/blue
			body.modulate = Color(0.5, 0.8, 1.0, 1.0)
		else:
			# Restore normal modulate
			body.modulate = Color(1, 1, 1, 1)

func get_hit_origin() -> Vector2:
	return global_position

func get_aim_point() -> Vector2:
	# STANDARD: Point for towers to aim at
	return global_position

func take_damage(amount: float, hit_global: Vector2 = Vector2.ZERO) -> void:
	if is_dead_flag or reached_base_flag:
		return
		
	# STANDARD: Use hit origin if no specific global point provided
	var capture_pos = hit_global if hit_global != Vector2.ZERO else get_hit_origin()
	
	hp -= amount
	if hp_bar:
		hp_bar.value = hp
		
	flash_body()
	spawn_damage_number(int(amount), capture_pos)
	
	if hp <= 0:
		die(capture_pos)

func flash_body() -> void:
	is_flashing = true
	queue_redraw()
	await get_tree().create_timer(0.08).timeout
	is_flashing = false
	queue_redraw()

func spawn_damage_number(amount: int, hit_global: Vector2) -> void:
	if damage_number_scene:
		var dn = damage_number_scene.instantiate()
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(dn)
			# MUST set global_position AFTER add_child
			dn.global_position = hit_global + Vector2(0, -20)
			dn.setup(amount)
		else:
			get_tree().current_scene.add_child(dn)
			dn.global_position = hit_global + Vector2(0, -20)
			dn.setup(amount)

func die(death_global: Vector2 = Vector2.ZERO) -> void:
	if is_dead_flag: return
	is_dead_flag = true
	is_active = false
	
	var capture_pos = death_global if death_global != Vector2.ZERO else global_position
	
	spawn_death_effect(capture_pos)
	
	died.emit(self, reward_gold)
	queue_free()

func spawn_death_effect(death_global: Vector2) -> void:
	if death_pop_scene:
		var effect = death_pop_scene.instantiate()
		# STANDARD: Use map-aligned effects container
		var effects_container = get_tree().current_scene.get_node_or_null("WorldRoot/MapRoot/EffectsContainer")
		if effects_container:
			effects_container.add_child(effect)
			# MUST set global_position AFTER add_child
			effect.global_position = death_global
			
			if OS.is_debug_build():
				if OS.is_debug_build(): print("[Enemy] Death effect spawned at global=", effect.global_position, " death_global=", death_global)
		else:
			get_tree().current_scene.add_child(effect)
			effect.global_position = death_global

func reach_base() -> void:
	if reached_base_flag: return
	reached_base_flag = true
	is_active = false
	var leak_global = global_position
	reached_base.emit(self, base_damage, leak_global)
	queue_free()

func is_alive() -> bool:
	return hp > 0 and not reached_base_flag and not is_dead_flag

func get_path_progress() -> float:
	return progress

func get_current_hp() -> float:
	return hp

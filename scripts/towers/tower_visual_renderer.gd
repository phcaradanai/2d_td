extends RefCounted
class_name TowerVisualRenderer

# Centralized procedural tower drawing.
# Keep visual-only shape changes here so tower.gd stays focused on gameplay.
# Godot 4.6.2 friendly: uses only CanvasItem draw_* calls, no extra nodes per tower.

const TOWER_CONTOUR_PX := 1.6
const TOWER_CONTOUR_COLOR := Color(0.0, 0.0, 0.0, 0.78)


static func draw_base_plate(t: Node2D) -> void:
	var lvl = t.tree_tier
	var base_color = Color(0.06, 0.08, 0.12, 1.0)
	var el_colors : Array[Color] = t._get_all_element_colors()
	var accent_color: Color

	# Tint base background slightly toward primary element
	if not el_colors.is_empty():
		accent_color = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.55)
		base_color = base_color.lerp(el_colors[0], 0.08)
	else:
		accent_color = Color(0.35, 0.55, 0.7, 0.35)

	# Main Base Rect
	_draw_contour_rect(t, Rect2(-24, -24, 48, 48))
	t.draw_rect(Rect2(-24, -24, 48, 48), base_color)

	# Element-colored border segments
	# Each element gets an equal portion of the border perimeter
	var border_w := 1.5 if lvl < 3 else 2.0
	if el_colors.is_empty():
		# Neutral: single muted border
		t.draw_rect(Rect2(-24, -24, 48, 48), accent_color, false, border_w)
	elif el_colors.size() == 1:
		# Single element: full border in element color
		var c := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.7)
		t.draw_rect(Rect2(-24, -24, 48, 48), c, false, border_w)
	elif el_colors.size() == 2:
		# Dual element: top+right = element1, bottom+left = element2
		var c0 := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.75)
		var c1 := Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.75)
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c0, border_w)    # right
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c1, border_w)    # bottom
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c1, border_w)  # left
	else:
		# Triple+ element: distribute segments around the border
		var c0 := Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.75)
		var c1 := Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.75)
		var c2 := Color(el_colors[2].r, el_colors[2].g, el_colors[2].b, 0.75)
		t.draw_line(Vector2(-24, -24), Vector2(24, -24), c0, border_w)  # top = el1
		t.draw_line(Vector2(24, -24), Vector2(24, 24), c1, border_w)    # right = el2
		t.draw_line(Vector2(24, 24), Vector2(-24, 24), c2, border_w)    # bottom = el3
		# left side: blend of el1+el3
		var c_left := c0.lerp(c2, 0.5)
		t.draw_line(Vector2(-24, 24), Vector2(-24, -24), c_left, border_w)

	# Corner Ticks — colored per element
	var s = 6.0
	var p = 22.0
	var tick_color := accent_color if el_colors.is_empty() else Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.6)
	var tick_color2 := tick_color
	if el_colors.size() >= 2:
		tick_color2 = Color(el_colors[1].r, el_colors[1].g, el_colors[1].b, 0.6)
	# Top-left & top-right: primary element
	t.draw_line(Vector2(-p, -p), Vector2(-p+s, -p), tick_color)
	t.draw_line(Vector2(-p, -p), Vector2(-p, -p+s), tick_color)
	t.draw_line(Vector2(p, -p), Vector2(p-s, -p), tick_color)
	t.draw_line(Vector2(p, -p), Vector2(p, -p+s), tick_color)
	# Bottom-left & bottom-right: secondary element (or same)
	t.draw_line(Vector2(-p, p), Vector2(-p+s, p), tick_color2)
	t.draw_line(Vector2(-p, p), Vector2(-p, p-s), tick_color2)
	t.draw_line(Vector2(p, p), Vector2(p-s, p), tick_color2)
	t.draw_line(Vector2(p, p), Vector2(p, p-s), tick_color2)

	# Level Details — tier 2+ inner rect tinted toward element
	if lvl >= 2:
		var inner_tint := Color(accent_color.r, accent_color.g, accent_color.b, 0.12)
		if not el_colors.is_empty():
			inner_tint = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.12)
		t.draw_rect(Rect2(-18, -18, 36, 36), inner_tint)
	if lvl >= 3:
		var ring_color := accent_color
		if not el_colors.is_empty():
			ring_color = Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.35)
		t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, ring_color, 1.5)


static func _draw_contour_rect(t: Node2D, rect: Rect2) -> void:
	t.draw_rect(rect.grow(TOWER_CONTOUR_PX), TOWER_CONTOUR_COLOR)


static func _draw_contour_circle(t: Node2D, center: Vector2, radius: float) -> void:
	t.draw_circle(center, radius + TOWER_CONTOUR_PX, TOWER_CONTOUR_COLOR)


static func _draw_contour_line(t: Node2D, from: Vector2, to: Vector2, width: float) -> void:
	t.draw_line(from, to, TOWER_CONTOUR_COLOR, width + TOWER_CONTOUR_PX * 2.0, true)


static func _draw_contour_poly(t: Node2D, points: PackedVector2Array) -> void:
	t.draw_colored_polygon(_expand_poly_from_center(t, points, TOWER_CONTOUR_PX), TOWER_CONTOUR_COLOR)


static func _expand_poly_from_center(t: Node2D, points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points:
		var dir := point.normalized()
		out.append(point + dir * amount)
	return out


static func draw_turret_contour(t: Node2D) -> void:
	var lvl = t.tree_tier
	var size = 20.0
	match t.visual_type:
		"basic":
			_draw_contour_rect(t, Rect2(0, -6, 26 + lvl * 4, 12))
			_draw_contour_circle(t, Vector2.ZERO, 15)
		"rapid":
			_draw_contour_rect(t, Rect2(-8, -12, 36 + lvl * 3, 24))
			_draw_contour_rect(t, Rect2(-14, -10, 10, 20))
			_draw_contour_rect(t, Rect2(28 + lvl * 3, -10, 10, 20))
			_draw_contour_rect(t, Rect2(2, -5, 20 + lvl * 2, 10))
		"cannon":
			_draw_contour_rect(t, Rect2(-6, -14, 32 + lvl * 4, 28))
			_draw_contour_rect(t, Rect2(-14, -16, 14, 32))
		"slow":
			_draw_contour_poly(t, PackedVector2Array([Vector2(0, -20 - lvl * 2), Vector2(16, 0), Vector2(0, 20 + lvl * 2), Vector2(-16, 0)]))
		"sniper":
			_draw_contour_rect(t, Rect2(0, -4, 40 + lvl * 6, 8))
			_draw_contour_rect(t, Rect2(36 + lvl * 6, -5, 6, 10))
			_draw_contour_poly(t, PackedVector2Array([Vector2(-18, -12), Vector2(12, -8), Vector2(12, 8), Vector2(-18, 12)]))
		"lightning":
			match t._get_tower_visual_family():
				"jinx":
					_draw_contour_poly(t, PackedVector2Array([Vector2(-14,-18),Vector2(8,-18),Vector2(18,-8),Vector2(10,0),Vector2(18,8),Vector2(8,18),Vector2(-14,18),Vector2(-4,0)]))
					_draw_contour_circle(t, Vector2.ZERO, 8)
				"periodic":
					_draw_contour_circle(t, Vector2.ZERO, 19)
					for i in range(6):
						var a = i * TAU / 6.0
						_draw_contour_circle(t, Vector2(cos(a), sin(a)) * 18, 3.5)
				_:
					_draw_contour_circle(t, Vector2.ZERO, 16)
					for i in range(4):
						var a = i * PI / 2 + (t.idle_rotation * 0.3)
						var tip := Vector2(cos(a), sin(a)) * 24
						_draw_contour_line(t, Vector2.ZERO, tip, 3.0)
						_draw_contour_circle(t, tip, 4)
		"trickery":
			_draw_contour_poly(t, PackedVector2Array([Vector2(0, -22), Vector2(18, -4), Vector2(10, 18), Vector2(-10, 18), Vector2(-18, -4)]))
		"sawblade":
			var blade_size = size + lvl * 2.0
			var teeth = 12
			var pts := PackedVector2Array()
			for i in range(teeth * 2):
				var angle = (float(i) / (teeth * 2)) * TAU + t.idle_rotation
				var r = blade_size * (1.0 if i % 2 == 0 else 0.7)
				pts.append(Vector2.RIGHT.rotated(angle) * r)
			_draw_contour_poly(t, pts)
		"prism_lens":
			match t._get_tower_visual_family():
				"ice":
					_draw_contour_poly(t, PackedVector2Array([Vector2(0,-24),Vector2(12,-8),Vector2(8,16),Vector2(0,22),Vector2(-8,16),Vector2(-12,-8)]))
					_draw_contour_line(t, Vector2(-18, -4), Vector2(18, 4), 3.0)
					_draw_contour_line(t, Vector2(-14, 10), Vector2(14, -10), 3.0)
				"polar":
					_draw_contour_circle(t, Vector2.ZERO, 18)
					_draw_contour_poly(t, PackedVector2Array([Vector2(-18,-10),Vector2(10,-16),Vector2(22,0),Vector2(10,16),Vector2(-18,10),Vector2(-8,0)]))
					_draw_contour_circle(t, Vector2(20, 0), 5)
				_:
					_draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(14,-8),Vector2(18,6),Vector2(0,14),Vector2(-18,6),Vector2(-14,-8)]))
					_draw_contour_rect(t, Rect2(0,-4,32+lvl*4,8))
					_draw_contour_rect(t, Rect2(28+lvl*4,-6,8,12))
		"void_orb":
			_draw_contour_circle(t, Vector2.ZERO, 20)
		"crystal_emitter":
			_draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(8,12),Vector2(0,18),Vector2(-8,12),Vector2(-10,-8)]))
		"furnace":
			_draw_contour_rect(t, Rect2(-16,-16,32,32))
			_draw_contour_rect(t, Rect2(0,-7,28+lvl*3,14))
			_draw_contour_rect(t, Rect2(20+lvl*3,-9,10,18))
		"bio_vine":
			_draw_contour_poly(t, PackedVector2Array([Vector2(-14,-16),Vector2(16,0),Vector2(-14,16),Vector2(-8,0)]))
			_draw_contour_rect(t, Rect2(4,-12,22+lvl*2,6))
			_draw_contour_rect(t, Rect2(4,6,22+lvl*2,6))
		"stone_bastion":
			_draw_contour_rect(t, Rect2(-20,-20,40,40))
			_draw_contour_rect(t, Rect2(0,-10,26+lvl*3,20))
			_draw_contour_rect(t, Rect2(-20,-8,8,16))
		"forge_anvil":
			_draw_contour_poly(t, PackedVector2Array([Vector2(-20,8),Vector2(20,8),Vector2(16,0),Vector2(8,-4),Vector2(8,-16),Vector2(-8,-16),Vector2(-8,-4),Vector2(-16,0)]))
			_draw_contour_circle(t, Vector2.ZERO, 8)
			_draw_contour_rect(t, Rect2(8,-5,20+lvl*2,10))
		"support_halo":
			match t._get_tower_visual_family():
				"life":
					_draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(20,0),Vector2(10,8),Vector2(0,22),Vector2(-10,8),Vector2(-20,0),Vector2(-10,-8)]))
					_draw_contour_circle(t, Vector2.ZERO, 8)
				"well":
					_draw_contour_rect(t, Rect2(-18,-10,36,20))
					_draw_contour_circle(t, Vector2.ZERO, 16)
				"tidal":
					_draw_contour_circle(t, Vector2.ZERO, 19)
					_draw_contour_poly(t, PackedVector2Array([Vector2(-18,8),Vector2(-6,-8),Vector2(8,-14),Vector2(20,-4),Vector2(8,8),Vector2(-6,14)]))
				"enchantment":
					_draw_contour_poly(t, PackedVector2Array([Vector2(0,-22),Vector2(19,-11),Vector2(19,11),Vector2(0,22),Vector2(-19,11),Vector2(-19,-11)]))
					_draw_contour_circle(t, Vector2.ZERO, 9)
				_:
					_draw_contour_rect(t, Rect2(-10,-10,20,20))
					_draw_contour_circle(t, Vector2.ZERO, 20)
		"particle_accel":
			_draw_contour_circle(t, Vector2.ZERO, 18)
			_draw_contour_rect(t, Rect2(0,-2,38+lvl*5,4))
		"chaos_orb":
			_draw_contour_circle(t, Vector2.ZERO, 12)
		"toxin_vial":
			_draw_contour_poly(t, PackedVector2Array([Vector2(-8,-18),Vector2(8,-18),Vector2(10,-8),Vector2(12,12),Vector2(-12,12),Vector2(-10,-8)]))
			_draw_contour_rect(t, Rect2(-3,-24,6,8))
		"spore_cap":
			if t._get_tower_visual_family() == "disease":
				_draw_contour_poly(t, PackedVector2Array([Vector2(-16,-14),Vector2(0,-22),Vector2(16,-14),Vector2(14,10),Vector2(0,20),Vector2(-14,10)]))
				for i in range(4):
					var a = i * TAU / 4.0 + PI / 4.0
					_draw_contour_line(t, Vector2(cos(a), sin(a)) * 12, Vector2(cos(a), sin(a)) * 21, 2.0)
			else:
				_draw_contour_rect(t, Rect2(-6,0,12,16))
				_draw_contour_poly(t, PackedVector2Array([Vector2(-20,0),Vector2(-14,-12),Vector2(-6,-20),Vector2(0,-22),Vector2(6,-20),Vector2(14,-12),Vector2(20,0)]))
		"heavy_mortar":
			_draw_contour_rect(t, Rect2(-14,-18,28,36))
			_draw_contour_rect(t, Rect2(0,-12,28+lvl*2,24))
			_draw_contour_circle(t, Vector2(26+lvl*2,0), 10)
		"steam_boiler":
			_draw_contour_rect(t, Rect2(-16,-14,32,28))
			_draw_contour_rect(t, Rect2(0,-6,24+lvl*2,12))
		"hydro_cannon":
			_draw_contour_rect(t, Rect2(-18,-12,36,24))
			_draw_contour_rect(t, Rect2(0,-9,30+lvl*3,18))
			_draw_contour_circle(t, Vector2(28+lvl*3,0), 7)
		"ember_bloom":
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * 0.3
				_draw_contour_poly(t, PackedVector2Array([Vector2.ZERO, Vector2(cos(a-0.4),sin(a-0.4))*16, Vector2(cos(a),sin(a))*22, Vector2(cos(a+0.4),sin(a+0.4))*16]))
			_draw_contour_circle(t, Vector2.ZERO, 10)
		"tar_pool":
			_draw_contour_rect(t, Rect2(-18,-8,36,16))
			_draw_contour_circle(t, Vector2.ZERO, 16)
		"voodoo_totem":
			_draw_contour_rect(t, Rect2(-8,-22,16,44))
			_draw_contour_rect(t, Rect2(-10,-26,20,16))
		"dual_nozzle":
			_draw_contour_rect(t, Rect2(-16,-18,32,36))
			_draw_contour_rect(t, Rect2(0,-14,30+lvl*2,10))
			_draw_contour_rect(t, Rect2(0,4,30+lvl*2,10))
			_draw_contour_rect(t, Rect2(-20,-16,6,32))
		"root_cage":
			_draw_contour_circle(t, Vector2.ZERO, 10)
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * 0.2
				_draw_contour_line(t, Vector2.ZERO, Vector2(cos(a),sin(a)) * 22, 3.0)
		"tri_reactor":
			_draw_contour_circle(t, Vector2.ZERO, 20)
			_draw_contour_rect(t, Rect2(0,-3,30+lvl*4,6))
			for i in range(3):
				var a = t.idle_rotation * 0.6 + i * TAU/3.0
				_draw_contour_circle(t, Vector2(cos(a),sin(a)) * 14, 5)
		"strike_blades":
			_draw_contour_poly(t, PackedVector2Array([Vector2(-14,-14),Vector2(18,-6),Vector2(24,0),Vector2(18,6),Vector2(-14,14),Vector2(-6,0)]))
			_draw_contour_poly(t, PackedVector2Array([Vector2(-2,-6),Vector2(10,-6),Vector2(14,-14),Vector2(2,-16)]))
			_draw_contour_poly(t, PackedVector2Array([Vector2(-2,6),Vector2(10,6),Vector2(14,14),Vector2(2,16)]))
		"golem_body":
			_draw_contour_rect(t, Rect2(-18,-18,36,36))
			_draw_contour_rect(t, Rect2(0,-12,24+lvl*2,24))
		"seismic_drill":
			_draw_contour_rect(t, Rect2(-14,-12,24,24))
			_draw_contour_poly(t, PackedVector2Array([Vector2(0,-8),Vector2(30+lvl*3,0),Vector2(0,8)]))
			_draw_contour_circle(t, Vector2(28+lvl*3,0), 5)
		"solar_bloom":
			for i in range(6):
				var a = i * TAU/6.0 + t.idle_rotation * 0.2
				_draw_contour_poly(t, PackedVector2Array([Vector2(cos(a-0.35),sin(a-0.35))*6, Vector2(cos(a),sin(a))*20, Vector2(cos(a+0.35),sin(a+0.35))*6]))
			_draw_contour_circle(t, Vector2.ZERO, 10)
		"gold_refinery":
			_draw_contour_rect(t, Rect2(-12,0,24,12))
			_draw_contour_rect(t, Rect2(-10,-4,20,8))
			_draw_contour_rect(t, Rect2(-8,-18,16,20))
			_draw_contour_rect(t, Rect2(0,-4,24+lvl*2,8))
		"acid_vat":
			_draw_contour_rect(t, Rect2(-14,-10,28,20))
			_draw_contour_rect(t, Rect2(0,-6,22+lvl*2,12))
			_draw_contour_circle(t, Vector2(20+lvl*2,0), 4)
		"void_vortex":
			_draw_contour_circle(t, Vector2.ZERO, 20)
		"hail_crystal":
			for i in range(6):
				var a = i * TAU/6.0 + t.idle_rotation * 0.1
				_draw_contour_line(t, Vector2.ZERO, Vector2(cos(a),sin(a))*20, 2.0)
			_draw_contour_circle(t, Vector2.ZERO, 6)
		"rail_laser":
			_draw_contour_rect(t, Rect2(-18,-14,32,28))
			_draw_contour_rect(t, Rect2(0,-5,44+lvl*5,10))
			_draw_contour_circle(t, Vector2(42+lvl*5,0), 4)
		"void_flower":
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * -0.2
				_draw_contour_poly(t, PackedVector2Array([Vector2(cos(a-0.3),sin(a-0.3))*6, Vector2(cos(a),sin(a))*18, Vector2(cos(a+0.3),sin(a+0.3))*6]))
			_draw_contour_circle(t, Vector2.ZERO, 10)
		"storm_turbine":
			_draw_contour_circle(t, Vector2.ZERO, 18)
			for i in range(4):
				var a = i * TAU/4.0 + t.idle_rotation * 1.2
				_draw_contour_poly(t, PackedVector2Array([Vector2(cos(a)*4,sin(a)*4), Vector2(cos(a+0.4)*16,sin(a+0.4)*16), Vector2(cos(a+0.6)*18,sin(a+0.6)*18), Vector2(cos(a+0.15)*4,sin(a+0.15)*4)]))


static func draw_element_core(t: Node2D) -> void:
	# Draw small element-colored dots in the center of the turret as a visual landmark.
	# 1 element → 1 dot, 2 → 2 dots side-by-side, 3 → triangle of 3 dots.
	var el_colors : Array[Color] = t._get_all_element_colors()
	if el_colors.is_empty():
		return

	var core_r := 3.5  # radius of each core dot
	var glow_r := 5.5  # outer glow ring

	if el_colors.size() == 1:
		# Single element: one bright core
		t.draw_circle(Vector2.ZERO, glow_r, Color(el_colors[0].r, el_colors[0].g, el_colors[0].b, 0.35))
		t.draw_circle(Vector2.ZERO, core_r, el_colors[0])
		t.draw_circle(Vector2.ZERO, 1.5, el_colors[0].lightened(0.6))
	elif el_colors.size() == 2:
		# Dual element: two dots side by side
		var offset_x := 4.5
		for i in range(2):
			var pos := Vector2(-offset_x + i * offset_x * 2, 0)
			t.draw_circle(pos, glow_r - 1.0, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 0.5, el_colors[i])
			t.draw_circle(pos, 1.2, el_colors[i].lightened(0.55))
	else:
		# Triple element: three dots in triangle formation
		var tri_r := 5.0  # distance from center to each dot
		for i in range(mini(el_colors.size(), 3)):
			var angle := -PI / 2.0 + i * TAU / 3.0  # start from top
			var pos := Vector2(cos(angle), sin(angle)) * tri_r
			t.draw_circle(pos, glow_r - 1.5, Color(el_colors[i].r, el_colors[i].g, el_colors[i].b, 0.3))
			t.draw_circle(pos, core_r - 1.0, el_colors[i])
			t.draw_circle(pos, 1.0, el_colors[i].lightened(0.5))


static func draw_turret_top(t: Node2D) -> void:
	var lvl = t.tree_tier
	var el_colors : Array[Color] = t._get_all_element_colors()
	# Determine main_color and secondary accent from elements
	var main_color: Color
	var secondary_color: Color
	var core_color: Color
	if not el_colors.is_empty():
		main_color = el_colors[0]
		secondary_color = el_colors[1] if el_colors.size() >= 2 else el_colors[0].lightened(0.3)
		core_color = main_color.lightened(0.45)
	else:
		# Neutral towers: muted gray-cyan
		main_color = Color(0.45, 0.55, 0.6, 1.0)
		secondary_color = Color(0.55, 0.65, 0.7, 1.0)
		core_color = Color(0.7, 0.8, 0.85, 1.0)
	var size = 20.0

	match t.visual_type:
		# ===== EXISTING VISUAL TYPES (Preserved) =====
		"basic":
			# Neutral Arrow Tower — precision starter, thin rail-arrow barrel
			t.draw_rect(Rect2(0, -6, 26 + lvl * 4, 12), main_color)
			t.draw_rect(Rect2(2, -4, 22 + lvl * 4, 8), Color(0, 0, 0, 0.5))
			t.draw_circle(Vector2.ZERO, 15, main_color)
			t.draw_circle(Vector2.ZERO, 10, Color.BLACK)
			if el_colors.is_empty():
				t.draw_circle(Vector2.ZERO, 6, core_color)
			else:
				draw_element_core(t)

		"rapid":
			# Neutral Cannon Tower — heavy starter, short thick barrel
			var plate_color := secondary_color if el_colors.size() >= 2 else core_color
			# Heavy base
			t.draw_rect(Rect2(-8, -12, 36 + lvl * 3, 24), main_color)
			t.draw_rect(Rect2(-4, -8, 30 + lvl * 3, 16), Color.BLACK)
			# Impact plates on sides
			t.draw_rect(Rect2(-14, -10, 10, 20), plate_color)
			t.draw_rect(Rect2(28 + lvl * 3, -10, 10, 20), plate_color)
			# Short thick barrel
			t.draw_rect(Rect2(2, -5, 20 + lvl * 2, 10), main_color)
			draw_element_core(t)

		"cannon":
			# Heavy cannon — splash damage (LEGACY - used by fire/earth towers currently)
			var plate_color := secondary_color if el_colors.size() >= 2 else core_color
			t.draw_rect(Rect2(-6, -14, 32 + lvl * 4, 28), main_color)
			t.draw_rect(Rect2(-2, -10, 26 + lvl * 4, 20), Color.BLACK)
			t.draw_rect(Rect2(-14, -16, 14, 32), main_color)
			t.draw_rect(Rect2(-10, -12, 6, 24), plate_color)
			draw_element_core(t)

		"slow":
			# Diamond shard — slow/freeze (LEGACY - used by water towers currently)
			var outline_color := Color.WHITE
			if el_colors.size() >= 2:
				outline_color = secondary_color.lightened(0.3)
			var pts = PackedVector2Array([Vector2(0, -20 - lvl * 2), Vector2(16, 0), Vector2(0, 20 + lvl * 2), Vector2(-16, 0)])
			t.draw_colored_polygon(pts, main_color)
			t.draw_polyline(pts + PackedVector2Array([pts[0]]), outline_color, 1.5)
			# Aura ring
			t.draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r, main_color.g, main_color.b, 0.2), 2.0)
			draw_element_core(t)

		"sniper":
			# Long rifle — precision single-target (LEGACY - used by light towers currently)
			var barrel_accent := secondary_color if el_colors.size() >= 2 else main_color
			t.draw_rect(Rect2(0, -4, 40 + lvl * 6, 8), main_color)
			# Muzzle cap in secondary color
			t.draw_rect(Rect2(36 + lvl * 6, -5, 6, 10), barrel_accent.darkened(0.5))
			# Sleek body
			var pts = PackedVector2Array([Vector2(-18, -12), Vector2(12, -8), Vector2(12, 8), Vector2(-18, 12)])
			t.draw_colored_polygon(pts, main_color)
			t.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.6), 1.0)
			draw_element_core(t)

		"lightning":
			# Electricity / Jinx / Periodic — shared chain-like VFX, distinct silhouettes.
			var spike_tip_color := secondary_color if el_colors.size() >= 2 else core_color
			match t._get_tower_visual_family():
				"jinx":
					var jinx_pts = PackedVector2Array([Vector2(-14,-18),Vector2(8,-18),Vector2(18,-8),Vector2(10,0),Vector2(18,8),Vector2(8,18),Vector2(-14,18),Vector2(-4,0)])
					t.draw_colored_polygon(jinx_pts, Color(main_color.r, main_color.g, main_color.b, 0.55))
					t.draw_polyline(jinx_pts + PackedVector2Array([jinx_pts[0]]), secondary_color.lightened(0.25), 1.4)
					t.draw_circle(Vector2.ZERO, 8, Color(0.05,0.0,0.08,1.0))
					for i in range(3):
						var a = -PI / 4.0 + i * PI / 4.0
						t.draw_line(Vector2(2, 0), Vector2(cos(a), sin(a)) * 18, spike_tip_color, 1.5)
				"periodic":
					t.draw_arc(Vector2.ZERO, 19, 0, TAU, 36, Color(main_color.r,main_color.g,main_color.b,0.6), 2.0)
					for i in range(6):
						var a = i * TAU / 6.0
						var node_color = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
						t.draw_circle(Vector2(cos(a), sin(a)) * 18, 3.5, node_color)
					t.draw_circle(Vector2.ZERO, 9, Color(0.92,0.96,1.0,0.85))
				_:
					t.draw_circle(Vector2.ZERO, 16, main_color)
					t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, main_color.lightened(0.4), 1.5)
					for i in range(4):
						var a = i * PI / 2 + (t.idle_rotation * 0.3)
						t.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 24, main_color, 3.0)
						t.draw_circle(Vector2(cos(a), sin(a)) * 24, 4, spike_tip_color)
					for i in range(2):
						var crackle_pts = PackedVector2Array()
						var start_a = randf() * TAU
						var dist = randf_range(18, 30)
						crackle_pts.append(Vector2.RIGHT.rotated(start_a) * 12)
						crackle_pts.append(Vector2.RIGHT.rotated(start_a + 0.2) * dist)
						crackle_pts.append(Vector2.RIGHT.rotated(start_a - 0.2) * (dist + 5))
						t.draw_polyline(crackle_pts, core_color, 1.0)
			draw_element_core(t)

		"trickery":
			# Hologram prism — support/clone tower (Light + Darkness)
			var prism_fill := main_color if not el_colors.is_empty() else Color(0.72, 0.42, 1.0)
			var prism_edge := secondary_color.lightened(0.35) if el_colors.size() >= 2 else Color(0.95, 0.82, 1.0)
			var prism = PackedVector2Array([Vector2(0, -22), Vector2(18, -4), Vector2(10, 18), Vector2(-10, 18), Vector2(-18, -4)])
			t.draw_colored_polygon(prism, Color(prism_fill.r, prism_fill.g, prism_fill.b, 0.55))
			t.draw_polyline(prism + PackedVector2Array([prism[0]]), prism_edge, 1.5)
			# Inner dark circle + pulsing core
			t.draw_circle(Vector2.ZERO, 8, Color(0.12, 0.04, 0.2, 0.9))
			draw_element_core(t)
			# Rotating rays
			for i in range(3):
				var a = t.idle_rotation * 0.7 + i * TAU / 3.0
				var ray_color := prism_edge
				if el_colors.size() >= 2:
					ray_color = el_colors[i % el_colors.size()].lightened(0.2)
				t.draw_line(Vector2.RIGHT.rotated(a) * 12, Vector2.RIGHT.rotated(a) * 22, Color(ray_color.r, ray_color.g, ray_color.b, 0.65), 1.5)

		"sawblade":
			# Rotating saw — aura damage (LEGACY - used by darkness towers currently)
			var blade_size = size + lvl * 2.0
			# Hub
			t.draw_circle(Vector2.ZERO, blade_size * 0.7, Color(0.25, 0.25, 0.25))
			# Saw blade teeth in primary element color
			var blade_color := main_color
			var teeth = 12
			var pts = []
			for i in range(teeth * 2):
				var angle = (float(i) / (teeth * 2)) * TAU + t.idle_rotation
				var r = blade_size * (1.0 if i % 2 == 0 else 0.7)
				pts.append(Vector2.RIGHT.rotated(angle) * r)
			t.draw_colored_polygon(PackedVector2Array(pts), blade_color)
			# Center hub with secondary accent
			var hub_color := secondary_color.darkened(0.2) if el_colors.size() >= 2 else Color(0.45, 0.45, 0.45)
			t.draw_circle(Vector2.ZERO, blade_size * 0.3, hub_color)
			draw_element_core(t)

		"prism_lens":
			# Light / Ice / Polar share lens attacks but keep different silhouettes.
			match t._get_tower_visual_family():
				"ice":
					var ice_pts = PackedVector2Array([Vector2(0,-24),Vector2(12,-8),Vector2(8,16),Vector2(0,22),Vector2(-8,16),Vector2(-12,-8)])
					t.draw_colored_polygon(ice_pts, Color(main_color.r,main_color.g,main_color.b,0.52))
					t.draw_polyline(ice_pts + PackedVector2Array([ice_pts[0]]), Color(0.82,0.96,1.0,0.9), 1.4)
					t.draw_line(Vector2(-18,-4), Vector2(18,4), secondary_color.lightened(0.25), 2.0)
					t.draw_line(Vector2(-14,10), Vector2(14,-10), Color(0.88,0.98,1.0,0.65), 1.5)
				"polar":
					t.draw_arc(Vector2.ZERO, 18, -PI * 0.72, PI * 0.72, 32, main_color, 3.0)
					var polar_pts = PackedVector2Array([Vector2(-18,-10),Vector2(10,-16),Vector2(22,0),Vector2(10,16),Vector2(-18,10),Vector2(-8,0)])
					t.draw_colored_polygon(polar_pts, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.42))
					t.draw_polyline(polar_pts + PackedVector2Array([polar_pts[0]]), main_color.lightened(0.25), 1.4)
					t.draw_circle(Vector2(20,0), 4, Color(0.9,0.98,1.0,0.9))
				_:
					var prism_pts = PackedVector2Array([Vector2(0,-22),Vector2(14,-8),Vector2(18,6),Vector2(0,14),Vector2(-18,6),Vector2(-14,-8)])
					t.draw_colored_polygon(prism_pts, Color(main_color.r,main_color.g,main_color.b,0.45))
					t.draw_polyline(prism_pts + PackedVector2Array([prism_pts[0]]), main_color.lightened(0.35), 1.5)
					t.draw_rect(Rect2(0,-4,32+lvl*4,8), main_color.darkened(0.35))
					t.draw_rect(Rect2(28+lvl*4,-6,8,12), main_color)
					t.draw_circle(Vector2(32+lvl*4,0), 5, Color.BLACK)
					t.draw_circle(Vector2(32+lvl*4,0), 3, main_color.lightened(0.5))
					t.draw_circle(Vector2.ZERO, 10, Color(main_color.r,main_color.g,main_color.b,0.25))
			draw_element_core(t)

		"void_orb":
			# Darkness — void orb with shadow rings and inward particles
			t.draw_circle(Vector2.ZERO, 20, Color(main_color.r,main_color.g,main_color.b,0.12))
			t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.5), 2.0)
			t.draw_arc(Vector2.ZERO, 12, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.4), 1.5)
			t.draw_circle(Vector2.ZERO, 9, Color(0.04,0.0,0.1,1.0))
			for i in range(6):
				var a = i * TAU/6.0 + t.idle_rotation * 0.4
				t.draw_line(Vector2(cos(a),sin(a))*16, Vector2(cos(a),sin(a))*11, Color(main_color.r,main_color.g,main_color.b,0.7), 1.5)
			draw_element_core(t)

		"crystal_emitter":
			# Water — blue crystal with ripple rings
			t.draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.18), 1.5)
			t.draw_arc(Vector2.ZERO, 15, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.3), 1.5)
			var cx_pts = PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(8,12),Vector2(0,18),Vector2(-8,12),Vector2(-10,-8)])
			t.draw_colored_polygon(cx_pts, Color(main_color.r,main_color.g,main_color.b,0.55))
			t.draw_polyline(cx_pts + PackedVector2Array([cx_pts[0]]), Color(0.7,0.95,1.0,0.9), 1.5)
			t.draw_line(Vector2(0,-22), Vector2(0,18), Color(1.0,1.0,1.0,0.18), 1.0)
			draw_element_core(t)

		"furnace":
			# Fire — furnace body with plasma nozzle
			t.draw_rect(Rect2(-16,-16,32,32), main_color.darkened(0.5))
			t.draw_rect(Rect2(-12,-12,24,24), Color(0.08,0.02,0.0,1.0))
			for i in range(3):
				t.draw_rect(Rect2(-14,-10+i*8,6,4), Color(1.0,0.3,0.0,0.8))
			t.draw_rect(Rect2(0,-7,28+lvl*3,14), main_color)
			t.draw_rect(Rect2(20+lvl*3,-9,10,18), main_color.darkened(0.3))
			t.draw_circle(Vector2(24+lvl*3,0), 6, Color(1.0,0.6,0.1,0.85))
			draw_element_core(t)

		"bio_vine":
			# Nature — organic vine-wrapped twin barrel turret
			var bv_pts = PackedVector2Array([Vector2(-14,-16),Vector2(16,0),Vector2(-14,16),Vector2(-8,0)])
			t.draw_colored_polygon(bv_pts, main_color.darkened(0.3))
			t.draw_polyline(bv_pts + PackedVector2Array([bv_pts[0]]), main_color, 1.5)
			t.draw_rect(Rect2(4,-12,22+lvl*2,6), main_color.darkened(0.2))
			t.draw_rect(Rect2(4,6,22+lvl*2,6), main_color.darkened(0.2))
			for i in range(3):
				t.draw_line(Vector2(6+i*7,-12), Vector2(9+i*7,6), Color(main_color.r,main_color.g,main_color.b,0.55), 1.0)
			var leaf_c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			t.draw_circle(Vector2(24+lvl*2,-9), 4, leaf_c)
			t.draw_circle(Vector2(24+lvl*2,9), 4, leaf_c)
			draw_element_core(t)

		"stone_bastion":
			# Earth — heavy armored block with amber reactor
			t.draw_rect(Rect2(-20,-20,40,40), main_color.darkened(0.4))
			t.draw_rect(Rect2(-14,-14,28,28), Color(0.06,0.04,0.02,1.0))
			t.draw_line(Vector2(-20,-20), Vector2(-14,-14), main_color.lightened(0.2), 1.0)
			t.draw_line(Vector2(20,-20), Vector2(14,-14), main_color.lightened(0.2), 1.0)
			t.draw_line(Vector2(-20,20), Vector2(-14,14), main_color.lightened(0.2), 1.0)
			t.draw_line(Vector2(20,20), Vector2(14,14), main_color.lightened(0.2), 1.0)
			t.draw_rect(Rect2(0,-10,26+lvl*3,20), main_color)
			t.draw_rect(Rect2(18+lvl*3,-12,10,24), main_color.darkened(0.3))
			t.draw_rect(Rect2(-20,-8,8,16), main_color.darkened(0.2))
			draw_element_core(t)

		"forge_anvil":
			# Blacksmith (Fire+Earth) — forge anvil silhouette
			var fa_pts = PackedVector2Array([Vector2(-20,8),Vector2(20,8),Vector2(16,0),Vector2(8,-4),Vector2(8,-16),Vector2(-8,-16),Vector2(-8,-4),Vector2(-16,0)])
			t.draw_colored_polygon(fa_pts, main_color.darkened(0.3))
			t.draw_polyline(fa_pts + PackedVector2Array([fa_pts[0]]), main_color, 1.5)
			t.draw_circle(Vector2.ZERO, 8, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.7))
			t.draw_rect(Rect2(8,-5,20+lvl*2,10), main_color.lightened(0.2))
			for i in range(4):
				var a = t.idle_rotation * 1.5 + i * TAU/4.0
				t.draw_circle(Vector2(cos(a),sin(a))*(10+randf()*5), 1.5, Color(1.0,0.82,0.2,0.85))
			draw_element_core(t)

		"support_halo":
			var h2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			# Support families share aura behavior, but not the same silhouette.
			match t._get_tower_visual_family():
				"life":
					var life_pts = PackedVector2Array([Vector2(0,-22),Vector2(10,-8),Vector2(20,0),Vector2(10,8),Vector2(0,22),Vector2(-10,8),Vector2(-20,0),Vector2(-10,-8)])
					t.draw_colored_polygon(life_pts, Color(main_color.r,main_color.g,main_color.b,0.48))
					t.draw_polyline(life_pts + PackedVector2Array([life_pts[0]]), h2c.lightened(0.25), 1.4)
					t.draw_circle(Vector2.ZERO, 8, Color(h2c.r,h2c.g,h2c.b,0.7))
				"well":
					t.draw_rect(Rect2(-18,-10,36,20), main_color.darkened(0.35))
					t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(h2c.r,h2c.g,h2c.b,0.75), 2.0)
					t.draw_arc(Vector2.ZERO, 10, 0, TAU, 32, Color(0.82,0.96,1.0,0.5), 1.5)
				"tidal":
					t.draw_arc(Vector2.ZERO, 19, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.55), 2.0)
					var wave_pts = PackedVector2Array([Vector2(-18,8),Vector2(-6,-8),Vector2(8,-14),Vector2(20,-4),Vector2(8,8),Vector2(-6,14)])
					t.draw_colored_polygon(wave_pts, Color(h2c.r,h2c.g,h2c.b,0.55))
					t.draw_polyline(wave_pts + PackedVector2Array([wave_pts[0]]), Color(0.9,0.98,1.0,0.7), 1.2)
				"enchantment":
					var hex_pts = PackedVector2Array([Vector2(0,-22),Vector2(19,-11),Vector2(19,11),Vector2(0,22),Vector2(-19,11),Vector2(-19,-11)])
					t.draw_colored_polygon(hex_pts, Color(main_color.r,main_color.g,main_color.b,0.28))
					t.draw_polyline(hex_pts + PackedVector2Array([hex_pts[0]]), h2c.lightened(0.35), 1.5)
					t.draw_circle(Vector2.ZERO, 9, Color(main_color.r,main_color.g,main_color.b,0.7))
				_:
					t.draw_rect(Rect2(-10,-10,20,20), main_color.darkened(0.4))
					t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.65), 2.0)
					t.draw_arc(Vector2.ZERO, 14, 0, TAU, 32, Color(h2c.r,h2c.g,h2c.b,0.4), 1.5)
					for i in range(4):
						var a = t.idle_rotation * 0.5 + i * TAU/4.0
						t.draw_circle(Vector2(cos(a),sin(a))*20, 3, main_color.lightened(0.35))
			draw_element_core(t)

		"particle_accel":
			# Quark (Light+Earth) — particle accelerator ring
			t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, main_color, 3.0)
			t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, secondary_color if el_colors.size() >= 2 else core_color, 1.5)
			t.draw_rect(Rect2(0,-2,38+lvl*5,4), main_color.lightened(0.2))
			t.draw_circle(Vector2(36+lvl*5,0), 3, core_color)
			for i in range(3):
				var a = t.idle_rotation * 1.2 + i * TAU/3.0
				t.draw_circle(Vector2(cos(a),sin(a))*18, 2, core_color)
			draw_element_core(t)

		"chaos_orb":
			# Magic (Darkness+Fire) — arcane flame sigil
			for i in range(6):
				var a1 = i * TAU/6.0
				var a2 = (i+2) * TAU/6.0
				t.draw_line(Vector2(cos(a1),sin(a1))*16, Vector2(cos(a2),sin(a2))*16, Color(main_color.r,main_color.g,main_color.b,0.65), 1.0)
			t.draw_circle(Vector2.ZERO, 12, Color(0.05,0.0,0.08,1.0))
			t.draw_circle(Vector2.ZERO, 8, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
			for i in range(3):
				var a = t.idle_rotation * 0.8 + i * TAU/3.0
				t.draw_line(Vector2.RIGHT.rotated(a)*8, Vector2.RIGHT.rotated(a+0.35)*16, Color(1.0,0.4,0.0,0.6), 1.5)
			draw_element_core(t)

		"toxin_vial":
			# Poison (Darkness+Water) — toxin vial emitter
			var tv_pts = PackedVector2Array([Vector2(-8,-18),Vector2(8,-18),Vector2(10,-8),Vector2(12,12),Vector2(-12,12),Vector2(-10,-8)])
			t.draw_colored_polygon(tv_pts, Color(main_color.r,main_color.g,main_color.b,0.4))
			t.draw_polyline(tv_pts + PackedVector2Array([tv_pts[0]]), main_color.lightened(0.2), 1.5)
			var bubble_c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			t.draw_circle(Vector2(-3,4), 3, bubble_c)
			t.draw_circle(Vector2(4,0), 2, bubble_c)
			t.draw_rect(Rect2(-3,-24,6,8), main_color)
			t.draw_circle(Vector2(0,-22), 2, Color(main_color.r,main_color.g,main_color.b,0.8))
			draw_element_core(t)

		"spore_cap":
			if t._get_tower_visual_family() == "disease":
				var disease_pts = PackedVector2Array([Vector2(-16,-14),Vector2(0,-22),Vector2(16,-14),Vector2(14,10),Vector2(0,20),Vector2(-14,10)])
				t.draw_colored_polygon(disease_pts, Color(main_color.r,main_color.g,main_color.b,0.42))
				t.draw_polyline(disease_pts + PackedVector2Array([disease_pts[0]]), secondary_color.lightened(0.25), 1.4)
				for i in range(4):
					var a = i * TAU / 4.0 + PI / 4.0
					t.draw_line(Vector2(cos(a),sin(a))*12, Vector2(cos(a),sin(a))*21, main_color.lightened(0.2), 1.8)
				t.draw_circle(Vector2.ZERO, 7, Color(0.05,0.08,0.02,1.0))
			else:
				t.draw_rect(Rect2(-6,0,12,16), main_color.darkened(0.3))
				var sc_pts = PackedVector2Array([Vector2(-20,0),Vector2(-14,-12),Vector2(-6,-20),Vector2(0,-22),Vector2(6,-20),Vector2(14,-12),Vector2(20,0)])
				t.draw_colored_polygon(sc_pts, main_color)
				t.draw_polyline(sc_pts, secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3), 1.5)
				for i in range(3):
					var a = -PI/2.0 + (i-1)*0.5
					t.draw_circle(Vector2(cos(a),sin(a))*14, 2, Color(1.0,1.0,0.8,0.8))
			draw_element_core(t)

		"heavy_mortar":
			# Gunpowder (Darkness+Earth) — wide mortar tube
			t.draw_rect(Rect2(-14,-18,28,36), main_color.darkened(0.4))
			t.draw_rect(Rect2(-10,-14,20,28), Color(0.05,0.04,0.04,1.0))
			t.draw_line(Vector2(-14,-18), Vector2(0,-12), main_color.lightened(0.2), 2.0)
			t.draw_line(Vector2(-14,18), Vector2(0,12), main_color.lightened(0.2), 2.0)
			t.draw_rect(Rect2(0,-12,28+lvl*2,24), main_color)
			t.draw_circle(Vector2(26+lvl*2,0), 10, Color(0.07,0.05,0.05,1.0))
			t.draw_circle(Vector2(26+lvl*2,0), 6, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.8))
			draw_element_core(t)

		"steam_boiler":
			# Vapor (Water+Fire) — steam boiler with vents
			t.draw_rect(Rect2(-16,-14,32,28), main_color.darkened(0.3))
			t.draw_rect(Rect2(-12,-10,24,20), Color(0.04,0.06,0.08,1.0))
			var vc = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			for i in range(3):
				t.draw_rect(Rect2(-10+i*8,-18,4,6), vc)
				t.draw_circle(Vector2(-8+i*8,-20), 3, Color(0.88,0.9,1.0,0.65))
			t.draw_rect(Rect2(0,-6,24+lvl*2,12), main_color.lightened(0.2))
			t.draw_circle(Vector2(-8,0), 5, Color(0.3,0.3,0.3,1.0))
			t.draw_arc(Vector2(-8,0), 3, -PI*0.8, -PI*0.8 + PI * (0.5 + 0.5 * sin(t.idle_rotation * 0.5)), 8, Color(1.0,0.6,0.0,0.9), 2.0)
			draw_element_core(t)

		"hydro_cannon":
			# Hydro (Water+Earth) — water cannon on stone base
			var hc_stone = secondary_color if el_colors.size() >= 2 else main_color.darkened(0.4)
			t.draw_rect(Rect2(-18,-12,36,24), hc_stone.darkened(0.4))
			t.draw_rect(Rect2(-14,-8,28,16), Color(0.05,0.07,0.05,1.0))
			t.draw_rect(Rect2(0,-9,30+lvl*3,18), main_color)
			t.draw_rect(Rect2(22+lvl*3,-10,10,20), main_color.darkened(0.3))
			t.draw_circle(Vector2(28+lvl*3,0), 7, Color(main_color.r,main_color.g,main_color.b,0.9))
			t.draw_circle(Vector2(28+lvl*3,0), 3, Color(0.85,0.97,1.0,1.0))
			draw_element_core(t)

		"ember_bloom":
			# Flame (Fire+Nature) — wildfire bio-core with ember leaves
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * 0.3
				var ep_pts = PackedVector2Array([Vector2.ZERO, Vector2(cos(a-0.4),sin(a-0.4))*16, Vector2(cos(a),sin(a))*22, Vector2(cos(a+0.4),sin(a+0.4))*16])
				t.draw_colored_polygon(ep_pts, Color(main_color.r,main_color.g,main_color.b,0.5))
			t.draw_circle(Vector2.ZERO, 10, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.85))
			t.draw_circle(Vector2.ZERO, 6, Color(1.0,0.92,0.3,0.9))
			draw_element_core(t)

		"tar_pool":
			# Muck (Darkness+Water+Earth) — tar/sludge pool emitter
			t.draw_rect(Rect2(-18,-8,36,16), main_color.darkened(0.5))
			t.draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.6), 3.0)
			t.draw_circle(Vector2.ZERO, 12, Color(0.04,0.03,0.07,0.9))
			t.draw_rect(Rect2(0,-5,18+lvl*2,10), Color(0.18,0.14,0.22,1.0))
			var b2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
			t.draw_circle(Vector2(-4,2), 2, Color(b2c.r,b2c.g,b2c.b,0.6))
			t.draw_circle(Vector2(5,-3), 2, Color(b2c.r,b2c.g,b2c.b,0.5))
			draw_element_core(t)

		"voodoo_totem":
			# Voodoo (Darkness+Fire+Nature) — cursed totem pole
			t.draw_rect(Rect2(-8,-22,16,44), main_color.darkened(0.3))
			t.draw_rect(Rect2(-10,-26,20,16), main_color.darkened(0.2))
			t.draw_circle(Vector2(-5,-20), 3, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
			t.draw_circle(Vector2(5,-20), 3, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.9))
			var vtc3 = el_colors[2] if el_colors.size() >= 3 else main_color
			t.draw_arc(Vector2.ZERO, 14, 0, TAU, 6, Color(vtc3.r,vtc3.g,vtc3.b,0.7), 1.5)
			for i in range(2):
				var bx = 12 * (1 if i == 0 else -1)
				t.draw_line(Vector2(0,-10), Vector2(bx,-18), main_color.lightened(0.3), 2.0)
				t.draw_circle(Vector2(bx,-18), 3, Color(1.0,1.0,0.8,0.7))
			draw_element_core(t)

		"dual_nozzle":
			# Flamethrower (Darkness+Fire+Earth) — heavy dual nozzle
			t.draw_rect(Rect2(-16,-18,32,36), main_color.darkened(0.5))
			t.draw_rect(Rect2(-10,-12,20,24), Color(0.04,0.02,0.02,1.0))
			var dn_barrel = secondary_color.darkened(0.2) if el_colors.size() >= 2 else main_color
			t.draw_rect(Rect2(0,-14,30+lvl*2,10), dn_barrel)
			t.draw_rect(Rect2(0,4,30+lvl*2,10), dn_barrel)
			t.draw_circle(Vector2(28+lvl*2,-9), 5, Color(1.0,0.4,0.0,0.9))
			t.draw_circle(Vector2(28+lvl*2,9), 5, Color(1.0,0.4,0.0,0.9))
			var dn_fuel = el_colors[2] if el_colors.size() >= 3 else main_color
			t.draw_rect(Rect2(-20,-16,6,32), Color(dn_fuel.r,dn_fuel.g,dn_fuel.b,0.8))
			draw_element_core(t)

		"root_cage":
			# Roots (Darkness+Nature+Earth) — thorn/root cage
			t.draw_circle(Vector2.ZERO, 10, Color(0.04,0.07,0.02,1.0))
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * 0.2
				var rend = Vector2(cos(a),sin(a)) * 22
				t.draw_line(Vector2.ZERO, rend, main_color.darkened(0.1), 3.0)
				t.draw_line(Vector2.ZERO, rend, Color(secondary_color.r,secondary_color.g,secondary_color.b,0.45), 1.0)
				var thorn_dir = Vector2(cos(a+PI/2.0),sin(a+PI/2.0))
				var thorn_base = rend - Vector2(cos(a),sin(a))*5
				var rc3 = el_colors[2] if el_colors.size() >= 3 else main_color
				t.draw_line(thorn_base, thorn_base + thorn_dir*5, Color(rc3.r,rc3.g,rc3.b,0.8), 1.5)
			draw_element_core(t)

		"tri_reactor":
			# Impulse (Water+Fire+Nature) — unstable tri-core reactor
			t.draw_arc(Vector2.ZERO, 20, 0, TAU, 32, Color(main_color.r,main_color.g,main_color.b,0.4), 3.0)
			for i in range(3):
				var a = t.idle_rotation * 0.6 + i * TAU/3.0
				var tp = Vector2(cos(a),sin(a)) * 14
				var tec = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
				t.draw_circle(tp, 5, tec)
				t.draw_circle(tp, 2.5, tec.lightened(0.5))
			t.draw_rect(Rect2(0,-3,30+lvl*4,6), Color(0.8,0.8,0.8,0.7))
			draw_element_core(t)

		"strike_blades":
			# Zealot (Water+Fire+Earth) — aggressive blade striker
			var sb_pts = PackedVector2Array([Vector2(-14,-14),Vector2(18,-6),Vector2(24,0),Vector2(18,6),Vector2(-14,14),Vector2(-6,0)])
			t.draw_colored_polygon(sb_pts, main_color.darkened(0.2))
			t.draw_polyline(sb_pts + PackedVector2Array([sb_pts[0]]), main_color.lightened(0.2), 1.5)
			var w2c = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
			t.draw_colored_polygon(PackedVector2Array([Vector2(-2,-6),Vector2(10,-6),Vector2(14,-14),Vector2(2,-16)]), w2c)
			t.draw_colored_polygon(PackedVector2Array([Vector2(-2,6),Vector2(10,6),Vector2(14,14),Vector2(2,16)]), w2c)
			draw_element_core(t)

		"golem_body":
			# Flesh Golem (Water+Nature+Earth) — bulky organic golem
			t.draw_rect(Rect2(-18,-18,36,36), main_color.darkened(0.3))
			t.draw_rect(Rect2(-12,-12,24,24), Color(0.04,0.08,0.05,1.0))
			var gl_vein = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
			t.draw_line(Vector2(-12,-12), Vector2(0,0), Color(gl_vein.r,gl_vein.g,gl_vein.b,0.5), 1.0)
			t.draw_line(Vector2(-12,12), Vector2(0,0), Color(gl_vein.r,gl_vein.g,gl_vein.b,0.5), 1.0)
			t.draw_rect(Rect2(0,-12,24+lvl*2,24), main_color)
			var gl_pulse = el_colors[1] if el_colors.size() >= 2 else main_color
			t.draw_circle(Vector2(-4,0), 8, Color(gl_pulse.r,gl_pulse.g,gl_pulse.b,0.4))
			draw_element_core(t)

		"seismic_drill":
			# Quaker (Fire+Nature+Earth) — seismic drill head
			t.draw_rect(Rect2(-14,-12,24,24), main_color.darkened(0.3))
			var sd_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.2)
			for i in range(3):
				t.draw_line(Vector2(-8+i*8,-12), Vector2(-8+i*8,12), Color(sd_sec.r,sd_sec.g,sd_sec.b,0.6), 2.0)
			t.draw_colored_polygon(PackedVector2Array([Vector2(0,-8),Vector2(30+lvl*3,0),Vector2(0,8)]), main_color.lightened(0.2))
			var sd3 = el_colors[2] if el_colors.size() >= 3 else main_color
			t.draw_circle(Vector2(28+lvl*3,0), 5, Color(sd3.r,sd3.g,sd3.b,0.8))
			draw_element_core(t)

		"solar_bloom":
			# Nova (Light+Fire+Nature) — solar flower reactor
			for i in range(6):
				var a = i * TAU/6.0 + t.idle_rotation * 0.2
				var sol_c = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
				t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a-0.35),sin(a-0.35))*6, Vector2(cos(a),sin(a))*20, Vector2(cos(a+0.35),sin(a+0.35))*6]), Color(sol_c.r,sol_c.g,sol_c.b,0.6))
			t.draw_circle(Vector2.ZERO, 10, Color(1.0,0.9,0.3,0.9))
			t.draw_circle(Vector2.ZERO, 6, Color(1.0,1.0,0.85,1.0))
			draw_element_core(t)

		"gold_refinery":
			# Gold (Light+Fire+Earth) — midas gold refinery
			t.draw_rect(Rect2(-12,0,24,12), Color(0.82,0.68,0.1,1.0))
			t.draw_rect(Rect2(-10,-4,20,8), Color(1.0,0.85,0.22,1.0))
			t.draw_rect(Rect2(-8,-18,16,20), main_color.darkened(0.2))
			t.draw_rect(Rect2(-6,-16,12,16), Color(0.1,0.08,0.02,1.0))
			t.draw_rect(Rect2(0,-4,24+lvl*2,8), Color(1.0,0.85,0.1,1.0))
			for i in range(4):
				var a = t.idle_rotation * 0.8 + i * TAU/4.0
				t.draw_circle(Vector2(cos(a),sin(a))*14, 2, Color(1.0,0.9,0.22,0.9))
			draw_element_core(t)

		"acid_vat":
			# Corrosion (Darkness+Water+Fire) — acid reactor
			t.draw_rect(Rect2(-14,-10,28,20), main_color.darkened(0.4))
			t.draw_rect(Rect2(-10,-6,20,16), Color(0.04,0.06,0.03,1.0))
			var av_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			t.draw_arc(Vector2(0,4), 9, 0, TAU, 32, Color(av_sec.r,av_sec.g,av_sec.b,0.7), 2.0)
			t.draw_rect(Rect2(0,-6,22+lvl*2,12), main_color.lightened(0.2))
			t.draw_circle(Vector2(20+lvl*2,0), 4, Color(0.3,1.0,0.1,0.8))
			t.draw_line(Vector2(-8,8), Vector2(-6,14), Color(0.4,1.0,0.2,0.6), 1.5)
			t.draw_circle(Vector2(-6,15), 2, Color(0.4,1.0,0.2,0.5))
			draw_element_core(t)

		"void_vortex":
			# Drowning (Darkness+Water+Nature) — abyssal vortex
			var vv_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.3)
			for i in range(4):
				var r = 20 - i * 4
				var col = main_color.lerp(vv_sec, float(i)/3.0)
				var arc_start = t.idle_rotation * (0.4 + i * 0.1)
				t.draw_arc(Vector2.ZERO, r, arc_start, arc_start + TAU * 0.8, 24, Color(col.r,col.g,col.b,0.4+i*0.08), 2.0 - i * 0.3)
			t.draw_circle(Vector2.ZERO, 8, Color(0.02,0.0,0.05,1.0))
			t.draw_circle(Vector2.ZERO, 4, Color(0.1,0.05,0.15,1.0))
			draw_element_core(t)

		"hail_crystal":
			# Hail (Light+Darkness+Water) — storm ice crystal snowflake
			for i in range(6):
				var a = i * TAU/6.0 + t.idle_rotation * 0.1
				t.draw_line(Vector2.ZERO, Vector2(cos(a),sin(a))*20, main_color, 2.0)
				var mid = Vector2(cos(a),sin(a)) * 12
				t.draw_line(mid, mid + Vector2(cos(a+PI/3.0),sin(a+PI/3.0))*6, main_color.lightened(0.3), 1.0)
				t.draw_line(mid, mid + Vector2(cos(a-PI/3.0),sin(a-PI/3.0))*6, main_color.lightened(0.3), 1.0)
			var hc_sec = secondary_color if el_colors.size() >= 2 else main_color.darkened(0.3)
			t.draw_circle(Vector2.ZERO, 6, Color(hc_sec.r,hc_sec.g,hc_sec.b,0.6))
			t.draw_circle(Vector2.ZERO, 3, Color(0.9,0.95,1.0,0.9))
			draw_element_core(t)

		"rail_laser":
			# Laser (Light+Darkness+Earth) — heavy rail-laser cannon
			t.draw_rect(Rect2(-18,-14,32,28), main_color.darkened(0.4))
			t.draw_rect(Rect2(-12,-10,20,20), Color(0.05,0.03,0.08,1.0))
			t.draw_rect(Rect2(0,-5,44+lvl*5,10), main_color)
			for i in range(3):
				t.draw_rect(Rect2(6+i*12,-7,4,14), main_color.lightened(0.3))
			var rl_sec = secondary_color if el_colors.size() >= 2 else main_color.lightened(0.4)
			t.draw_circle(Vector2(42+lvl*5,0), 4, Color(rl_sec.r,rl_sec.g,rl_sec.b,0.8))
			t.draw_circle(Vector2(42+lvl*5,0), 2, Color(1.0,1.0,1.0,0.9))
			draw_element_core(t)

		"void_flower":
			# Oblivion (Light+Darkness+Nature) — collapsing star/void flower
			for i in range(5):
				var a = i * TAU/5.0 + t.idle_rotation * -0.2
				var pf_col = main_color if i % 2 == 0 else secondary_color
				t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a-0.3),sin(a-0.3))*6, Vector2(cos(a),sin(a))*18, Vector2(cos(a+0.3),sin(a+0.3))*6]), Color(pf_col.r,pf_col.g,pf_col.b,0.55))
			t.draw_circle(Vector2.ZERO, 10, Color(0.04,0.0,0.1,1.0))
			t.draw_circle(Vector2.ZERO, 6, main_color.darkened(0.2))
			t.draw_circle(Vector2.ZERO, 3, Color(1.0,1.0,1.0,0.6))
			draw_element_core(t)

		"storm_turbine":
			# Windstorm (Light+Water+Fire) — storm turbine with rotating blades
			t.draw_circle(Vector2.ZERO, 18, Color(main_color.r,main_color.g,main_color.b,0.18))
			t.draw_arc(Vector2.ZERO, 18, 0, TAU, 32, main_color, 2.0)
			for i in range(4):
				var a = i * TAU/4.0 + t.idle_rotation * 1.2
				var st_c = el_colors[i % el_colors.size()] if not el_colors.is_empty() else main_color
				t.draw_colored_polygon(PackedVector2Array([Vector2(cos(a)*4,sin(a)*4), Vector2(cos(a+0.4)*16,sin(a+0.4)*16), Vector2(cos(a+0.6)*18,sin(a+0.6)*18), Vector2(cos(a+0.15)*4,sin(a+0.15)*4)]), Color(st_c.r,st_c.g,st_c.b,0.75))
			t.draw_circle(Vector2.ZERO, 5, main_color.darkened(0.3))
			draw_element_core(t)

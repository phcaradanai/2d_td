extends RefCounted
class_name CosmeticPreviewResolver

## Mirrors color/shape resolution from projectile.gd and TowerHitVFX so the
## cosmetic preview panel shows the actual in-game visuals for each tower.

static func get_projectile_draw_info(tower_cfg: Dictionary) -> Dictionary:
	var tower_id := str(tower_cfg.get("id", "")).to_lower()
	var attack_type := str(tower_cfg.get("attack_type", "single"))
	var elements: Array = tower_cfg.get("elements", [])
	var speed := float(tower_cfg.get("projectile_speed", 500.0))

	var core := Color(0.78, 0.9, 1.0, 1.0)
	var glow := Color(0.28, 0.8, 1.0, 0.85)
	var accent := Color(0.9, 0.96, 1.0, 1.0)
	var shape := "bolt"

	if tower_id.begins_with("flamethrower"):
		core = _element_color("fire")
		glow = _element_color("darkness")
		accent = _element_color("earth").lightened(0.25)
		shape = "flame"
	elif tower_id.find("laser") >= 0 or tower_id.find("rail") >= 0:
		shape = "beam"
		if elements.size() > 0:
			core = _element_color(str(elements[0]))
			glow = core.lightened(0.25)
	elif attack_type == "splash":
		core = Color(1.0, 0.55, 0.24, 1.0)
		glow = Color(1.0, 0.28, 0.08, 0.85)
		accent = Color(1.0, 0.85, 0.45, 1.0)
		shape = "shell"
	elif attack_type == "slow":
		shape = "droplet"
		if elements.size() > 0:
			core = _element_color(str(elements[0]))
			glow = core.lightened(0.25)
	elif elements.size() > 0:
		core = _element_color(str(elements[0]))
		glow = core.lightened(0.25)
		accent = Color.WHITE
		if elements.size() >= 2:
			glow = _element_color(str(elements[1]))
		if elements.size() >= 3:
			accent = _element_color(str(elements[2])).lightened(0.2)

	return {
		"core_color": core,
		"glow_color": glow,
		"accent_color": accent,
		"shape": shape,
		"speed": speed,
	}

static func get_impact_draw_info(tower_cfg: Dictionary) -> Dictionary:
	var tower_id := str(tower_cfg.get("id", "")).to_lower()
	var attack_type := str(tower_cfg.get("attack_type", "single"))
	var elements: Array = tower_cfg.get("elements", [])

	var mode := _resolve_hit_vfx_mode(tower_id, attack_type)

	var core := Color(0.78, 0.9, 1.0, 1.0)
	var glow := Color(0.28, 0.8, 1.0, 0.85)
	var accent := Color(0.9, 0.96, 1.0, 1.0)

	if elements.size() > 0:
		core = _element_color(str(elements[0]))
		glow = core.lightened(0.25)
		accent = Color.WHITE
		if elements.size() >= 2:
			glow = _element_color(str(elements[1]))
		if elements.size() >= 3:
			accent = _element_color(str(elements[2])).lightened(0.2)
	elif attack_type == "splash":
		core = Color(1.0, 0.55, 0.24, 1.0)
		glow = Color(1.0, 0.28, 0.08, 0.85)
		accent = Color(1.0, 0.85, 0.45, 1.0)

	return {
		"mode": mode,
		"core_color": core,
		"glow_color": glow,
		"accent_color": accent,
	}

static func _resolve_hit_vfx_mode(tower_id: String, attack_type: String) -> String:
	if tower_id.begins_with("earth") or tower_id.begins_with("quaker") or tower_id.begins_with("flesh_golem") or tower_id.begins_with("gunpowder"):
		return "seismic"
	if tower_id.begins_with("hydro") or tower_id.begins_with("tidal") or tower_id.begins_with("water") or tower_id.begins_with("vapor"):
		return "water"
	if tower_id.begins_with("ice") or tower_id.begins_with("hail") or tower_id.begins_with("polar") or tower_id.begins_with("windstorm"):
		return "frost"
	if tower_id.begins_with("poison") or tower_id.begins_with("disease") or tower_id.begins_with("muck") or tower_id.begins_with("corrosion") or tower_id.begins_with("mushroom"):
		return "toxic"
	if tower_id.begins_with("darkness") or tower_id.begins_with("oblivion") or tower_id.begins_with("drowning") or tower_id.begins_with("voodoo"):
		return "void"
	if tower_id.begins_with("light") or tower_id.begins_with("nova") or tower_id.begins_with("laser"):
		return "prism"
	if tower_id.begins_with("fire") or tower_id.begins_with("flame") or tower_id.begins_with("flamethrower"):
		return "fire_blast"
	if tower_id.begins_with("nature") or tower_id.begins_with("roots") or tower_id.begins_with("life"):
		return "nature"
	if tower_id.begins_with("electricity") or tower_id.begins_with("jinx"):
		return "chain"
	if tower_id.begins_with("gold"):
		return "gold"
	if tower_id.begins_with("magic") or tower_id.begins_with("quark") or tower_id.begins_with("impulse") or tower_id.begins_with("periodic"):
		return "arcane"
	if attack_type == "splash":
		return "splash"
	if attack_type == "slow":
		return "slow"
	if attack_type == "chain":
		return "chain"
	return "single"

static func _element_color(element: String) -> Color:
	match element.to_lower():
		"light": return Color(1.0, 0.88, 0.18, 1.0)
		"darkness", "dark": return Color(0.52, 0.16, 0.9, 1.0)
		"water": return Color(0.16, 0.78, 1.0, 1.0)
		"fire": return Color(1.0, 0.26, 0.06, 1.0)
		"nature": return Color(0.22, 0.95, 0.34, 1.0)
		"earth": return Color(0.86, 0.53, 0.2, 1.0)
		_: return Color(0.78, 0.9, 1.0, 1.0)

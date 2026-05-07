extends Node

# Theme Manager
# Handles loading and providing AreaTheme data.

var themes: Dictionary = {}

func _init() -> void:
	_create_default_themes()

func get_theme(theme_id: String) -> Resource:
	return themes.get(theme_id, themes.get("area_grasslands"))

func _create_default_themes() -> void:
	# Sector A: Main Hub
	var sector_a = load("res://scripts/map/area_theme.gd").new()
	sector_a.theme_id = "area_grasslands" # Keep ID for compatibility
	sector_a.display_name = "Sector A: Hub"
	sector_a.color_bg = Color(0.02, 0.03, 0.05) # Deep Navy-Black
	sector_a.color_buildable = Color(0.05, 0.08, 0.12) # Gunmetal blue
	sector_a.color_path = Color(0.01, 0.01, 0.01) # Near Black
	sector_a.color_blocked = Color(0.01, 0.02, 0.03) # Abyss
	sector_a.color_grid = Color(0.2, 0.6, 1.0, 0.04) # Subtle Cyan Grid
	sector_a.color_path_glow = Color(0.0, 1.0, 1.0, 0.15) # Cyan Glow
	sector_a.color_path_line = Color(0.2, 0.8, 1.0, 0.4) # Electric Blue Line
	sector_a.color_spawn = Color(1.0, 0.2, 0.2, 0.8) # Danger Red
	sector_a.color_base = Color(0.2, 1.0, 1.0, 0.8) # Secure Cyan
	themes["area_grasslands"] = sector_a

	# Sector B: Outpost
	var sector_b = load("res://scripts/map/area_theme.gd").new()
	sector_b.theme_id = "area_forest"
	sector_b.display_name = "Sector B: Outpost"
	sector_b.color_bg = Color(0.01, 0.04, 0.04) # Deep Teal-Black
	sector_b.color_buildable = Color(0.03, 0.08, 0.08)
	sector_b.color_path = Color(0.01, 0.01, 0.01)
	sector_b.color_blocked = Color(0.0, 0.02, 0.02)
	sector_b.color_grid = Color(0.0, 1.0, 0.8, 0.04) # Teal Grid
	sector_b.color_path_glow = Color(0.0, 1.0, 0.6, 0.15) # Teal Glow
	sector_b.color_path_line = Color(0.2, 1.0, 0.8, 0.4)
	sector_b.color_spawn = Color(1.0, 0.3, 0.1, 0.8) # Orange-Red
	sector_b.color_base = Color(0.0, 0.8, 1.0, 0.8)
	themes["area_forest"] = sector_b

	# Sector C: Reactor
	var sector_c = load("res://scripts/map/area_theme.gd").new()
	sector_c.theme_id = "area_forest_river"
	sector_c.display_name = "Sector C: Reactor"
	sector_c.color_bg = Color(0.04, 0.02, 0.06) # Deep Violet-Black
	sector_c.color_buildable = Color(0.08, 0.05, 0.12)
	sector_c.color_path = Color(0.01, 0.01, 0.01)
	sector_c.color_blocked = Color(0.02, 0.0, 0.04)
	sector_c.color_grid = Color(0.6, 0.2, 1.0, 0.04) # Violet Grid
	sector_c.color_path_glow = Color(0.8, 0.2, 1.0, 0.15) # Magenta/Violet Glow
	sector_c.color_path_line = Color(0.7, 0.4, 1.0, 0.4)
	sector_c.color_spawn = Color(1.0, 0.1, 0.4, 0.8) # Hot Pink
	sector_c.color_base = Color(0.2, 0.8, 1.0, 0.8)
	themes["area_forest_river"] = sector_c

	# Sector D: Core
	var sector_d = load("res://scripts/map/area_theme.gd").new()
	sector_d.theme_id = "area_mountain"
	sector_d.display_name = "Sector D: Core"
	sector_d.color_bg = Color(0.02, 0.02, 0.03) # Near Black
	sector_d.color_buildable = Color(0.06, 0.06, 0.08)
	sector_d.color_path = Color(0.0, 0.0, 0.0)
	sector_d.color_blocked = Color(0.01, 0.01, 0.02)
	sector_d.color_grid = Color(0.4, 0.6, 1.0, 0.06) # Bright Blue Grid
	sector_d.color_path_glow = Color(1.0, 0.8, 0.2, 0.15) # Golden Energy Glow
	sector_d.color_path_line = Color(1.0, 0.6, 0.1, 0.4)
	sector_d.color_spawn = Color(1.0, 0.0, 0.0, 0.9) # Pure Danger
	sector_d.color_base = Color(0.0, 1.0, 1.0, 0.9)
	themes["area_mountain"] = sector_d


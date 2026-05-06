extends Node

# Theme Manager
# Handles loading and providing AreaTheme data.

var themes: Dictionary = {}

func _init() -> void:
	_create_default_themes()

func get_theme(theme_id: String) -> Resource:
	return themes.get(theme_id, themes.get("area_grasslands"))

func _create_default_themes() -> void:
	# Area 1: Grasslands
	var grasslands = load("res://scripts/map/area_theme.gd").new()
	grasslands.theme_id = "area_grasslands"
	grasslands.display_name = "Grasslands"
	grasslands.color_bg = Color(0.1, 0.25, 0.1) # Darker green base
	grasslands.color_buildable = Color(0.15, 0.35, 0.15) # Lush grass
	grasslands.color_path = Color(0.45, 0.35, 0.2) # Tan dirt
	grasslands.color_blocked = Color(0.05, 0.15, 0.05) # Deep forest edges
	grasslands.color_grid = Color(1, 1, 1, 0.03)
	grasslands.color_path_glow = Color(0.9, 0.8, 0.4, 0.1) # Golden path glow
	grasslands.color_path_line = Color(0.7, 0.6, 0.3, 0.3)
	themes["area_grasslands"] = grasslands

	# Area 2: Forest
	var forest = load("res://scripts/map/area_theme.gd").new()
	forest.theme_id = "area_forest"
	forest.display_name = "Forest"
	forest.color_bg = Color(0.05, 0.15, 0.05) # Very dark green
	forest.color_buildable = Color(0.08, 0.22, 0.08) # Mossy floor
	forest.color_path = Color(0.3, 0.2, 0.1) # Dark mud trail
	forest.color_blocked = Color(0.02, 0.1, 0.02) # Dense thicket
	forest.color_path_glow = Color(0.4, 0.7, 0.3, 0.15) # Greenish path glow
	forest.color_path_line = Color(0.3, 0.5, 0.2, 0.4)
	themes["area_forest"] = forest

	# Area 3: Forest River
	var river = load("res://scripts/map/area_theme.gd").new()
	river.theme_id = "area_forest_river"
	river.display_name = "Forest River"
	river.color_bg = Color(0.05, 0.1, 0.15) # Dark water base
	river.color_buildable = Color(0.1, 0.25, 0.1) # Wet grass
	river.color_path = Color(0.35, 0.25, 0.15) # Wooden bridge/path
	river.color_blocked = Color(0.0, 0.15, 0.25) # Deep water
	river.color_path_glow = Color(0.3, 0.6, 0.8, 0.15) # Bluish path glow
	river.color_path_line = Color(0.4, 0.7, 0.9, 0.4)
	themes["area_forest_river"] = river

	# Area 4: Mountain
	var mountain = load("res://scripts/map/area_theme.gd").new()
	mountain.theme_id = "area_mountain"
	mountain.display_name = "Mountain"
	mountain.color_bg = Color(0.15, 0.15, 0.18) # Dark stone base
	mountain.color_buildable = Color(0.25, 0.25, 0.28) # Gray stone tiles
	mountain.color_path = Color(0.1, 0.1, 0.1) # Carved stone road
	mountain.color_blocked = Color(0.05, 0.05, 0.08) # Abyss/cliff
	mountain.color_path_glow = Color(0.8, 0.4, 0.2, 0.2) # Ember path glow (torches)
	mountain.color_path_line = Color(1.0, 0.5, 0.2, 0.5)
	themes["area_mountain"] = mountain

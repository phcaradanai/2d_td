extends Resource
class_name AreaTheme

@export var theme_id: String = "area_grasslands"
@export var display_name: String = "Grasslands"

@export_group("Colors")
@export var color_bg: Color = Color(0.02, 0.03, 0.05)
@export var color_path: Color = Color(0.01, 0.01, 0.01)
@export var color_buildable: Color = Color(0.05, 0.08, 0.12)
@export var color_blocked: Color = Color(0.01, 0.02, 0.03)
@export var color_grid: Color = Color(0.2, 0.6, 1.0, 0.05)

@export_group("Path Visuals")
@export var path_width: float = 48.0
@export var path_glow_width: float = 12.0
@export var color_path_glow: Color = Color(0.0, 1.0, 1.0, 0.15)
@export var color_path_line: Color = Color(0.2, 0.8, 1.0, 0.4)

@export_group("Decorations")
@export var prop_pool: Array[String] = [] # IDs of props to spawn randomly
@export var prop_density: float = 0.08 # Slightly lower density for cleaner look
@export var blocker_prop_pool: Array[String] = [] # Props that act as blockers

@export_group("Markers")
@export var color_spawn: Color = Color(1.0, 0.2, 0.2, 0.8)
@export var color_base: Color = Color(0.2, 1.0, 1.0, 0.8)


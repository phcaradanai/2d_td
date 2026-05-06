extends Resource
class_name AreaTheme

@export var theme_id: String = "area_grasslands"
@export var display_name: String = "Grasslands"

@export_group("Colors")
@export var color_bg: Color = Color(0.1, 0.3, 0.1)
@export var color_path: Color = Color(0.4, 0.3, 0.1)
@export var color_buildable: Color = Color(0.15, 0.35, 0.15)
@export var color_blocked: Color = Color(0.05, 0.15, 0.05)
@export var color_grid: Color = Color(1, 1, 1, 0.05)

@export_group("Path Visuals")
@export var path_width: float = 48.0
@export var path_glow_width: float = 12.0
@export var color_path_glow: Color = Color(1.0, 0.4, 0.2, 0.15)
@export var color_path_line: Color = Color(1.0, 0.3, 0.1, 0.4)

@export_group("Decorations")
@export var prop_pool: Array[String] = [] # IDs of props to spawn randomly
@export var prop_density: float = 0.1 # Probability of a prop in a non-path cell
@export var blocker_prop_pool: Array[String] = [] # Props that act as blockers

@export_group("Markers")
@export var color_spawn: Color = Color(0.2, 1.0, 0.5, 0.3)
@export var color_base: Color = Color(1.0, 0.2, 0.3, 0.3)

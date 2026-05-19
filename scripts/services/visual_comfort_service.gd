extends Node
class_name VisualComfortService

const HIT_FLASH_ALPHA_MAX := 0.22
const HIT_FLASH_DURATION := 0.08
const HIT_FLASH_COOLDOWN := 0.18
const LINK_ALPHA_MAX := 0.28
const SHIELD_ALPHA_MAX := 0.24
const STATUS_ICON_ALPHA := 0.75
const MAX_FLASHES_PER_SECOND := 3
const SOFT_GLOW_ALPHA := 0.18

var visual_comfort_mode := true

var _last_flash_msec: Dictionary = {}


func allow_flash(key: String) -> bool:
	if key == "":
		key = "global"
	if not visual_comfort_mode:
		return true
	if _current_fps() < 52.0:
		return false

	var now := Time.get_ticks_msec()
	var last := int(_last_flash_msec.get(key, -100000))
	var min_gap := int(ceil(1000.0 / float(MAX_FLASHES_PER_SECOND)))
	min_gap = maxi(min_gap, int(round(HIT_FLASH_COOLDOWN * 1000.0)))
	if now - last < min_gap:
		return false

	_last_flash_msec[key] = now
	return true


func get_hit_flash_color(element_or_damage_type: String) -> Color:
	var key := element_or_damage_type.strip_edges().to_lower()
	if key.contains("fire") or key.contains("burn") or key.contains("flame"):
		return Color(1.0, 0.48, 0.16, HIT_FLASH_ALPHA_MAX)
	if key.contains("poison") or key.contains("nature") or key.contains("disease") or key.contains("spore"):
		return Color(0.48, 0.95, 0.34, HIT_FLASH_ALPHA_MAX)
	if key.contains("ice") or key.contains("frost") or key.contains("slow") or key.contains("water"):
		return Color(0.40, 0.86, 1.0, HIT_FLASH_ALPHA_MAX)
	if key.contains("dark") or key.contains("void") or key.contains("jinx") or key.contains("curse") or key.contains("oblivion"):
		return Color(0.70, 0.45, 1.0, HIT_FLASH_ALPHA_MAX)
	if key.contains("light") or key.contains("holy") or key.contains("laser"):
		return Color(1.0, 0.82, 0.36, HIT_FLASH_ALPHA_MAX)
	return Color(1.0, 0.62, 0.26, HIT_FLASH_ALPHA_MAX)


func get_link_color(effect_type: String) -> Color:
	var key := effect_type.strip_edges().to_lower()
	if key.contains("disrupt") or key.contains("emp"):
		return Color(0.48, 0.78, 1.0, LINK_ALPHA_MAX)
	if key.contains("shield"):
		return Color(0.45, 0.82, 1.0, LINK_ALPHA_MAX)
	return Color(0.62, 0.74, 0.92, LINK_ALPHA_MAX)


func get_shield_color(shield_type: String) -> Color:
	var key := shield_type.strip_edges().to_lower()
	if key.contains("gold") or key.contains("holy") or key.contains("light"):
		return Color(1.0, 0.78, 0.34, SHIELD_ALPHA_MAX)
	return Color(0.42, 0.78, 1.0, SHIELD_ALPHA_MAX)


func should_skip_hit_flash() -> bool:
	return visual_comfort_mode and _current_fps() < 52.0


func allow_shield_ripple(key: String) -> bool:
	if visual_comfort_mode and _current_fps() < 58.0:
		return false
	return allow_flash(key)


func get_hit_flash_duration() -> float:
	return HIT_FLASH_DURATION


func get_link_alpha_max() -> float:
	return LINK_ALPHA_MAX


func get_shield_alpha_max() -> float:
	return SHIELD_ALPHA_MAX


func get_status_icon_alpha() -> float:
	return STATUS_ICON_ALPHA


func get_soft_glow_alpha() -> float:
	return SOFT_GLOW_ALPHA


func _current_fps() -> float:
	var perf := get_node_or_null("/root/PerformanceBudgetService")
	if perf != null:
		return float(perf.current_fps)
	return float(Engine.get_frames_per_second())

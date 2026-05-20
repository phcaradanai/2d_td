extends Node
## PerformanceBudgetService
##
## Visual policy layer for PERF-60. It never changes gameplay math or timing;
## callers use it only to skip/degrade decorative effects.

signal quality_changed(quality_name: String)
signal settings_changed(settings: Dictionary)

enum Quality { HIGH, BALANCED, LOW }

const FPS_HIGH := 58.0
const FPS_BALANCED := 50.0
const FPS_SAMPLE_INTERVAL := 0.50
const QUALITY_HOLD_SECONDS := 1.25

const DEFAULT_SETTINGS := {
	"visual_quality": "auto",
	"attack_vfx": "normal",
	"floating_damage_numbers": "off",
	"status_effects": "icons_only",
	"screen_shake": "off",
}

var current_fps: float = 60.0
var quality: Quality = Quality.HIGH

var max_attack_vfx_active: int = 60
var max_attack_vfx_spawn_per_frame: int = 8
var max_status_vfx_active: int = 80
var max_damage_numbers_per_second: int = 0
var allow_trails: bool = false
var allow_minor_impacts: bool = true
var allow_continuous_auras: bool = false
var allow_screen_shake: bool = true
var target_scans_per_second: int = 0
var avg_candidates_per_scan: float = 0.0
var active_towers_scanning: int = 0

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var _fps_elapsed: float = 0.0
var _pending_quality: Quality = Quality.HIGH
var _pending_elapsed: float = 0.0
var _attack_vfx_frame: int = -1
var _attack_vfx_spawned_this_frame: int = 0
var _damage_second_msec: int = 0
var _damage_numbers_this_second: int = 0
var _stat_timer: float = 0.0
var _target_scan_bucket: int = 0
var _target_candidate_bucket: int = 0
var _target_scan_towers: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("performance_budget_service")
	_apply_platform_defaults()
	_recompute_budgets()

func _process(delta: float) -> void:
	_fps_elapsed += delta
	_stat_timer += delta
	if _stat_timer >= FPS_SAMPLE_INTERVAL:
		_stat_timer = 0.0
		target_scans_per_second = _target_scan_bucket
		avg_candidates_per_scan = float(_target_candidate_bucket) / maxf(float(_target_scan_bucket), 1.0)
		active_towers_scanning = _target_scan_towers.size()
		_target_scan_bucket = 0
		_target_candidate_bucket = 0
		_target_scan_towers.clear()
	if _fps_elapsed < FPS_SAMPLE_INTERVAL:
		return
	_fps_elapsed = 0.0
	current_fps = float(Engine.get_frames_per_second())
	_update_auto_quality()

func get_default_settings() -> Dictionary:
	var out := DEFAULT_SETTINGS.duplicate(true)
	if _is_low_power_platform():
		out["attack_vfx"] = "minimal"
		out["screen_shake"] = "off"
	out["screen_shake"] = "off"
	return out

func apply_settings(settings: Dictionary) -> void:
	var next := get_default_settings()
	for key in next.keys():
		if settings.has(key):
			next[key] = settings[key]
	next["screen_shake"] = "off"
	_settings = next
	if str(_settings.get("visual_quality", "auto")) != "auto":
		quality = _quality_from_setting(str(_settings.get("visual_quality", "auto")))
	_recompute_budgets()
	settings_changed.emit(get_settings())

func get_settings() -> Dictionary:
	return _settings.duplicate(true)

func get_quality_name() -> String:
	match quality:
		Quality.HIGH:
			return "HIGH"
		Quality.BALANCED:
			return "BALANCED"
		Quality.LOW:
			return "LOW"
	return "LOW"

func get_vfx_quality_name() -> String:
	match quality:
		Quality.HIGH:
			return "High"
		Quality.BALANCED:
			return "Medium"
		Quality.LOW:
			return "Low"
	return "Low"

func get_budget(key: String) -> Variant:
	match key:
		"max_attack_vfx_active":
			return max_attack_vfx_active
		"max_attack_vfx_spawn_per_frame":
			return max_attack_vfx_spawn_per_frame
		"max_status_vfx_active":
			return max_status_vfx_active
		"max_damage_numbers_per_second":
			return max_damage_numbers_per_second
		"allow_trails":
			return allow_trails
		"allow_minor_impacts":
			return allow_minor_impacts
		"allow_continuous_auras":
			return allow_continuous_auras
		"allow_screen_shake":
			return allow_screen_shake
	return null

func can_spawn_attack_vfx(active_count: int) -> bool:
	_reset_attack_frame_bucket()
	if active_count >= max_attack_vfx_active:
		return false
	if _attack_vfx_spawned_this_frame >= max_attack_vfx_spawn_per_frame:
		return false
	_attack_vfx_spawned_this_frame += 1
	return true

func allow_floating_damage_number() -> bool:
	if str(_settings.get("floating_damage_numbers", "off")) == "off":
		return false
	if current_fps < 55.0:
		return false
	var now := Time.get_ticks_msec()
	if now - _damage_second_msec >= 1000:
		_damage_second_msec = now
		_damage_numbers_this_second = 0
	if _damage_numbers_this_second >= max_damage_numbers_per_second:
		return false
	_damage_numbers_this_second += 1
	return true

func register_target_check() -> void:
	register_target_scan(null, 0)

func register_target_scan(tower: Node = null, candidate_count: int = 0) -> void:
	_target_scan_bucket += 1
	_target_candidate_bucket += max(candidate_count, 0)
	if tower != null and is_instance_valid(tower):
		_target_scan_towers[tower.get_instance_id()] = true

func debug_force_fps(fps: float) -> void:
	current_fps = fps
	_set_quality(_quality_for_fps(fps))
	_recompute_budgets()

func _reset_attack_frame_bucket() -> void:
	var frame := Engine.get_process_frames()
	if frame == _attack_vfx_frame:
		return
	_attack_vfx_frame = frame
	_attack_vfx_spawned_this_frame = 0

func _update_auto_quality() -> void:
	if str(_settings.get("visual_quality", "auto")) != "auto":
		_set_quality(_quality_from_setting(str(_settings.get("visual_quality", "auto"))))
		return
	var next := _quality_for_fps(current_fps)
	if next == quality:
		_pending_quality = next
		_pending_elapsed = 0.0
		return
	if next != _pending_quality:
		_pending_quality = next
		_pending_elapsed = 0.0
		return
	_pending_elapsed += FPS_SAMPLE_INTERVAL
	if _pending_elapsed >= QUALITY_HOLD_SECONDS:
		_set_quality(next)
		_pending_elapsed = 0.0

func _set_quality(next: Quality) -> void:
	if quality == next:
		return
	quality = next
	_recompute_budgets()
	quality_changed.emit(get_quality_name())

func _quality_for_fps(fps: float) -> Quality:
	if fps >= FPS_HIGH:
		return Quality.HIGH
	if fps >= FPS_BALANCED:
		return Quality.BALANCED
	return Quality.LOW

func _quality_from_setting(value: String) -> Quality:
	match value:
		"high":
			return Quality.HIGH
		"balanced", "medium":
			return Quality.BALANCED
		"low":
			return Quality.LOW
		_:
			return _quality_for_fps(current_fps)

func _recompute_budgets() -> void:
	var attack_vfx := str(_settings.get("attack_vfx", "normal"))
	var damage_numbers := str(_settings.get("floating_damage_numbers", "off"))
	var status_effects := str(_settings.get("status_effects", "icons_only"))

	match quality:
		Quality.HIGH:
			max_attack_vfx_active = 70
			max_attack_vfx_spawn_per_frame = 10
			max_status_vfx_active = 120
			allow_minor_impacts = true
			allow_trails = attack_vfx == "full"
		Quality.BALANCED:
			max_attack_vfx_active = 44
			max_attack_vfx_spawn_per_frame = 5
			max_status_vfx_active = 80
			allow_minor_impacts = true
			allow_trails = false
		Quality.LOW:
			max_attack_vfx_active = 22
			max_attack_vfx_spawn_per_frame = 2
			max_status_vfx_active = 45
			allow_minor_impacts = false
			allow_trails = false

	if attack_vfx == "minimal":
		max_attack_vfx_active = mini(max_attack_vfx_active, 28)
		max_attack_vfx_spawn_per_frame = mini(max_attack_vfx_spawn_per_frame, 3)
	elif attack_vfx == "full" and quality == Quality.HIGH:
		max_attack_vfx_active = 80

	allow_continuous_auras = status_effects == "icons_minimal_pulse" and quality == Quality.HIGH and not _is_low_power_platform()
	# PERF-60 default: screen shake is disabled globally for readability and frame stability.
	allow_screen_shake = false

	match damage_numbers:
		"full":
			max_damage_numbers_per_second = 20 if quality != Quality.LOW else 0
		"limited":
			max_damage_numbers_per_second = 10 if quality == Quality.HIGH else (5 if quality == Quality.BALANCED else 0)
		_:
			max_damage_numbers_per_second = 0

func _apply_platform_defaults() -> void:
	if _is_low_power_platform():
		_settings["attack_vfx"] = "minimal"
		_settings["screen_shake"] = "off"
		_settings["floating_damage_numbers"] = "off"
		_settings["status_effects"] = "icons_only"

func _is_low_power_platform() -> bool:
	var os_name := OS.get_name()
	return OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios") \
		or os_name in ["Web", "Android", "iOS"]

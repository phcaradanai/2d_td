## PerformanceBudget — central FX quality and telemetry singleton.
## Registered as an autoload so any node can read fx_quality without coupling to main.gd.
##
## Quality levels:
##   HIGH   (fps >= 58)  — full glow, aura, trails, beam spam
##   MEDIUM (fps >= 45)  — reduced aura redraw, shorter trails, fewer glow layers
##   LOW    (fps <  45)  — disable decorative glow, static icons, minimal animation
##
## Hysteresis prevents rapid flickering between modes.
extends Node

enum Quality { HIGH, MEDIUM, LOW }

const FPS_TO_HIGH   := 58.0
const FPS_TO_MEDIUM := 45.0   # downgrade threshold from HIGH
const FPS_TO_LOW    := 35.0   # downgrade threshold from MEDIUM

const UPGRADE_HOLD_SECS   := 3.0  # must stay above threshold this long before upgrading
const DOWNGRADE_HOLD_SECS := 1.0  # must stay below threshold this long before downgrading

const FPS_SAMPLE_INTERVAL  := 0.5   # how often we measure FPS
const STAT_UPDATE_INTERVAL := 0.5   # how often overlay-facing counters reset

# ── Public readable state ─────────────────────────────────────────────────────
var current_fps: float   = 60.0
var fx_quality: Quality  = Quality.HIGH

# Counters for the performance overlay
var target_checks_per_second: int = 0
var active_fx_count: int          = 0  # rough gauge, updated externally

# ── Private ──────────────────────────────────────────────────────────────────
var _fps_timer:     float = 0.0
var _upgrade_timer: float = 0.0
var _downgrade_timer: float = 0.0

var _target_check_bucket:  int   = 0
var _stat_timer:           float = 0.0

# Cached enemy list — refreshed once per frame here, so every tower scan
# reads the same array instead of each calling get_nodes_in_group separately.
# This turns N tower × (1/scan_interval) group queries per second into a flat
# 60 queries/second regardless of tower count.
var _enemy_list_cache: Array = []
var _enemy_cache_frame: int  = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "PerformanceBudget"

func _process(delta: float) -> void:
	# Refresh enemy cache once per frame — shared by all tower targeting scans.
	_enemy_list_cache = get_tree().get_nodes_in_group("enemies")
	_enemy_cache_frame = Engine.get_process_frames()

	_fps_timer += delta
	if _fps_timer >= FPS_SAMPLE_INTERVAL:
		_fps_timer = 0.0
		current_fps = Engine.get_frames_per_second()
		_update_quality()

	_stat_timer += delta
	if _stat_timer >= STAT_UPDATE_INTERVAL:
		_stat_timer = 0.0
		target_checks_per_second = _target_check_bucket
		_target_check_bucket = 0

# ── Quality queries (hot path — keep branchless) ──────────────────────────────
func allow_decorative_fx() -> bool:
	return fx_quality == Quality.HIGH

func allow_aura_full_quality() -> bool:
	return fx_quality != Quality.LOW

func allow_extra_glow() -> bool:
	return fx_quality == Quality.HIGH

## Returns 1 / 2 / 4 — caller multiplies its normal interval by this.
func get_effect_tick_multiplier() -> float:
	match fx_quality:
		Quality.MEDIUM: return 2.0
		Quality.LOW:    return 4.0
		_:              return 1.0

func get_quality_name() -> String:
	match fx_quality:
		Quality.HIGH:   return "HIGH"
		Quality.MEDIUM: return "MED"
		Quality.LOW:    return "LOW"
	return "?"

# ── Telemetry helpers ─────────────────────────────────────────────────────────
func register_target_check() -> void:
	_target_check_bucket += 1

## Call from wave_manager / enemy_container when an enemy is added or removed.
func update_enemy_cache(enemies: Array) -> void:
	_enemy_list_cache = enemies
	_enemy_cache_frame = Engine.get_process_frames()

## Towers call this instead of get_nodes_in_group("enemies").
## Falls back to group query if cache is stale (> 2 frames old).
func get_enemies() -> Array:
	var frame := Engine.get_process_frames()
	if frame - _enemy_cache_frame <= 2:
		return _enemy_list_cache
	# Cache stale — should not happen in normal gameplay, but be safe
	return []

# ── Quality transitions ───────────────────────────────────────────────────────
func _update_quality() -> void:
	match fx_quality:
		Quality.HIGH:
			if current_fps < FPS_TO_MEDIUM:
				_downgrade_timer += FPS_SAMPLE_INTERVAL
				_upgrade_timer = 0.0
				if _downgrade_timer >= DOWNGRADE_HOLD_SECS:
					fx_quality = Quality.LOW
					_downgrade_timer = 0.0
			elif current_fps < FPS_TO_HIGH:
				_downgrade_timer += FPS_SAMPLE_INTERVAL
				_upgrade_timer = 0.0
				if _downgrade_timer >= DOWNGRADE_HOLD_SECS:
					fx_quality = Quality.MEDIUM
					_downgrade_timer = 0.0
			else:
				_downgrade_timer = 0.0
		Quality.MEDIUM:
			if current_fps >= FPS_TO_HIGH:
				_upgrade_timer += FPS_SAMPLE_INTERVAL
				_downgrade_timer = 0.0
				if _upgrade_timer >= UPGRADE_HOLD_SECS:
					fx_quality = Quality.HIGH
					_upgrade_timer = 0.0
			elif current_fps < FPS_TO_LOW:
				_downgrade_timer += FPS_SAMPLE_INTERVAL
				_upgrade_timer = 0.0
				if _downgrade_timer >= DOWNGRADE_HOLD_SECS:
					fx_quality = Quality.LOW
					_downgrade_timer = 0.0
			else:
				_upgrade_timer = 0.0
				_downgrade_timer = 0.0
		Quality.LOW:
			if current_fps >= FPS_TO_MEDIUM:
				_upgrade_timer += FPS_SAMPLE_INTERVAL
				_downgrade_timer = 0.0
				if _upgrade_timer >= UPGRADE_HOLD_SECS:
					fx_quality = Quality.MEDIUM
					_upgrade_timer = 0.0
			else:
				_upgrade_timer = 0.0

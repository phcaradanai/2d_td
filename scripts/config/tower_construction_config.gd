extends RefCounted
class_name TowerConstructionConfig

const DEFAULT_BUILD_SECONDS := 0.55
const DEFAULT_UPGRADE_SECONDS := 0.65
const MIN_SECONDS := 0.10
const MAX_SECONDS := 3.00

static func get_build_seconds(cfg: Dictionary) -> float:
	return _read_seconds(cfg, "build_time", DEFAULT_BUILD_SECONDS)

static func get_upgrade_seconds(cfg: Dictionary) -> float:
	return _read_seconds(cfg, "upgrade_time", DEFAULT_UPGRADE_SECONDS)

static func _read_seconds(cfg: Dictionary, key: String, fallback: float) -> float:
	var value := float(cfg.get(key, fallback))
	return clampf(value, MIN_SECONDS, MAX_SECONDS)

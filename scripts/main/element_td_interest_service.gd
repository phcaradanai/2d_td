extends RefCounted
class_name ElementTDInterestService

const DEFAULT_BASE_RATE: float = 0.02
const DEFAULT_UPGRADE_STEP: float = 0.01
const DEFAULT_MAX_UPGRADES: int = 5
const DEFAULT_INTERVAL_SEC: float = 15.0

var enabled: bool = true
var base_rate: float = DEFAULT_BASE_RATE
var rate: float = DEFAULT_BASE_RATE
var upgrade_step: float = DEFAULT_UPGRADE_STEP
var upgrade_count: int = 0
var max_upgrades: int = DEFAULT_MAX_UPGRADES
var interval_sec: float = DEFAULT_INTERVAL_SEC
var elapsed: float = 0.0
var disabled_for_wave: bool = false

func configure_from_level(level_data: Dictionary) -> void:
	enabled = bool(level_data.get("interest_enabled", true))
	base_rate = float(level_data.get("interest_rate", DEFAULT_BASE_RATE))
	upgrade_step = float(level_data.get("interest_upgrade_step", DEFAULT_UPGRADE_STEP))
	max_upgrades = int(level_data.get("interest_max_upgrades", DEFAULT_MAX_UPGRADES))
	interval_sec = float(level_data.get("interest_interval_sec", DEFAULT_INTERVAL_SEC))

	base_rate = max(0.0, base_rate)
	upgrade_step = max(0.0, upgrade_step)
	max_upgrades = max(0, max_upgrades)
	interval_sec = max(1.0, interval_sec)

	upgrade_count = 0
	elapsed = 0.0
	disabled_for_wave = false
	recalculate_rate()

func reset_to_defaults() -> void:
	configure_from_level({})

func recalculate_rate() -> void:
	rate = base_rate + float(upgrade_count) * upgrade_step
	rate = max(0.0, rate)

func can_choose_upgrade() -> bool:
	return enabled and upgrade_step > 0.0 and upgrade_count < max_upgrades

func apply_upgrade() -> bool:
	if not can_choose_upgrade():
		return false
	upgrade_count += 1
	recalculate_rate()
	return true

func format_rate_percent() -> String:
	return "%.0f%%" % (rate * 100.0)

func format_next_rate_percent() -> String:
	return "%.0f%%" % ((rate + upgrade_step) * 100.0)

func reset_wave_state() -> void:
	elapsed = 0.0
	disabled_for_wave = false

func disable_for_current_wave() -> void:
	disabled_for_wave = true

func tick(delta: float, current_gold: int, active_enemy_count: int, can_tick: bool) -> int:
	if not can_tick:
		return 0
	if not enabled or disabled_for_wave:
		return 0
	if active_enemy_count <= 0:
		return 0

	elapsed += delta
	var total_interest := 0
	while elapsed >= interval_sec:
		elapsed -= interval_sec
		var interest_gold := int(floor(float(current_gold + total_interest) * rate))
		if interest_gold > 0:
			total_interest += interest_gold

	return total_interest

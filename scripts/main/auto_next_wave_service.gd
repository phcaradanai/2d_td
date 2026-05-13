extends RefCounted
class_name AutoNextWaveService

const DEFAULT_ENABLED: bool = true
const DEFAULT_DELAY_SEC: float = 15.0
const MIN_DELAY_SEC: float = 1.0

var enabled: bool = DEFAULT_ENABLED
var delay_sec: float = DEFAULT_DELAY_SEC
var remaining: float = 0.0
var countdown_active: bool = false
var has_started_first_wave: bool = false

func configure_from_level(level_data: Dictionary) -> void:
	enabled = bool(level_data.get("auto_next_wave_enabled", DEFAULT_ENABLED))
	delay_sec = float(level_data.get("auto_next_wave_delay_sec", DEFAULT_DELAY_SEC))
	delay_sec = max(MIN_DELAY_SEC, delay_sec)
	stop_countdown()
	has_started_first_wave = false

func reset() -> void:
	enabled = DEFAULT_ENABLED
	delay_sec = DEFAULT_DELAY_SEC
	remaining = 0.0
	countdown_active = false
	has_started_first_wave = false

func mark_first_wave_started() -> void:
	has_started_first_wave = true

func is_waiting_for_manual_first_wave(next_wave_number: int, wave_running: bool) -> bool:
	return not has_started_first_wave and next_wave_number == 1 and not wave_running

func stop_countdown() -> void:
	countdown_active = false
	remaining = 0.0

func maybe_start_countdown(can_auto_countdown: bool, manual_first_wave: bool) -> void:
	if not enabled:
		stop_countdown()
		return
	if not can_auto_countdown:
		stop_countdown()
		return
	if manual_first_wave:
		stop_countdown()
		return
	if countdown_active:
		return
	remaining = delay_sec
	countdown_active = true

func tick(delta: float, can_auto_countdown: bool, paused: bool) -> bool:
	if not countdown_active:
		return false
	if paused:
		return false
	if not can_auto_countdown:
		stop_countdown()
		return false

	remaining -= delta
	if remaining <= 0.0:
		remaining = 0.0
		countdown_active = false
		return true
	return false

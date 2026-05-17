class_name CombatAudioService
extends Node

const _Config = preload("res://scripts/services/combat_audio_config.gd")
const _PoolScript = preload("res://scripts/services/audio_player_pool.gd")

var _audio_manager: Node = null
var _pool = null  # AudioPlayerPool instance

# Seconds elapsed since each sfx_type was last played.
# Default look-up returns the cooldown value itself so the first play always passes.
var _cooldown_elapsed: Dictionary = {}

# How many pool players are currently playing each sfx_type.
var _sim_counts: Dictionary = {}

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

func setup(audio_manager: Node) -> void:
	_audio_manager = audio_manager
	_pool = _PoolScript.new()
	_pool.name = "CombatAudioPool"
	add_child(_pool)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func play_tower_sfx(sfx_type: String, world_pos: Vector2, priority_override: int = -1) -> void:
	_play(sfx_type, priority_override)

func play_combat_event_sfx(sfx_type: String, world_pos: Vector2, priority_override: int = -1) -> void:
	_play(sfx_type, priority_override)

# Stubs — reserved for future looping/fade-channel support (flame streams, beams, etc.)
func start_loop(_loop_key: String, _sfx_type: String, _world_pos: Vector2) -> void:
	pass

func update_loop_position(_loop_key: String, _world_pos: Vector2) -> void:
	pass

func stop_loop(_loop_key: String, _fade_time: float = 0.15) -> void:
	pass

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _play(sfx_type: String, priority_override: int) -> void:
	var priority: int = priority_override if priority_override >= 0 \
		else _Config.SFX_PRIORITIES.get(sfx_type, _Config.DEFAULT_PRIORITY)

	# High-priority sounds skip throttle and simultaneous checks.
	if priority < _Config.PRIORITY_HIGH:
		# Cooldown gate
		var cooldown: float = _Config.COOLDOWNS.get(sfx_type, 0.0)
		if cooldown > 0.0:
			var elapsed: float = _cooldown_elapsed.get(sfx_type, cooldown)
			if elapsed < cooldown:
				return

		# Per-type simultaneous cap
		var max_sim: int = _Config.MAX_SIMULTANEOUS.get(sfx_type, 0)
		if max_sim > 0 and _sim_counts.get(sfx_type, 0) >= max_sim:
			return

	var player: AudioStreamPlayer = _pool.acquire()
	if player == null:
		if priority < _Config.PRIORITY_NORMAL:
			return
		# Important sounds are still dropped when the pool is fully busy.
		# A future enhancement could evict the oldest low-priority player here.
		return

	var stream := _get_stream(sfx_type)
	if stream == null:
		return

	# Pitch variation
	var pitch_var: float = _Config.PITCH_VARIATION.get(sfx_type, 0.0)
	if pitch_var > 0.0:
		player.pitch_scale = clampf(1.0 + randf_range(-pitch_var, pitch_var), 0.5, 2.0)
	else:
		player.pitch_scale = 1.0

	# Volume: base variation + adaptive reduction for busy pool
	var vol_db := 0.0
	var vol_var: float = _Config.VOLUME_VARIATION_DB.get(sfx_type, 0.0)
	if vol_var > 0.0:
		vol_db += randf_range(-vol_var, vol_var)

	if priority < _Config.PRIORITY_HIGH:
		var active: int = _pool.active_count()
		# Walk from most-severe tier downward; take the first (worst) match.
		var steps: Array = _Config.ADAPTIVE_STEPS
		for i in range(steps.size() - 1, -1, -1):
			if active >= steps[i][0]:
				vol_db += steps[i][1]
				break

	player.volume_db = clampf(vol_db, -20.0, 6.0)
	player.stream = stream
	player.play()

	_cooldown_elapsed[sfx_type] = 0.0
	_sim_counts[sfx_type] = _sim_counts.get(sfx_type, 0) + 1
	player.finished.connect(_on_finished.bind(sfx_type), CONNECT_ONE_SHOT)

func _on_finished(sfx_type: String) -> void:
	_sim_counts[sfx_type] = maxi(0, _sim_counts.get(sfx_type, 0) - 1)

func _process(delta: float) -> void:
	for key in _cooldown_elapsed:
		_cooldown_elapsed[key] += delta

func _get_stream(sfx_type: String) -> AudioStream:
	if _audio_manager == null:
		return null
	if _audio_manager.has_method("_get_sfx_stream"):
		return _audio_manager._get_sfx_stream(sfx_type)
	return null

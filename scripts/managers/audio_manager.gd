extends Node

signal audio_settings_changed()

@export var debug_audio_enabled: bool = false

# Audio Bus Names
const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

var sfx_paths: Dictionary = {
	"ui_click": "res://assets/audio/sfx/ui_click",
	"start_wave": "res://assets/audio/sfx/start_wave",
	"tower_place": "res://assets/audio/sfx/tower_place",
	"tower_upgrade": "res://assets/audio/sfx/tower_upgrade",
	"tower_shoot_basic": "res://assets/audio/sfx/tower_shoot_basic",
	"tower_shoot_rapid": "res://assets/audio/sfx/tower_shoot_rapid",
	"tower_shoot_cannon": "res://assets/audio/sfx/tower_shoot_cannon",
	"tower_shoot_slow": "res://assets/audio/sfx/tower_shoot_slow",
	"tower_shoot_sniper": "res://assets/audio/sfx/tower_shoot_basic", # TODO: Re-check asset if dedicated exists
	"tower_shoot_sawblade": "res://assets/audio/sfx/tower_shoot_rapid", # TODO: Re-check asset if dedicated exists
	"projectile_hit": "res://assets/audio/sfx/projectile_hit",
	"splash_hit": "res://assets/audio/sfx/splash_hit",
	"enemy_die": "res://assets/audio/sfx/enemy_die",
	"enemy_reach_base": "res://assets/audio/sfx/enemy_reach_base",
	"gold_gain": "res://assets/audio/sfx/gold_gain",
	"game_over": "res://assets/audio/sfx/game_over",
	"victory": "res://assets/audio/sfx/victory",
	"pause": "res://assets/audio/sfx/pause",
	"resume": "res://assets/audio/sfx/resume"
}

var music_paths: Dictionary = {
	"menu": "res://assets/audio/music/menu_theme",
	"gameplay": "res://assets/audio/music/gameplay_theme"
}

# Category extension priorities
var sfx_extensions: Array[String] = [".wav", ".ogg", ".mp3"]
var music_extensions: Array[String] = [".ogg", ".wav", ".mp3"]

# Resolved paths after startup
var resolved_sfx: Dictionary = {}
var resolved_music: Dictionary = {}

# Web Audio Unlock
var audio_unlocked: bool = false
var pending_music_name: String = ""
var current_music_name: String = ""

# Volume settings
var master_volume: float = 0.8
var music_volume: float = 0.6
var sfx_volume: float = 0.8
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

var sfx_cache: Dictionary = {}
var music_cache: Dictionary = {}

var music_player: AudioStreamPlayer
var warned_missing: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Web audio starts locked
	if not OS.has_feature("web"):
		audio_unlocked = true
	else:
		if OS.is_debug_build(): print("[AudioManager] Web detected. Audio locked until user gesture.")
	
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	
	# Create Music Player
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	music_player.autoplay = false
	add_child(music_player)
	
	_resolve_all_paths()
	_preload_assets()

func unlock_audio() -> void:
	if audio_unlocked: return
	
	audio_unlocked = true
	if OS.is_debug_build(): print("[AudioManager] Audio UNLOCKED via user gesture.")
	
	# Play a small click to confirm unlock
	play_sfx("ui_click")
	
	# Diagnostics
	print_bus_diagnostics()
	
	# Resume pending music
	if pending_music_name != "":
		if OS.is_debug_build(): print("[AudioManager] Playing pending music: ", pending_music_name)
		play_music(pending_music_name)
		pending_music_name = ""
	else:
		# Default to menu if nothing pending
		play_music("menu")

func print_bus_diagnostics() -> void:
	if OS.is_debug_build(): print("--- Audio Bus Diagnostics ---")
	var buses = [BUS_MASTER, BUS_MUSIC, BUS_SFX]
	for bus in buses:
		var idx = AudioServer.get_bus_index(bus)
		if idx != -1:
			var vol = AudioServer.get_bus_volume_db(idx)
			var mute = AudioServer.is_bus_mute(idx)
			var send = AudioServer.get_bus_send(idx)
			if OS.is_debug_build(): print("Bus [%s] index=%d vol=%.2fdb mute=%s send=%s" % [bus, idx, vol, mute, send])
		else:
			if OS.is_debug_build(): print("Bus [%s] NOT FOUND" % bus)
	if OS.is_debug_build(): print("-----------------------------")

func reset_to_defaults() -> void:
	if OS.is_debug_build(): print("[AudioManager] Resetting audio to defaults...")
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 0.8
	master_muted = false
	music_muted = false
	sfx_muted = false
	_apply_audio_settings()
	audio_settings_changed.emit()
	print_bus_diagnostics()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		# Route Music and SFX to Master by default
		if bus_name != BUS_MASTER:
			AudioServer.set_bus_send(index, BUS_MASTER)

func find_audio_file(base_path: String, extensions: Array[String] = []) -> String:
	if base_path.contains("."):
		if ResourceLoader.exists(base_path) or FileAccess.file_exists(base_path):
			return base_path
	
	var search_extensions := extensions
	if search_extensions.is_empty():
		search_extensions = [".wav", ".ogg", ".mp3"]
		
	for ext in search_extensions:
		var full_path = base_path + ext
		if ResourceLoader.exists(full_path) or FileAccess.file_exists(full_path):
			return full_path
	return ""

func play_direct_asset_test(path: String, bus_name: String = "Master") -> void:
	if OS.is_debug_build(): print("[AudioManager] direct asset test path=", path)

	if not ResourceLoader.exists(path):
		if OS.is_debug_build(): print("[AudioManager] direct asset missing: ", path)
		return

	var stream := load(path)
	if stream == null:
		if OS.is_debug_build(): print("[AudioManager] direct asset load FAILED: ", path)
		return
		
	if OS.is_debug_build(): print("[AudioManager] direct stream=", stream, " class=", stream.get_class())
	if stream is AudioStreamWAV:
		if OS.is_debug_build(): print("[AudioManager] WAV info: mix_rate=%d stereo=%s format=%d data_size=%d" % [stream.mix_rate, stream.stereo, stream.format, stream.data.size()])

	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.volume_db = 6.0 # Force loud for testing
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()

	if OS.is_debug_build(): print("[AudioManager] direct playing=", player.playing, " bus=", player.bus, " vol=", player.volume_db)

	await get_tree().create_timer(2.0).timeout
	player.queue_free()

func play_generated_sfx(type: String) -> void:
	if OS.is_debug_build(): print("[AudioManager] Generated SFX fallback: ", type)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.2
	
	var player := AudioStreamPlayer.new()
	player.bus = BUS_MASTER
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()
	
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback:
		var frames := int(44100 * 0.15)
		var freq := 880.0
		if type == "tower_place": freq = 440.0
		elif type == "victory": freq = 1320.0
		elif type == "game_over": freq = 220.0
		
		for i in range(frames):
			var t := float(i) / 44100.0
			var sample := sin(TAU * freq * t) * 0.3
			# Simple decay
			sample *= (1.0 - float(i)/frames)
			playback.push_frame(Vector2(sample, sample))
			
	await get_tree().create_timer(0.3).timeout
	player.queue_free()

func _resolve_all_paths() -> void:
	if debug_audio_enabled:
		if OS.is_debug_build(): print("[AudioManager] SFX extension priority: ", sfx_extensions)
		if OS.is_debug_build(): print("[AudioManager] Music extension priority: ", music_extensions)
		if OS.is_debug_build(): print("[AudioManager] Resolving audio paths category-wise...")
	
	for key in sfx_paths:
		var resolved = find_audio_file(sfx_paths[key], sfx_extensions)
		if resolved != "": 
			resolved_sfx[key] = resolved
			if debug_audio_enabled:
				if OS.is_debug_build(): print("[AudioManager] SFX %s resolved to: %s" % [key, resolved])
			
	for key in music_paths:
		var resolved = find_audio_file(music_paths[key], music_extensions)
		if resolved != "": 
			resolved_music[key] = resolved
			if debug_audio_enabled:
				if OS.is_debug_build(): print("[AudioManager] Music %s resolved to: %s" % [key, resolved])
			
	if OS.is_debug_build(): print("[AudioManager] Assets Resolved: SFX=%d Music=%d" % [resolved_sfx.keys().size(), resolved_music.keys().size()])

func play_generated_test_tone() -> void:
	if OS.is_debug_build(): print("[AudioManager] Hard Audio Test: generating tone...")
	if OS.is_debug_build(): print("[AudioManager] audio_unlocked=", audio_unlocked)
	
	var master_idx = AudioServer.get_bus_index(BUS_MASTER)
	if master_idx != -1:
		if OS.is_debug_build(): print("[AudioManager] Master bus: vol=%.2fdb mute=%s" % [AudioServer.get_bus_volume_db(master_idx), AudioServer.is_bus_mute(master_idx)])

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100.0
	stream.buffer_length = 0.5

	var player := AudioStreamPlayer.new()
	player.bus = BUS_MASTER # Direct to Master
	player.volume_db = 0.0
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()
	
	if debug_audio_enabled:
		if OS.is_debug_build(): print("[AudioManager] Hard Audio Test: player.playing=", player.playing)

	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		if OS.is_debug_build(): print("[AudioManager] Hard Audio Test failed: no playback (check if bus is active)")
		player.queue_free()
		return

	var frames := int(44100 * 0.35)
	var freq := 880.0 # A5 note

	for i in range(frames):
		var t := float(i) / 44100.0
		var sample := sin(TAU * freq * t) * 0.35
		playback.push_frame(Vector2(sample, sample))

	if debug_audio_enabled:
		if OS.is_debug_build(): print("[AudioManager] Hard Audio Test: tone pushed to buffer.")
	
	await get_tree().create_timer(0.6).timeout
	player.queue_free()

func play_sfx(name: String, force: bool = false) -> void:
	if OS.has_feature("web") and not audio_unlocked:
		if force: if OS.is_debug_build(): print("[AudioManager] play_sfx blocked before unlock: ", name)
		return

	if not resolved_sfx.has(name):
		var base = sfx_paths.get(name, "")
		if base != "":
			var found = find_audio_file(base, sfx_extensions)
			if found != "": resolved_sfx[name] = found
			else: 
				if force: if OS.is_debug_build(): print("[AudioManager] SFX file not found for: ", name)
				return
		else: 
			if force: if OS.is_debug_build(): print("[AudioManager] Unknown SFX key: ", name)
			return
	
	var stream = _get_sfx_stream(name)
	if stream == null: 
		if force: if OS.is_debug_build(): print("[AudioManager] Failed to get SFX stream for: ", name)
		return
		
	if OS.has_feature("web"):
		var path = resolved_sfx.get(name, "")
		_play_web_one_shot(stream, BUS_SFX, 6.0 if force else 0.0, name, path, force)
		return

	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.bus = BUS_SFX
	add_child(sfx_player)
	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
	
	if force:
		if OS.is_debug_build(): print("[AudioManager] FORCE play_sfx name=%s path=%s stream=%s class=%s playing=%s" % 
			[name, stream.resource_path, stream, stream.get_class(), sfx_player.playing])

func _play_web_one_shot(
	stream: AudioStream,
	bus_name: String,
	volume_db: float,
	label: String,
	path: String,
	force: bool = false
) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	player.volume_db = volume_db
	player.stream = stream
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()

	if OS.is_debug_build(): print("[AudioManager] WEB one-shot label=%s path=%s class=%s bus=%s vol=%.1f playing=%s" % 
		[label, path, stream.get_class(), player.bus, player.volume_db, player.playing])
	
	if force:
		print_bus_diagnostics()

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(player):
		player.queue_free()

func play_sfx_on_bus(name: String, bus_name: String) -> void:
	if OS.is_debug_build(): print("[AudioManager] play_sfx_on_bus name=%s bus=%s" % [name, bus_name])
	var stream = _get_sfx_stream(name)
	if stream:
		var path = resolved_sfx.get(name, "")
		_play_web_one_shot(stream, bus_name, 6.0, name, path, true)


func _get_sfx_stream(name: String) -> AudioStream:
	if sfx_cache.has(name): return sfx_cache[name]
	var path = resolved_sfx.get(name, "")
	if path == "": 
		if OS.is_debug_build(): print("[AudioManager] _get_sfx_stream missing path for: ", name)
		return null
	var stream = load(path)
	if stream:
		sfx_cache[name] = stream
		return stream
	if OS.is_debug_build(): print("[AudioManager] _get_sfx_stream failed to load path: ", path)
	return null

func play_music(name: String, force: bool = false) -> void:
	if OS.has_feature("web") and not audio_unlocked:
		pending_music_name = name
		if OS.is_debug_build(): print("[AudioManager] play_music deferred before unlock: ", name)
		return

	if not resolved_music.has(name):
		var base = music_paths.get(name, "")
		if base != "":
			var found = find_audio_file(base, music_extensions)
			if found != "": resolved_music[name] = found
			else: 
				if force: if OS.is_debug_build(): print("[AudioManager] Music file not found for: ", name)
				return
		else: 
			if force: if OS.is_debug_build(): print("[AudioManager] Unknown Music key: ", name)
			return
	
	var stream = _get_music_stream(name)
	if stream == null:
		if force: if OS.is_debug_build(): print("[AudioManager] Failed to get Music stream for: ", name)
		music_player.stop()
		return
		
	if not force and music_player.stream == stream and music_player.playing:
		return
		
	# Ensure looping is enabled for music
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		
	music_player.stop()
	music_player.bus = BUS_MUSIC
	music_player.volume_db = 0.0
	music_player.stream = stream
	music_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	music_player.play()
	current_music_name = name
	
	if force:
		if OS.is_debug_build(): print("[AudioManager] FORCE play_music name=%s path=%s stream=%s class=%s playing=%s" % 
			[name, stream.resource_path, stream, stream.get_class(), music_player.playing])
		print_bus_diagnostics()
	elif debug_audio_enabled:
		if OS.is_debug_build(): print("[AudioManager] Music playing: %s stream=%s class=%s bus=%s vol=%.2f playing=%s" % 
			[name, stream.resource_path, stream.get_class(), music_player.bus, music_player.volume_db, music_player.playing])
	
	if OS.has_feature("web"):
		if debug_audio_enabled:
			if OS.is_debug_build(): print("[AudioManager] Web audio_unlocked=", audio_unlocked)

func play_music_fallback_test() -> void:
	if OS.is_debug_build(): print("[AudioManager] Running Music Fallback Test (ui_click through MusicPlayer)...")
	var stream = _get_sfx_stream("ui_click")
	if stream == null:
		if OS.is_debug_build(): print("[AudioManager] Fallback test FAILED: ui_click stream null")
		return
		
	music_player.stream = stream
	music_player.play()
	if OS.is_debug_build(): print("[AudioManager] Fallback Test: stream=%s bus=%s vol=%.2f playing=%s" % 
		[stream.resource_path, music_player.bus, music_player.volume_db, music_player.playing])

func _get_music_stream(name: String) -> AudioStream:
	if music_cache.has(name): return music_cache[name]
	var path = resolved_music.get(name, "")
	if path == "": 
		if OS.is_debug_build(): print("[AudioManager] _get_music_stream missing path for: ", name)
		return null
	var stream = load(path)
	if stream:
		music_cache[name] = stream
		return stream
	if OS.is_debug_build(): print("[AudioManager] _get_music_stream failed to load path: ", path)
	return null

func stop_music() -> void:
	music_player.stop()

# --- Audio Settings ---

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	audio_settings_changed.emit()

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	audio_settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	audio_settings_changed.emit()

func set_master_muted(value: bool) -> void:
	master_muted = value
	_apply_audio_settings()
	audio_settings_changed.emit()

func set_music_muted(value: bool) -> void:
	music_muted = value
	_apply_audio_settings()
	audio_settings_changed.emit()

func set_sfx_muted(value: bool) -> void:
	sfx_muted = value
	_apply_audio_settings()
	audio_settings_changed.emit()

func _volume_to_db(value: float) -> float:
	return linear_to_db(clamp(value, 0.0, 1.0))

func _apply_audio_settings() -> void:
	var master_index := AudioServer.get_bus_index(BUS_MASTER)
	var music_index := AudioServer.get_bus_index(BUS_MUSIC)
	var sfx_index := AudioServer.get_bus_index(BUS_SFX)

	if master_index != -1:
		AudioServer.set_bus_volume_db(master_index, _volume_to_db(master_volume))
		AudioServer.set_bus_mute(master_index, master_muted)

	if music_index != -1:
		AudioServer.set_bus_volume_db(music_index, _volume_to_db(music_volume))
		AudioServer.set_bus_mute(music_index, music_muted)

	if sfx_index != -1:
		AudioServer.set_bus_volume_db(sfx_index, _volume_to_db(sfx_volume))
		AudioServer.set_bus_mute(sfx_index, sfx_muted)

func get_settings() -> Dictionary:
	return {
		"master_volume": master_volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"master_muted": master_muted, "music_muted": music_muted, "sfx_muted": sfx_muted
	}

func apply_settings(settings: Dictionary) -> void:
	master_volume = float(settings.get("master_volume", master_volume))
	sfx_volume = float(settings.get("sfx_volume", sfx_volume))
	music_volume = float(settings.get("music_volume", music_volume))
	master_muted = bool(settings.get("master_muted", master_muted))
	sfx_muted = bool(settings.get("sfx_muted", sfx_muted))
	music_muted = bool(settings.get("music_muted", music_muted))
	_apply_audio_settings()
	audio_settings_changed.emit()

func _preload_assets() -> void: pass

func _warn_missing(key: String) -> void:
	if not warned_missing.has(key):
		warned_missing[key] = true
		if OS.is_debug_build(): print("[AudioManager] Warning: ", key)

func _linear_to_db(linear: float) -> float: return linear_to_db(linear)
func _db_to_linear(db: float) -> float: return db_to_linear(db)

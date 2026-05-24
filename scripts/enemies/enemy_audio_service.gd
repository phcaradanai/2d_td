class_name EnemyAudioService
extends RefCounted

# Minimum milliseconds between plays of each sound key (throttle)
const THROTTLE_MS: Dictionary = {
	"enemy_spawn":      350,
	"enemy_die_light":  80,
	"enemy_die_medium": 80,
	"enemy_die_heavy":  150,
	"enemy_die_flyer":  80,
	"enemy_die_boss":   0,
	"enemy_heal":       3000,
	"enemy_shield":     2000,
	"enemy_split":      0,
	"enemy_cloak":      2000,
	"enemy_disrupt":    1500,
	"enemy_dash":       600,
}

static var _last_play_ms: Dictionary = {}

static func _get_audio(enemy: Node2D) -> Node:
	return enemy.get_tree().current_scene.get_node_or_null("AudioManager")

static func play(enemy: Node2D, sfx_key: String) -> void:
	var min_ms: int = THROTTLE_MS.get(sfx_key, 0)
	if min_ms > 0:
		var now := Time.get_ticks_msec()
		var last: int = _last_play_ms.get(sfx_key, 0)
		if now - last < min_ms:
			return
		_last_play_ms[sfx_key] = now
	var audio := _get_audio(enemy)
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_key)

static func play_death(enemy: Node2D) -> void:
	var sfx_key: String
	if enemy.tags.has("boss"):
		sfx_key = "enemy_die_boss"
	elif enemy.get("category") == "air" or enemy.tags.has("air"):
		sfx_key = "enemy_die_flyer"
	elif enemy.tags.has("heavy") or enemy.tags.has("shield") or enemy.tags.has("frontline"):
		sfx_key = "enemy_die_heavy"
	elif enemy.tags.has("fast") or enemy.tags.has("swarm") or enemy.tags.has("small"):
		sfx_key = "enemy_die_light"
	else:
		sfx_key = "enemy_die_medium"
	play(enemy, sfx_key)

static func play_spawn(enemy: Node2D) -> void:
	play(enemy, "enemy_spawn")

static func play_movement(enemy: Node2D) -> void:
	var now := Time.get_ticks_msec()

	if enemy.tags.has("air"):
		# Wing beat: sync to visual wing-tilt cycle (sin(pulse_time * 4.0), period ≈ 1.57s)
		_play_cycle_synced(enemy, "enemy_wing", enemy.get("pulse_time"), TAU / 4.0, now, "sfx_wing_cycle", 400)
	elif enemy.tags.has("swarm"):
		# Bob bounce: sync to visual bob cycle (sin(pulse_time * 4.2), period ≈ 1.50s)
		_play_cycle_synced(enemy, "enemy_bounce", enemy.get("pulse_time"), TAU / 4.2, now, "sfx_bob_cycle", 400)
	elif enemy.tags.has("boss"):
		_play_footstep(enemy, "enemy_step_boss", 1000, now)
	elif enemy.tags.has("heavy") or enemy.tags.has("shield") or enemy.tags.has("frontline"):
		_play_footstep(enemy, "enemy_step_heavy", 1200, now)

static func _play_cycle_synced(enemy: Node2D, sfx_key: String, pulse_time: Variant,
		period: float, now: int, meta_key: String, global_min_ms: int) -> void:
	if not pulse_time is float and not pulse_time is int:
		return
	var t := float(pulse_time)
	var last_t: float = enemy.get_meta(meta_key, -1.0)
	# Detect wrap-around = one full cycle completed
	var did_cycle := last_t >= 0.0 and fmod(t, period) < fmod(last_t, period)
	enemy.set_meta(meta_key, t)
	if not did_cycle:
		return
	# Global cap so many air enemies don't flood at once
	var global_key := sfx_key + "_global"
	var global_last: int = _last_play_ms.get(global_key, 0)
	if now - global_last < global_min_ms:
		return
	_last_play_ms[global_key] = now
	var audio := _get_audio(enemy)
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_key)

static func _play_footstep(enemy: Node2D, sfx_key: String, per_enemy_ms: int, now: int) -> void:
	const META_KEY := "sfx_step_last_ms"
	var last: int = enemy.get_meta(META_KEY, 0)
	if now - last < per_enemy_ms:
		return
	enemy.set_meta(META_KEY, now)
	var global_last: int = _last_play_ms.get("step_global", 0)
	if now - global_last < 150:
		return
	_last_play_ms["step_global"] = now
	var audio := _get_audio(enemy)
	if audio and audio.has_method("play_sfx"):
		audio.play_sfx(sfx_key)

static func play_dash(enemy: Node2D) -> void:
	play(enemy, "enemy_dash")

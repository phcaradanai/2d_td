class_name AudioPlayerPool
extends Node

const _Config = preload("res://scripts/services/combat_audio_config.gd")

var _pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
	for i in range(_Config.POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)

# Returns a free player, or null if the pool is exhausted.
func acquire() -> AudioStreamPlayer:
	for player in _pool:
		if not player.playing:
			return player
	return null

func active_count() -> int:
	var n := 0
	for player in _pool:
		if player.playing:
			n += 1
	return n

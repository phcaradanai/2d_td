extends Node

var repo: Node = null

func _ready() -> void:
	# For now, we use the local repository
	# In the future, this can be swapped with a RemoteLeaderboardRepository
	repo = load("res://scripts/core/local_leaderboard_repo.gd").new()
	add_child(repo)

func submit_score(level_id: String, summary: Dictionary, player_name: String) -> int:
	var entry = {
		"player_name": player_name,
		"score": summary.get("score", 0),
		"stars": summary.get("stars", 0),
		"perfect_clear": summary.get("is_perfect", false),
		"clear_time": summary.get("clear_time", 0),
		"created_at": Time.get_datetime_dict_from_system()
	}
	
	if OS.is_debug_build():
		print("[LeaderboardService] Submitting score for %s on %s" % [player_name, level_id])
		
	return repo.submit_entry(level_id, entry)

func get_top_scores(level_id: String) -> Array:
	return repo.get_top_entries(level_id)

func clear_local_data() -> void:
	if repo:
		repo.clear_all()

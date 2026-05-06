extends Node

const SAVE_PATH = "user://leaderboards.json"

# level_id: Array of entries
# Entry: {player_name, score, stars, perfect_clear, clear_time, created_at}
var leaderboard_data: Dictionary = {}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		leaderboard_data = {}
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error == OK:
		leaderboard_data = json.data
		if OS.is_debug_build(): print("[LocalLeaderboard] Data loaded.")
	else:
		push_error("[LocalLeaderboard] JSON Parse Error: " + json.get_error_message())

func save_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_text = JSON.stringify(leaderboard_data, "\t")
	file.store_string(json_text)
	file.close()
	if OS.is_debug_build(): print("[LocalLeaderboard] Data saved.")

func submit_entry(level_id: String, entry: Dictionary) -> int:
	if not leaderboard_data.has(level_id):
		leaderboard_data[level_id] = []
		
	var entries = leaderboard_data[level_id]
	entries.append(entry)
	
	# Sort: Score (Desc) > Stars (Desc) > Clear Time (Asc)
	entries.sort_custom(func(a, b):
		if a.score != b.score:
			return a.score > b.score
		if a.stars != b.stars:
			return a.stars > b.stars
		return a.clear_time < b.clear_time
	)
	
	# Keep only top 10
	if entries.size() > 10:
		entries.resize(10)
		
	save_data()
	
	# Find rank (1-indexed)
	for i in range(entries.size()):
		var e = entries[i]
		if e.player_name == entry.player_name and e.score == entry.score and e.clear_time == entry.clear_time and e.created_at == entry.created_at:
			return i + 1
			
	return -1 # Not in top 10

func get_top_entries(level_id: String) -> Array:
	if leaderboard_data.has(level_id):
		return leaderboard_data[level_id]
	return []

func clear_all() -> void:
	leaderboard_data = {}
	save_data()

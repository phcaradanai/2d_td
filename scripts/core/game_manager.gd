extends Node

signal gold_changed(new_gold: int)
signal lives_changed(new_lives: int)
signal wave_changed(current_wave: int)
signal score_changed(new_score: int)
signal game_over()
signal victory()
signal game_paused()
signal game_resumed()
signal wave_rewarded(amount: int)

@export var starting_gold: int = 120
@export var starting_lives: int = 20

func apply_level_config(p_gold: int, p_lives: int) -> void:
	starting_gold = p_gold
	starting_lives = p_lives
	# High visibility log for level switching audit
	print(">>> [GameManager] APPLY CONFIG: starting_gold=%d, starting_lives=%d" % [starting_gold, starting_lives])

# Legacy alias for backward compatibility if needed, but we should use apply_level_config
func set_starting_stats(p_gold: int, p_lives: int) -> void:
	apply_level_config(p_gold, p_lives)

var gold: int = 0
var lives: int = 0
var current_wave: int = 0
var score: int = 0

# Stats for summary
var enemies_killed: int = 0
var enemies_leaked: int = 0
var gold_earned: int = 0
var gold_spent: int = 0
var waves_completed: int = 0

var is_game_over: bool = false
var is_victory: bool = false
var is_paused: bool = false
var debug_god_mode: bool = false
var session_start_time: int = 0
var clear_time_seconds: int = 0

func _ready() -> void:
	reset_game()

func reset_game() -> void:
	reset_runtime_state()

func reset_runtime_state() -> void:
	gold = starting_gold
	lives = starting_lives
	current_wave = 0
	score = 0
	
	enemies_killed = 0
	enemies_leaked = 0
	gold_earned = starting_gold
	gold_spent = 0
	waves_completed = 0
	
	session_start_time = 0
	clear_time_seconds = 0
	
	is_game_over = false
	is_victory = false
	is_paused = false
	
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(current_wave)
	score_changed.emit(score)
	
	if OS.is_debug_build(): 
		print("[GameManager] reset_runtime_state: gold=", gold, " lives=", lives)

func start_timer() -> void:
	if session_start_time == 0:
		session_start_time = Time.get_ticks_msec()
		if OS.is_debug_build(): print("[GameManager] Timer started")

func stop_timer() -> void:
	if session_start_time > 0 and clear_time_seconds == 0:
		clear_time_seconds = (Time.get_ticks_msec() - session_start_time) / 1000
		if OS.is_debug_build(): print("[GameManager] Timer stopped: %d seconds" % clear_time_seconds)

func add_gold(amount: int) -> void:
	if is_game_over: return
	gold += amount
	gold_earned += amount
	gold_changed.emit(gold)

func award_wave_completion(amount: int) -> void:
	if amount <= 0: return
	if is_game_over: return
	
	gold += amount
	gold_earned += amount
	waves_completed += 1
	
	# Score for wave completion
	add_score(amount * 5)
	
	gold_changed.emit(gold)
	wave_rewarded.emit(amount)
	if OS.is_debug_build(): print("[GameManager] Wave reward: +", amount, " Gold")

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		if OS.is_debug_build(): print("[Economy] spend gold amount=%d gold_before=%d gold_after=%d" % [amount, gold, gold - amount])
		gold -= amount
		gold_spent += amount
		gold_changed.emit(gold)
		return true
	if OS.is_debug_build(): print("[Economy] spend failed: not enough gold! (has %d, need %d)" % [gold, amount])
	return false

func damage_base(amount: int) -> void:
	if is_game_over or is_victory: return
	
	if debug_god_mode:
		if OS.is_debug_build(): print("[Debug] God Mode: Blocked ", amount, " base damage.")
		return
		
	lives -= amount
	enemies_leaked += 1
	
	if lives < 0: lives = 0
	lives_changed.emit(lives)
	
	if lives <= 0:
		trigger_game_over()

func set_current_wave(wave_number: int) -> void:
	current_wave = wave_number
	wave_changed.emit(current_wave)
	if wave_number == 1:
		start_timer()

func add_kill_score(enemy_reward: int) -> void:
	enemies_killed += 1
	add_score(enemy_reward * 10)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func calculate_final_score(total_waves: int = 0) -> int:
	# New formula based on requirements:
	# Base clear score: 1000 if level cleared
	# Remaining lives bonus: lives * 50
	# Remaining gold bonus: gold * 2
	# Wave clear bonus: waves_completed * 100 (using waves_completed which is incremented in award_wave_completion)
	# Perfect clear bonus: +1000 if no lives were lost
	
	var final_score = 0
	
	# Wave clear bonus (always awarded for completed waves)
	final_score += waves_completed * 100
	
	if is_victory:
		final_score += 1000 # Base clear score
		if lives >= starting_lives:
			final_score += 1000 # Perfect clear bonus
			
	final_score += lives * 50
	final_score += gold * 2
	
	if OS.is_debug_build():
		print("[ScoreSystem] level cleared=%s score=%d" % [str(is_victory), final_score])
		
	if final_score < 0: final_score = 0
	return final_score

func calculate_stars(total_waves: int = 0) -> int:
	# 3 stars: level cleared and perfect clear (no lives lost)
	# 2 stars: level cleared but lives were lost
	# 1 star: level failed but player cleared at least 50% of waves
	# 0 stars: level failed early
	
	if is_victory:
		if lives >= starting_lives:
			return 3
		return 2
	else:
		if total_waves > 0 and float(waves_completed) / float(total_waves) >= 0.5:
			return 1
		return 0

func get_run_summary(total_waves: int = 0) -> Dictionary:
	var final_score = calculate_final_score(total_waves)
	var stars = calculate_stars(total_waves)
	var is_perfect = is_victory and (lives >= starting_lives)
	
	if OS.is_debug_build():
		print("[ScoreSystem] stars=%d perfect_clear=%s" % [stars, str(is_perfect)])
		
	return {
		"result": "Victory" if is_victory else "Game Over",
		"score": final_score,
		"stars": stars,
		"is_perfect": is_perfect,
		"clear_time": clear_time_seconds,
		"lives": lives,
		"starting_lives": starting_lives,
		"enemies_killed": enemies_killed,
		"enemies_leaked": enemies_leaked,
		"gold_earned": gold_earned,
		"gold_spent": gold_spent,
		"gold_remaining": gold,
		"waves_completed": waves_completed,
		"total_waves": total_waves
	}

func trigger_game_over() -> void:
	if is_game_over: return
	is_game_over = true
	stop_timer()
	game_over.emit()
	if OS.is_debug_build(): print("Game Over triggered!")

func trigger_victory() -> void:
	if is_victory or is_game_over: return
	is_victory = true
	stop_timer()
	victory.emit()
	if OS.is_debug_build(): print("Victory triggered!")

func pause_game() -> void:
	if is_game_over or is_victory: return
	if is_paused: return
	
	is_paused = true
	get_tree().paused = true
	game_paused.emit()
	if OS.is_debug_build(): print("[GameManager] engine pause ON")

func resume_game() -> void:
	if not is_paused: return
	
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()
	if OS.is_debug_build(): print("[GameManager] engine pause OFF")

func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()

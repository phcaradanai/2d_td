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

func set_starting_stats(p_gold: int, p_lives: int) -> void:
	starting_gold = p_gold
	starting_lives = p_lives

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

func _ready() -> void:
	reset_game()

func reset_game() -> void:
	gold = starting_gold
	lives = starting_lives
	current_wave = 0
	score = 0
	
	enemies_killed = 0
	enemies_leaked = 0
	gold_earned = starting_gold
	gold_spent = 0
	waves_completed = 0
	
	is_game_over = false
	is_victory = false
	is_paused = false
	
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(current_wave)
	score_changed.emit(score)

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
		gold -= amount
		gold_spent += amount
		gold_changed.emit(gold)
		return true
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

func add_kill_score(enemy_reward: int) -> void:
	enemies_killed += 1
	add_score(enemy_reward * 10)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func calculate_final_score() -> int:
	# Base score is already tracked via add_score during kills and waves
	# Add bonuses at the end
	var final_score = score
	final_score += lives * 50
	final_score += gold * 2
	final_score -= enemies_leaked * 25
	
	if final_score < 0: final_score = 0
	return final_score

func calculate_stars() -> int:
	if not is_victory:
		return 0
	
	var ratio = float(lives) / float(starting_lives)
	if ratio >= 0.75:
		return 3
	if ratio >= 0.4:
		return 2
	return 1

func get_run_summary() -> Dictionary:
	var final_score = calculate_final_score()
	var stars = calculate_stars()
	
	return {
		"result": "Victory" if is_victory else "Game Over",
		"score": final_score,
		"stars": stars,
		"lives": lives,
		"starting_lives": starting_lives,
		"enemies_killed": enemies_killed,
		"enemies_leaked": enemies_leaked,
		"gold_earned": gold_earned,
		"gold_spent": gold_spent,
		"gold_remaining": gold,
		"waves_completed": waves_completed
	}

func trigger_game_over() -> void:
	if is_game_over: return
	is_game_over = true
	game_over.emit()
	if OS.is_debug_build(): print("Game Over triggered!")

func trigger_victory() -> void:
	if is_victory or is_game_over: return
	is_victory = true
	victory.emit()
	if OS.is_debug_build(): print("Victory triggered!")

func pause_game() -> void:
	if is_game_over or is_victory: return
	if is_paused: return
	
	is_paused = true
	game_paused.emit()
	if OS.is_debug_build(): print("[GameManager] manual pause ON")

func resume_game() -> void:
	if not is_paused: return
	
	is_paused = false
	game_resumed.emit()
	if OS.is_debug_build(): print("[GameManager] manual pause OFF")

func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()

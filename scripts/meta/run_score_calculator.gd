extends RefCounted

# Server-side formula mirror — must stay in sync with backend/leaderboard-api calcScore().
# score = wave_reached * 10000
#       + lives_remaining * 500
#       + gold_remaining  * 10
#       + interest_level  * 1000
#       + clear_bonus
#       - run_time_seconds
# clear_bonus = 100000 if cleared AND wave_reached >= MAX_WAVE

const MAX_WAVE: int = 60
const CLEAR_BONUS: int = 100000

static func calculate(
	wave_reached: int,
	lives_remaining: int,
	gold_remaining: int,
	interest_level: int,
	cleared: bool,
	run_time_seconds: int
) -> int:
	var s: int = wave_reached * 10000 \
		+ lives_remaining * 500 \
		+ gold_remaining * 10 \
		+ interest_level * 1000 \
		- run_time_seconds
	if cleared and wave_reached >= MAX_WAVE:
		s += CLEAR_BONUS
	return max(0, s)

class_name CombatAudioConfig
extends RefCounted

# Throttle: minimum seconds between plays per SFX type.
# High-priority sounds bypass this check entirely.
const COOLDOWNS: Dictionary = {
	"tower_shoot_rapid":    0.08,
	"tower_shoot_sawblade": 0.08,
	"tower_shoot_basic":    0.10,
	"tower_shoot_sniper":   0.14,
	"tower_shoot_cannon":   0.16,
	"tower_shoot_slow":     0.22,
	"projectile_hit":       0.06,
	"splash_hit":           0.10,
}

# Max AudioStreamPlayers allowed to play this type simultaneously.
# 0 = no per-type cap (only pool cap applies).
const MAX_SIMULTANEOUS: Dictionary = {
	"tower_shoot_rapid":    4,
	"tower_shoot_sawblade": 4,
	"tower_shoot_basic":    6,
	"tower_shoot_sniper":   3,
	"tower_shoot_cannon":   3,
	"tower_shoot_slow":     3,
	"projectile_hit":       8,
	"splash_hit":           4,
}

# Priority levels — higher wins.
const PRIORITY_HIGH   := 10  # UI / wave / leak / upgrade / game events
const PRIORITY_NORMAL := 5   # Standard tower attacks
const PRIORITY_LOW    := 2   # Rapid, DoT, aura, repeated ticks

const SFX_PRIORITIES: Dictionary = {
	"ui_click":         10,
	"start_wave":       10,
	"tower_place":      10,
	"tower_upgrade":    10,
	"enemy_reach_base": 10,
	"game_over":        10,
	"victory":          10,
	"pause":            10,
	"resume":           10,
	"gold_gain":         8,
	"enemy_die":         7,
	"tower_shoot_cannon": 6,
	"splash_hit":         6,
	"tower_shoot_sniper": 5,
	"tower_shoot_basic":  5,
	"projectile_hit":     4,
	"tower_shoot_slow":   4,
	"tower_shoot_rapid":  3,
	"tower_shoot_sawblade": 3,
}

# Random pitch variation: player pitch_scale = 1.0 ± this value.
const PITCH_VARIATION: Dictionary = {
	"tower_shoot_rapid":    0.08,
	"tower_shoot_sawblade": 0.10,
	"tower_shoot_basic":    0.05,
	"tower_shoot_cannon":   0.04,
	"tower_shoot_slow":     0.06,
	"tower_shoot_sniper":   0.03,
	"projectile_hit":       0.10,
	"splash_hit":           0.06,
}

# Random volume variation in dB applied on each play.
const VOLUME_VARIATION_DB: Dictionary = {
	"tower_shoot_rapid":    1.5,
	"tower_shoot_sawblade": 1.5,
	"tower_shoot_cannon":   1.0,
	"tower_shoot_slow":     1.0,
	"tower_shoot_basic":    1.0,
	"tower_shoot_sniper":   0.5,
	"projectile_hit":       2.0,
	"splash_hit":           1.5,
}

# Pre-allocated pool size.
const POOL_SIZE := 16

# Adaptive volume reduction for normal/low priority sounds.
# Format: [min_active_pool_count, reduction_db]
# Highest matching tier wins (tiers must be in ascending order).
const ADAPTIVE_STEPS: Array = [
	[6,  -2.0],
	[10, -4.0],
	[14, -7.0],
]

const DEFAULT_PRIORITY := 5

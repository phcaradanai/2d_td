class_name CombatAudioConfig
extends RefCounted

# Priority levels — shared across all modes.
const PRIORITY_HIGH   := 10  # UI / wave / leak / upgrade / game events
const PRIORITY_NORMAL := 5   # Standard tower attacks
const PRIORITY_LOW    := 2   # Rapid, DoT, aura, repeated ticks

const SFX_PRIORITIES: Dictionary = {
	"ui_click":           10,
	"start_wave":         10,
	"tower_place":        10,
	"tower_upgrade":      10,
	"enemy_reach_base":   10,
	"game_over":          10,
	"victory":            10,
	"pause":              10,
	"resume":             10,
	"gold_gain":           8,
	"enemy_die":           7,
	"tower_shoot_cannon":  6,
	"splash_hit":           6,
	"tower_shoot_sniper":  5,
	"tower_shoot_basic":   5,
	"projectile_hit":      4,
	"tower_shoot_slow":    4,
	"tower_shoot_rapid":   3,
	"tower_shoot_sawblade": 3,
}

# Minimum seconds between plays per SFX type, per combat audio mode.
# High-priority sounds bypass this check entirely.
const COOLDOWNS_BY_MODE: Dictionary = {
	"full": {
		"tower_shoot_rapid":    0.02,
		"tower_shoot_sawblade": 0.02,
		"tower_shoot_basic":    0.04,
		"tower_shoot_sniper":   0.06,
		"tower_shoot_cannon":   0.08,
		"tower_shoot_slow":     0.08,
		"projectile_hit":       0.02,
		"splash_hit":           0.04,
	},
	"balanced": {
		"tower_shoot_rapid":    0.08,
		"tower_shoot_sawblade": 0.08,
		"tower_shoot_basic":    0.10,
		"tower_shoot_sniper":   0.14,
		"tower_shoot_cannon":   0.16,
		"tower_shoot_slow":     0.22,
		"projectile_hit":       0.06,
		"splash_hit":           0.10,
	},
	"minimal": {
		"tower_shoot_rapid":    0.25,
		"tower_shoot_sawblade": 0.25,
		"tower_shoot_basic":    0.18,
		"tower_shoot_sniper":   0.20,
		"tower_shoot_cannon":   0.28,
		"tower_shoot_slow":     0.40,
		"projectile_hit":       0.14,
		"splash_hit":           0.22,
	},
}

# Max simultaneous AudioStreamPlayers per SFX type, per mode.
# 0 = no per-type cap (only pool cap applies).
const MAX_SIMULTANEOUS_BY_MODE: Dictionary = {
	"full": {
		"tower_shoot_rapid":    8,
		"tower_shoot_sawblade": 8,
		"tower_shoot_basic":    10,
		"tower_shoot_sniper":   6,
		"tower_shoot_cannon":   6,
		"tower_shoot_slow":     6,
		"projectile_hit":       12,
		"splash_hit":           8,
	},
	"balanced": {
		"tower_shoot_rapid":    4,
		"tower_shoot_sawblade": 4,
		"tower_shoot_basic":    6,
		"tower_shoot_sniper":   3,
		"tower_shoot_cannon":   3,
		"tower_shoot_slow":     3,
		"projectile_hit":       8,
		"splash_hit":           4,
	},
	"minimal": {
		"tower_shoot_rapid":    2,
		"tower_shoot_sawblade": 2,
		"tower_shoot_basic":    3,
		"tower_shoot_sniper":   2,
		"tower_shoot_cannon":   2,
		"tower_shoot_slow":     2,
		"projectile_hit":       4,
		"splash_hit":           2,
	},
}

# Adaptive volume reduction for normal/low priority sounds, per mode.
# Format: [min_active_pool_count, reduction_db].
# Highest matching tier wins; list must be in ascending threshold order.
const ADAPTIVE_STEPS_BY_MODE: Dictionary = {
	"full": [
		[10, -1.0],
		[14, -2.5],
	],
	"balanced": [
		[6,  -2.0],
		[10, -4.0],
		[14, -7.0],
	],
	"minimal": [
		[4,  -4.0],
		[8,  -8.0],
		[12, -12.0],
	],
}

# Random pitch variation: pitch_scale = 1.0 ± this value.
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

const POOL_SIZE     := 16
const DEFAULT_PRIORITY := 5
const DEFAULT_MODE  := "balanced"
const VALID_MODES: Array = ["full", "balanced", "minimal"]

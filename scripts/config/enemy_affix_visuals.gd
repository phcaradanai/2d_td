class_name EnemyAffixVisuals
extends RefCounted

const AFFIX_COLORS := {
	"mechanical": Color(0.55, 0.80, 1.00),
	"undead": Color(0.75, 0.55, 1.00),
	"fast": Color(1.00, 0.95, 0.30),
	"healing": Color(0.40, 1.00, 0.60),
	"image": Color(0.70, 0.80, 1.00),
}

const BOSS_COLORS := {
	"boss_tyrant": Color(1.00, 0.50, 0.30),
	"boss_phantom": Color(0.65, 0.35, 1.00),
	"boss_herald": Color(1.00, 0.80, 0.20),
	"boss_colossus": Color(1.00, 0.28, 0.28),
	"boss_basic": Color(0.20, 1.00, 1.00),
	"boss_fast": Color(0.10, 1.00, 0.50),
	"boss_swarm": Color(0.75, 1.00, 0.10),
	"boss_runner": Color(0.20, 0.65, 1.00),
	"boss_tank": Color(1.00, 0.45, 0.10),
	"boss_hunter": Color(1.00, 0.10, 0.40),
	"boss_shieldbearer": Color(0.25, 0.50, 1.00),
	"boss_healer": Color(1.00, 0.35, 0.85),
	"boss_splitter": Color(0.75, 0.15, 1.00),
	"boss_cloaked": Color(0.35, 0.15, 1.00),
	"boss_flyer": Color(0.40, 0.90, 1.00),
	"boss_fast_flyer": Color(0.90, 1.00, 0.60),
	"boss_armored_flyer": Color(1.00, 0.65, 0.20),
	"boss_disruptor": Color(0.65, 0.25, 1.00),
}

static func get_affix_color(affix: String) -> Color:
	return AFFIX_COLORS.get(affix, Color.WHITE)

static func get_enemy_tint(enemy_type: String, affixes: Array) -> Color:
	if BOSS_COLORS.has(enemy_type):
		return BOSS_COLORS[enemy_type]
	if affixes.is_empty():
		return Color.WHITE

	var tint := Color.BLACK
	var count := 0
	for affix in affixes:
		var color := get_affix_color(str(affix))
		if color != Color.WHITE:
			tint.r += color.r
			tint.g += color.g
			tint.b += color.b
			count += 1
	if count <= 0:
		return Color.WHITE
	return Color(tint.r / count, tint.g / count, tint.b / count, 1.0)

static func get_sprite_modulate(tint: Color) -> Color:
	if tint == Color.WHITE:
		return Color.WHITE
	return Color.WHITE.lerp(tint, 0.38)

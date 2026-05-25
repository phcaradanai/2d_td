class_name EnemyRoleHunter
extends RefCounted

## Deployable support units were removed from the core mode. Hunter remains a
## fast pressure enemy, but no longer chases or attacks a player-controlled unit.
static func _process_hunter_ai(enemy: Node2D, delta: float) -> void:
	enemy.hunter_attack_timer = maxf(0.0, enemy.hunter_attack_timer - delta)
	enemy.hunter_scan_rotation += delta * 2.8
	enemy.hunter_lock_fx_time = maxf(0.0, enemy.hunter_lock_fx_time - delta * 3.0)
	enemy.hunter_target = null
	enemy.hunter_state = enemy.HunterState.PATHING
	enemy._process_pathing(delta)

static func _clear_hunter_target(enemy: Node2D) -> void:
	enemy.hunter_target = null
	enemy.hunter_state = enemy.HunterState.PATHING

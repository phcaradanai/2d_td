## StatusMarkerVFX — draws compact status icons on enemy creeps.
## One node is attached per creep (via EnemyVFXController or similar).
## Reuses the same node for all status updates — no per-hit spawning.
## Draws in LOCAL space above the enemy body.
extends Node2D
class_name StatusMarkerVFX

const ICON_R  := 5.5
const ICON_GAP := 13.0
const ICON_Y  := -28.0

const C_SLOW   := Color(0.50, 0.95, 1.00, 0.80)
const C_ROOT   := Color(0.15, 0.90, 0.45, 0.80)
const C_BURN   := Color(1.00, 0.32, 0.05, 0.80)
const C_POISON := Color(0.52, 0.12, 0.88, 0.80)
const C_SHOCK  := Color(0.65, 0.55, 1.00, 0.80)
const C_VULN   := Color(0.80, 0.08, 0.88, 0.80)

var owner_enemy: Node = null
var _t: float = 0.0
const _REDRAW_INTERVAL := 0.20
var _redraw_timer: float = 0.0

func setup(enemy: Node) -> void:
	owner_enemy = enemy
	z_index = 20
	add_to_group("status_vfx")
	if enemy.has_signal("enemy_modifier_changed"):
		if not enemy.enemy_modifier_changed.is_connected(_on_modifier_changed):
			enemy.enemy_modifier_changed.connect(_on_modifier_changed)

func _on_modifier_changed(_en: Node, _key: String, _val: Variant) -> void:
	_redraw_timer = 0.0
	visible = _has_any_active()
	queue_redraw()

func _process(delta: float) -> void:
	if owner_enemy == null or not is_instance_valid(owner_enemy):
		queue_free()
		return
	_t += delta * TAU
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = _REDRAW_INTERVAL
		visible = _has_any_active()
	if visible:
		queue_redraw()

func _has_any_active() -> bool:
	if not is_instance_valid(owner_enemy):
		return false
	return (
		float(owner_enemy.get("slow_remaining")) > 0.0
		or float(owner_enemy.get("root_remaining")) > 0.0
		or float(owner_enemy.get("vulnerability_remaining")) > 0.0
		or float(owner_enemy.get("armor_reduction_remaining")) > 0.0
		or not (owner_enemy.get("active_dot_effects") as Array).is_empty()
	)

func _draw() -> void:
	if not is_instance_valid(owner_enemy):
		return
	var states := _read_states()
	var active: Array[Color] = []
	if states["slow"]:   active.append(C_SLOW)
	if states["root"]:   active.append(C_ROOT)
	if states["burn"]:   active.append(C_BURN)
	if states["poison"]: active.append(C_POISON)
	if states["vuln"]:   active.append(C_VULN)
	var total := active.size()
	if total == 0:
		return
	var start_x := -(float(total - 1) * ICON_GAP) * 0.5
	for i in range(total):
		var cx := start_x + float(i) * ICON_GAP
		var pos := Vector2(cx, ICON_Y)
		var col: Color = active[i]
		var pulse := (sin(_t * 1.8 + float(i) * 1.1) * 0.5 + 0.5) * 0.25
		draw_circle(pos, ICON_R + pulse, Color(col.r, col.g, col.b, 0.18))
		draw_arc(pos, ICON_R, 0.0, TAU, 12, col, 1.4, true)
		draw_circle(pos, 2.2, Color(1.0, 1.0, 1.0, col.a * 0.72))

func _read_states() -> Dictionary:
	var s := {
		"slow": false, "root": false, "burn": false, "poison": false, "vuln": false
	}
	if not is_instance_valid(owner_enemy):
		return s
	s["slow"] = float(owner_enemy.get("slow_remaining")) > 0.0
	s["root"] = float(owner_enemy.get("root_remaining")) > 0.0
	s["vuln"] = float(owner_enemy.get("vulnerability_remaining")) > 0.0 \
		or float(owner_enemy.get("armor_reduction_remaining")) > 0.0
	var dots = owner_enemy.get("active_dot_effects")
	if dots is Array:
		for d in dots:
			if not d is Dictionary: continue
			match str(d.get("attack_type", "dot")).to_lower():
				"fire": s["burn"] = true
				_:      s["poison"] = true
	return s

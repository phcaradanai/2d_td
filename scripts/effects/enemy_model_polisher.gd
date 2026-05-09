extends RefCounted
class_name EnemyModelPolisher

static func role_color(enemy_type: String, visual_type: String, tags: Array, skill_id: String) -> Color:
	if skill_id == "healer" or enemy_type == "healer" or tags.has("healing"):
		return Color(0.64, 1.0, 0.84)
	if skill_id == "disrupt_aura" or enemy_type == "disruptor" or tags.has("disruptor"):
		return Color(0.95, 0.22, 0.82)
	if skill_id == "shield_aura" or tags.has("shield"):
		return Color(0.28, 0.78, 1.0)
	if tags.has("air") or visual_type.ends_with("flyer"):
		return Color(0.45, 0.9, 1.0)
	if tags.has("fast") or tags.has("runner"):
		return Color(0.05, 1.0, 0.74)
	if tags.has("heavy") or tags.has("armored"):
		return Color(0.72, 0.78, 0.84)
	if enemy_type == "splitter":
		return Color(0.86, 0.42, 1.0)
	if enemy_type == "cloaked" or tags.has("stealth"):
		return Color(0.72, 0.72, 1.0)
	if enemy_type == "swarm" or tags.has("swarm"):
		return Color(0.35, 1.0, 0.55)
	return Color(0.22, 0.82, 1.0)

static func should_use_lightweight_fx(enemy_type: String, tags: Array) -> bool:
	return enemy_type == "swarm" or tags.has("swarm")

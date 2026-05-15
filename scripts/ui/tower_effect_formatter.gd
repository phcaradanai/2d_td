## TowerEffectFormatter
## Static helper that converts raw tower config/info fields into human-readable
## display text. Works with both tower.get_info() dicts and raw catalog config dicts.
## Never reads global state; always pure-function over the supplied dictionary.

class_name TowerEffectFormatter
extends RefCounted

# ── Attack-type badge ────────────────────────────────────────────────────────

## Short human-readable label for the attack style.
static func attack_badge(info: Dictionary) -> String:
	var a_type := str(info.get("attack_type", "single")).to_lower()
	var tower_id := str(info.get("id", info.get("tower_id", ""))).to_lower()
	var economy_type := str(info.get("economy_type", "")).to_lower()
	match a_type:
		"splash":  return "Splash AoE"
		"slow":    return "Area Control"
		"chain":   return "Chain"
		"aura":    return "Aura"
		"support_aura":
			var st := str(info.get("support_type", "")).to_lower()
			if st == "attack_speed": return "Speed Aura"
			if st == "damage":       return "Damage Aura"
			return "Support Aura"
		"clone_support": return "Clone"
		_:
			if economy_type == "life":  return "Economy: Life"
			if economy_type == "gold":  return "Economy: Gold"
			if tower_id.begins_with("laser_"):      return "Pierce Beam"
			if tower_id.begins_with("impulse_"):    return "Impact Shot"
			if tower_id.begins_with("zealot_"):     return "Rapid Strike"
			if tower_id.begins_with("quark_"):      return "Charged Shot"
			if tower_id.begins_with("flesh_golem_"): return "Slam AoE"
			return "Kinetic"

## Same as attack_badge but reads from a raw catalog config (uses .get() defaults).
static func attack_badge_from_cfg(cfg: Dictionary) -> String:
	return attack_badge(cfg)

# ── Effect lines ─────────────────────────────────────────────────────────────

## Returns an array of human-readable effect description lines (non-empty only).
## Caller joins them with "\n" for Labels, or formats with BBCode for RichTextLabel.
static func effect_lines(info: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var a_type    := str(info.get("attack_type", "single")).to_lower()
	var tower_id  := str(info.get("id", info.get("tower_id", ""))).to_lower()

	var splash_r    := int(info.get("splash_radius", 0))
	var slow_pct    := int(round(float(info.get("slow_percent",   0.0)) * 100.0))
	var slow_dur    := float(info.get("slow_duration",  0.0))
	var slow_r      := int(info.get("slow_radius", 0))
	var chain_j     := int(info.get("chain_jumps",  0))
	var chain_rng   := int(round(float(info.get("chain_range",  0.0))))
	var chain_fall  := float(info.get("chain_falloff", 1.0))
	var vuln_pct    := int(round(float(info.get("vulnerability_percent",  0.0)) * 100.0))
	var vuln_dur    := float(info.get("vulnerability_duration", 0.0))
	var sup_type    := str(info.get("support_type",  "")).to_lower()
	var sup_pct     := int(round(float(info.get("support_value",  0.0)) * 100.0))
	var sup_limit   := int(info.get("support_limit", 4))
	var sup_count   := int(info.get("support_target_count", 0))
	var clone_pct   := int(round(float(info.get("clone_damage_multiplier", 0.0)) * 100.0))
	var clone_dur   := float(info.get("clone_duration", 0.0))
	var clone_tgt   := str(info.get("clone_target_name", ""))
	var economy     := str(info.get("economy_type", "")).to_lower()
	var damage      := float(info.get("damage", 0.0))

	# ── Core attack-type effect ─────────────────────────────────────────────
	match a_type:
		"splash":
			if splash_r > 0:
				lines.append("Splash: damages enemies within %d radius" % splash_r)
			if slow_pct > 0 and slow_dur > 0.0:
				lines.append("On-hit Slow: -%d%% speed for %.1fs" % [slow_pct, slow_dur])

		"slow":
			var r := slow_r if slow_r > 0 else splash_r
			if slow_pct > 0 and slow_dur > 0.0:
				if r > 0:
					lines.append("Area Slow: -%d%% speed for %.1fs in %d radius" % [slow_pct, slow_dur, r])
				else:
					lines.append("Area Slow: -%d%% speed for %.1fs" % [slow_pct, slow_dur])

		"chain":
			if chain_j > 0:
				var fall_pct := int(round(chain_fall * 100.0))
				if chain_rng > 0:
					lines.append("Chain: jumps to %d enemies within %d range, %d%% damage" % [chain_j, chain_rng, fall_pct])
				else:
					lines.append("Chain: jumps to %d nearby enemies, %d%% damage" % [chain_j, fall_pct])

		"aura":
			if vuln_pct > 0:
				lines.append("Vulnerability: enemies take +%d%% damage for %.1fs" % [vuln_pct, vuln_dur])

		"support_aura":
			if sup_type == "attack_speed" and sup_pct > 0:
				lines.append("Speed Aura: +%d%% attack speed to nearby towers" % sup_pct)
				lines.append("Supports up to %d towers  [%d linked]" % [sup_limit, sup_count])
			elif sup_type == "damage" and sup_pct > 0:
				lines.append("Damage Aura: +%d%% damage to nearby towers" % sup_pct)
				lines.append("Supports up to %d towers  [%d linked]" % [sup_limit, sup_count])

		"clone_support":
			if clone_pct > 0:
				if clone_tgt != "":
					lines.append("Clone: copies %s at %d%% damage" % [clone_tgt, clone_pct])
				else:
					lines.append("Clone: copies a selected tower at %d%% damage" % clone_pct)
			if clone_dur > 0.0:
				lines.append("Clone duration: %.0fs" % clone_dur)

	# ── Vulnerability on non-aura projectile towers ─────────────────────────
	if a_type not in ["aura", "support_aura", "clone_support"] and vuln_pct > 0 and vuln_dur > 0.0:
		lines.append("Vulnerability: +%d%% damage taken for %.1fs" % [vuln_pct, vuln_dur])

	# ── Economy ─────────────────────────────────────────────────────────────
	if economy == "life":
		var req  := int(info.get("on_kill_life_counter_required", 0))
		var prog := int(info.get("on_kill_life_progress",         0))
		if req > 0:
			lines.append("Life Harvest: +1 core every %d kills" % req)
			if prog > 0:
				lines.append("Kill progress: %d / %d" % [prog, req])
	elif economy == "gold":
		var bonus := int(round(float(info.get("on_kill_gold_bonus_percent", 0.0)) * 100.0))
		if bonus > 0:
			lines.append("Gold Bounty: +%d%% bonus credits on kills" % bonus)

	# ── Control-family parity abilities ─────────────────────────────────────
	if tower_id.begins_with("nova_") and damage > 0.0 and slow_dur > 0.0:
		lines.append("Burn: %.0f dps fire for %.1fs after impact" % [damage * 0.2, slow_dur * 1.5])

	if tower_id.begins_with("roots_") and slow_pct > 0:
		var snare := int(round(minf(float(info.get("slow_percent", 0.0)) + 0.25, 1.0) * 100.0))
		lines.append("Entangle: %d%% snare for %.1fs then slows" % [snare, slow_dur * 0.35])
		if damage > 0.0:
			lines.append("Poison: %.0f dps for %.1fs" % [damage * 0.25, slow_dur])

	if tower_id.begins_with("muck_") and damage > 0.0:
		lines.append("Sludge: %.0f dps for %.1fs" % [damage * 0.3, slow_dur * 1.2])
		lines.append("Corrode: -12%% enemy armor for %.1fs" % slow_dur)

	if tower_id.begins_with("windstorm_") and slow_pct > 0:
		lines.append("Gale: full-stop stagger 0.35s on impact")

	# ── Special damage-family parity abilities ───────────────────────────────
	if tower_id.begins_with("quark_"):
		lines.append("Impact: 70%% snare for 0.6s per charged shot")

	if tower_id.begins_with("laser_"):
		lines.append("Pierce: beam hits 2 additional enemies in line at 65%% damage")

	if tower_id.begins_with("impulse_"):
		lines.append("Scaling: 80%%→145%% damage by target distance")

	if tower_id.begins_with("zealot_"):
		lines.append("Ramp: +6%% damage per consecutive hit (cap +60%%)")

	if tower_id.begins_with("quaker_"):
		lines.append("Shock: 0.4s stun + enemies take +15%% damage for 2.5s")

	if tower_id.begins_with("flesh_golem_"):
		lines.append("Crush: enemies take +18%% damage for 3s (refreshing)")

	if tower_id.begins_with("flamethrower_") and damage > 0.0:
		lines.append("Burn: %.0f dps fire for 2s after each blast" % (damage * 0.35))

	return lines

# ── Upgrade delta ────────────────────────────────────────────────────────────

## Returns a compact "Next Upgrade" summary string comparing current stats to
## the next-tier config. Returns "" if no meaningful delta exists.
static func upgrade_preview(current_info: Dictionary, next_cfg: Dictionary) -> String:
	if next_cfg.is_empty():
		return ""
	var next_name := str(next_cfg.get("name", next_cfg.get("display_name", "")))
	var next_stats := _first_level_stats(next_cfg)
	var next_dmg   := float(next_stats.get("damage",    0.0))
	var next_rng   := int(next_stats.get("range",       0))
	var next_rate  := float(next_stats.get("fire_rate", 0.0))
	var next_cost  := int(next_cfg.get("cost",          0))

	var cur_dmg  := float(current_info.get("damage",    0.0))
	var cur_rng  := int(round(float(current_info.get("range", 0))))
	var cur_rate := float(current_info.get("fire_rate", 0.0))

	var parts := PackedStringArray()
	if next_dmg > 0.0 and cur_dmg > 0.0:
		var d := int(round(next_dmg - cur_dmg))
		if d > 0:   parts.append("DMG +%d" % d)
		elif d < 0: parts.append("DMG %d" % d)
	if next_rng > 0 and cur_rng > 0:
		var d := next_rng - cur_rng
		if d > 0:   parts.append("RNG +%d" % d)
	if next_rate > 0.0 and cur_rate > 0.0:
		var d := next_rate - cur_rate
		if absf(d) > 0.005:
			parts.append("SPEED %s" % ("↑" if d < 0.0 else "↓"))

	var header := "── Next: %s" % next_name if next_name != "" else "── Next Tier"
	if next_cost > 0:
		header += "  (%d ¢)" % next_cost
	if parts.is_empty():
		return header
	return "%s\n   %s" % [header, "  ".join(parts)]

# ── Build-button tooltip text ────────────────────────────────────────────────

## Produces the tooltip_text string for a build shop button.
## elements_fn: callable(Array) -> String  (e.g. _elements_full in HUD)
static func build_tooltip(tower_id: String, cfg: Dictionary, cost: int, elements_fn: Callable) -> String:
	if cfg.is_empty():
		return "Cost: %d Credits" % cost

	var lines := PackedStringArray()
	var desc := str(cfg.get("description", ""))
	if desc != "":
		lines.append(desc)
		lines.append("")

	var a_badge    := attack_badge(cfg)
	var targets: Array = cfg.get("target_categories", ["land"])
	var tgt_str    := "Land + Air" if (targets.has("land") and targets.has("air")) else \
					  ("Air Only"  if targets.has("air") else "Land Only")
	var el_str     : String = elements_fn.call(cfg.get("elements", []))
	lines.append("Type: %s  |  Targets: %s" % [a_badge, tgt_str])
	lines.append("Elements: %s  |  Cost: %d" % [el_str, cost])

	var st := _first_level_stats(cfg)
	var dmg  := float(st.get("damage",    0.0))
	var rng  := int(st.get("range",       0))
	var rate := float(st.get("fire_rate", 0.0))
	var stat_parts := PackedStringArray()
	if dmg  > 0.0: stat_parts.append("DMG %s" % str(int(round(dmg))))
	if rng  > 0:   stat_parts.append("RNG %d" % rng)
	if rate > 0.0: stat_parts.append("%.2fs/shot" % rate)
	if stat_parts.size() > 0:
		lines.append("  ".join(stat_parts))

	# Key effects using a flat info dict derived from cfg + first-level stats
	var flat := _cfg_to_flat(tower_id, cfg, st)
	var effs := effect_lines(flat)
	for eff in effs:
		lines.append("  " + eff)

	return "\n".join(lines)

# ── Hover card BBCode lines ──────────────────────────────────────────────────

## Returns BBCode lines suitable for a RichTextLabel hover card.
static func hover_card_bbcode(tower_id: String, cfg: Dictionary, cost: int, elements_fn: Callable) -> String:
	if cfg.is_empty():
		return "[b]%s[/b]  [color=#aabbcc]%d ¢[/color]" % [tower_id, cost]

	var parts := PackedStringArray()
	var name_str := str(cfg.get("name", cfg.get("display_name", tower_id)))
	parts.append("[b]%s[/b]  [color=#a8c4d8]%d ¢[/color]" % [name_str, cost])

	var a_badge   := attack_badge(cfg)
	var targets: Array = cfg.get("target_categories", ["land"])
	var tgt_str   := "Land+Air" if (targets.has("land") and targets.has("air")) else \
					 ("Air"     if targets.has("air") else "Land")
	var el_str    : String = elements_fn.call(cfg.get("elements", []))
	parts.append("[color=#6699bb]%s[/color]  [color=#99bbcc]%s • %s[/color]" % [el_str, a_badge, tgt_str])

	var st   := _first_level_stats(cfg)
	var dmg  := float(st.get("damage",    0.0))
	var rng  := int(st.get("range",       0))
	var rate := float(st.get("fire_rate", 0.0))
	var stat_parts := PackedStringArray()
	if dmg  > 0.0: stat_parts.append("DMG [b]%s[/b]" % str(int(round(dmg))))
	if rng  > 0:   stat_parts.append("RNG [b]%d[/b]" % rng)
	if rate > 0.0: stat_parts.append("[b]%.2fs[/b]/shot" % rate)
	if stat_parts.size() > 0:
		parts.append("[color=#88aacc]" + "  ".join(stat_parts) + "[/color]")

	var flat := _cfg_to_flat(tower_id, cfg, st)
	var effs := effect_lines(flat)
	for eff in effs:
		parts.append("[color=#aaccee]  %s[/color]" % eff)

	var desc := str(cfg.get("description", ""))
	if desc != "" and effs.is_empty():
		parts.append("[i][color=#667788]%s[/color][/i]" % desc)

	return "\n".join(parts)

# ── Private helpers ──────────────────────────────────────────────────────────

## Extracts first-level stats from a tower config dict.
static func _first_level_stats(cfg: Dictionary) -> Dictionary:
	if cfg.has("levels"):
		var lvls = cfg["levels"]
		if lvls is Array and not lvls.is_empty() and lvls[0] is Dictionary:
			return lvls[0]
	return cfg

## Builds a flat info-compatible dict from a config + first-level stats.
static func _cfg_to_flat(tower_id: String, cfg: Dictionary, st: Dictionary) -> Dictionary:
	var d := {}
	d["id"]                          = tower_id
	d["attack_type"]                 = str(cfg.get("attack_type", "single"))
	d["damage"]                      = float(st.get("damage", cfg.get("damage", 0.0)))
	d["splash_radius"]               = int(st.get("splash_radius", cfg.get("splash_radius", 0)))
	d["slow_percent"]                = float(st.get("slow_percent", cfg.get("slow_percent", 0.0)))
	d["slow_duration"]               = float(st.get("slow_duration", cfg.get("slow_duration", 0.0)))
	d["slow_radius"]                 = int(st.get("slow_radius", cfg.get("slow_radius", 0)))
	d["chain_jumps"]                 = int(st.get("chain_jumps", cfg.get("chain_jumps", 0)))
	d["chain_range"]                 = float(st.get("chain_range", cfg.get("chain_range", 0.0)))
	d["chain_falloff"]               = float(st.get("chain_falloff", cfg.get("chain_falloff", 1.0)))
	d["vulnerability_percent"]       = float(st.get("vulnerability_percent", cfg.get("vulnerability_percent", 0.0)))
	d["vulnerability_duration"]      = float(st.get("vulnerability_duration", cfg.get("vulnerability_duration", 0.0)))
	d["support_type"]                = str(cfg.get("support_type", ""))
	d["support_value"]               = float(cfg.get("support_value", 0.0))
	d["support_limit"]               = int(cfg.get("support_limit", 4))
	d["support_target_count"]        = 0
	d["clone_damage_multiplier"]     = float(cfg.get("clone_damage_multiplier", 0.0))
	d["clone_duration"]              = float(cfg.get("clone_duration", 0.0))
	d["clone_target_name"]           = ""
	d["economy_type"]                = str(cfg.get("economy_type", ""))
	d["on_kill_life_counter_required"] = int(cfg.get("on_kill_life_counter_required", 0))
	d["on_kill_life_progress"]       = 0
	d["on_kill_gold_bonus_percent"]  = float(cfg.get("on_kill_gold_bonus_percent", 0.0))
	return d

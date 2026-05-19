## PerformanceFirebreak — global kill-switch for all cosmetic VFX.
## Set enabled = true to enforce all sub-flags simultaneously.
## Individual flags can be toggled while enabled is false.
class_name PerformanceFirebreak
extends RefCounted

static var enabled := true

static var disable_all_attack_vfx := true
static var disable_catalog_vfx := true
static var disable_damage_numbers := true
static var disable_impact_effects := true
static var disable_death_effects := true
static var disable_status_animations := true
static var disable_aura_visuals := true
static var disable_projectile_visuals := true
static var disable_cosmetic_tweens := true
static var max_active_vfx := 0
static var ui_refresh_interval := 1.0

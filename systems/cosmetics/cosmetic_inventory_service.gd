extends Node

signal cosmetics_changed()
signal equipped_changed(tower_id: String, slot: String, cosmetic_id: String)

const SLOT_TOWER_SKIN := "tower_skin"
const SLOT_PROJECTILE_SKIN := "projectile_skin"
const SLOT_IMPACT_SKIN := "impact_skin"
const SLOT_ATTACK_VFX_SKIN := "attack_vfx_skin"
## Synthetic slot used to store per-tower VFX mode preference via equip_cosmetic.
const _SLOT_ATTACK_MODE := "attack_vfx_mode"

func get_unlocked_ids() -> Array[String]:
	var sm := _save_manager()
	if sm != null and sm.has_method("get_unlocked_cosmetic_ids"):
		return sm.get_unlocked_cosmetic_ids()
	return []

func is_unlocked(cosmetic_id: String) -> bool:
	return get_unlocked_ids().has(cosmetic_id)

func unlock(cosmetic_id: String) -> bool:
	if cosmetic_id == "":
		return false
	var sm := _save_manager()
	if sm == null or not sm.has_method("unlock_cosmetic"):
		return false
	var changed := bool(sm.unlock_cosmetic(cosmetic_id))
	if changed:
		cosmetics_changed.emit()
	return changed

func equip(tower_id: String, slot: String, cosmetic_id: String) -> bool:
	print("[inv.equip] called tower=", tower_id, " slot=", slot, " id=", cosmetic_id)
	if tower_id == "" or slot == "":
		print("[inv.equip] REJECTED: empty tower_id or slot")
		return false
	if cosmetic_id != "" and not is_unlocked(cosmetic_id):
		print("[inv.equip] REJECTED: not unlocked. unlocked_ids=", get_unlocked_ids())
		return false
	var registry := _registry()
	if cosmetic_id != "" and registry != null and registry.has_method("get_cosmetic"):
		var cfg: Dictionary = registry.get_cosmetic(cosmetic_id)
		if cfg.is_empty() or str(cfg.get("tower_id", "")) != tower_id or str(cfg.get("slot", "")) != slot:
			print("[inv.equip] REJECTED: cfg mismatch. cfg=", cfg)
			return false
	var sm := _save_manager()
	if sm == null or not sm.has_method("equip_cosmetic"):
		print("[inv.equip] REJECTED: SaveManager not found. sm=", sm)
		return false
	var changed := bool(sm.equip_cosmetic(tower_id, slot, cosmetic_id))
	if changed:
		equipped_changed.emit(tower_id, slot, cosmetic_id)
		cosmetics_changed.emit()
	return changed

func unequip(tower_id: String, slot: String) -> bool:
	return equip(tower_id, slot, "")

## Returns "projectile" or "attack_vfx" (default).
func get_attack_mode(tower_id: String) -> String:
	var sm := _save_manager()
	if sm != null and sm.has_method("get_equipped_cosmetic"):
		var v := str(sm.get_equipped_cosmetic(tower_id, _SLOT_ATTACK_MODE))
		if v == "projectile":
			return "projectile"
	return "attack_vfx"

## Persists the per-tower VFX mode preference ("attack_vfx" or "projectile").
func set_attack_mode(tower_id: String, mode: String) -> void:
	if tower_id == "":
		return
	var safe_mode := "projectile" if mode == "projectile" else "attack_vfx"
	var sm := _save_manager()
	if sm != null and sm.has_method("equip_cosmetic"):
		sm.equip_cosmetic(tower_id, _SLOT_ATTACK_MODE, safe_mode)
		equipped_changed.emit(tower_id, _SLOT_ATTACK_MODE, safe_mode)

func get_equipped(tower_id: String, slot: String) -> String:
	var sm := _save_manager()
	if sm != null and sm.has_method("get_equipped_cosmetic"):
		return str(sm.get_equipped_cosmetic(tower_id, slot))
	return ""

func _save_manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("SaveManager") if scene != null else null

func _registry() -> Node:
	return get_node_or_null("/root/CosmeticRegistry")

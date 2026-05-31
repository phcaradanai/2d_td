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
	var us := _unlock_service()
	if us != null:
		return us.get_unlocked_ids()
	var sm := _save_manager()
	if sm != null and sm.has_method("get_unlocked_cosmetic_ids"):
		return sm.get_unlocked_cosmetic_ids()
	return []

func is_unlocked(cosmetic_id: String) -> bool:
	var us := _unlock_service()
	if us != null:
		return us.is_unlocked(cosmetic_id)
	return get_unlocked_ids().has(cosmetic_id)

func unlock(cosmetic_id: String) -> bool:
	if cosmetic_id == "":
		return false
	var us := _unlock_service()
	if us != null:
		var changed : Variant = us.unlock(cosmetic_id)
		if changed:
			cosmetics_changed.emit()
		return changed
	var sm := _save_manager()
	if sm == null or not sm.has_method("unlock_cosmetic"):
		return false
	var changed := bool(sm.unlock_cosmetic(cosmetic_id))
	if changed:
		cosmetics_changed.emit()
	return changed

func equip(tower_id: String, slot: String, cosmetic_id: String) -> bool:
	if tower_id == "" or slot == "":
		return false
	if cosmetic_id != "" and not is_unlocked(cosmetic_id):
		return false
	var registry := _registry()
	if cosmetic_id != "" and registry != null and registry.has_method("get_cosmetic"):
		var cfg: Dictionary = registry.get_cosmetic(cosmetic_id)
		if cfg.is_empty() or str(cfg.get("tower_id", "")) != tower_id or str(cfg.get("slot", "")) != slot:
			return false
	var sm := _save_manager()
	if sm == null or not sm.has_method("equip_cosmetic"):
		return false
	var changed := bool(sm.equip_cosmetic(tower_id, slot, cosmetic_id))
	if changed:
		equipped_changed.emit(tower_id, slot, cosmetic_id)
		_equip_linked_cosmetic_bundle(sm, tower_id, slot, cosmetic_id)
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

func _equip_linked_cosmetic_bundle(sm: Node, tower_id: String, slot: String, cosmetic_id: String) -> void:
	if tower_id != "darkness_t1" or slot != SLOT_TOWER_SKIN or cosmetic_id != "darkness_turret_core":
		return
	var linked := {
		SLOT_PROJECTILE_SKIN: "darkness_turret_projectile",
		SLOT_IMPACT_SKIN: "darkness_turret_impact",
		SLOT_ATTACK_VFX_SKIN: "darkness_turret_attack_vfx",
	}
	for linked_slot in linked.keys():
		var linked_id := str(linked[linked_slot])
		if sm.has_method("get_equipped_cosmetic") and str(sm.get_equipped_cosmetic(tower_id, linked_slot)) == linked_id:
			continue
		if sm.has_method("equip_cosmetic") and bool(sm.equip_cosmetic(tower_id, linked_slot, linked_id)):
			equipped_changed.emit(tower_id, linked_slot, linked_id)
	if sm.has_method("equip_cosmetic"):
		sm.equip_cosmetic(tower_id, _SLOT_ATTACK_MODE, "attack_vfx")
		equipped_changed.emit(tower_id, _SLOT_ATTACK_MODE, "attack_vfx")

func get_equipped(tower_id: String, slot: String) -> String:
	var sm := _save_manager()
	if sm != null and sm.has_method("get_equipped_cosmetic"):
		return str(sm.get_equipped_cosmetic(tower_id, slot))
	return ""

func _unlock_service() -> Node:
	return get_node_or_null("/root/CosmeticUnlockService")

func _save_manager() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("SaveManager") if scene != null else null

func _registry() -> Node:
	return get_node_or_null("/root/CosmeticRegistry")

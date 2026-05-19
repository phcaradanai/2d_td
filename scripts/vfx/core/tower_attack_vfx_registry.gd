## TowerAttackVFXRegistry — maps every tower_id to its VFX GDScript.
## Populated with preload() entries in Task 10 after all tower files exist.
class_name TowerAttackVFXRegistry
extends RefCounted

## Filled in Task 10.
const _SCRIPTS: Dictionary = {}

static func get_script(tower_id: String) -> GDScript:
	return _SCRIPTS.get(tower_id, null)

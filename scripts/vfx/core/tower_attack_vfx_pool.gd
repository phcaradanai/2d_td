## TowerAttackVFXPool — manages the global VFX budget for new per-id VFX nodes.
## Actual node pooling is deferred; budget enforcement is the priority.
class_name TowerAttackVFXPool
extends RefCounted

const MAX_ACTIVE: int = 80

static func can_spawn() -> bool:
	return BaseTowerAttackVFX._active_count < MAX_ACTIVE

static func active_count() -> int:
	return BaseTowerAttackVFX._active_count

class_name CatalogVfxMode
extends RefCounted

const VFX_OFF := "off"
const VFX_SELECTED_ONLY := "selected_only"
const VFX_ALL := "all"
const DEFAULT_MODE := VFX_SELECTED_ONLY

static func allows_grid_vfx(mode: String, selected: bool, hovered: bool) -> bool:
	match mode:
		VFX_OFF:
			return false
		VFX_ALL:
			return true
		_:
			return selected or hovered

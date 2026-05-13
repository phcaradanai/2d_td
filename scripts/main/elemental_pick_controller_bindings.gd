extends RefCounted
class_name ElementalPickControllerBindings

static func dependencies(main_node: Node, hud_presenter: RefCounted) -> Dictionary:
	return {
		"main": main_node,
		"hud_state_presenter": hud_presenter,
	}

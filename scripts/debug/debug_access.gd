extends RefCounted
class_name DebugAccess

const DEBUG_UI_SETTING := "application/config/enable_debug_ui"
const BALANCE_TOOLS_SETTING := "application/config/enable_balance_tools"

static func is_debug_ui_allowed() -> bool:
	if OS.is_debug_build():
		return true
	return bool(ProjectSettings.get_setting(DEBUG_UI_SETTING, false)) or OS.has_feature("qa_build") or OS.has_feature("internal_tools")

static func is_balance_tools_allowed() -> bool:
	if not is_debug_ui_allowed():
		return false
	if OS.has_feature("qa_build") or OS.has_feature("internal_tools"):
		return bool(ProjectSettings.get_setting(BALANCE_TOOLS_SETTING, true))
	return bool(ProjectSettings.get_setting(BALANCE_TOOLS_SETTING, false))

const DEBUG_ACCESS_LOGS := false

static func block_balance_tool(action: String) -> bool:
	if is_balance_tools_allowed():
		return false
	if DEBUG_ACCESS_LOGS and OS.is_debug_build():
		print("[DebugAccess] Balance tool blocked: %s is not allowed in this build." % action)
	return true

static func register_balance_tool_ui(node: Node) -> void:
	if node == null:
		return
	node.add_to_group("balance_tool_ui")
	_apply_balance_control_state(node, is_balance_tools_allowed())

static func apply_balance_tool_gate(root: Node) -> void:
	if root == null:
		return
	var allowed := is_balance_tools_allowed()
	for node in root.get_tree().get_nodes_in_group("balance_tool_ui"):
		_apply_balance_control_state(node, allowed)

static func assert_release_has_no_balance_tools(root: Node) -> void:
	if root == null or OS.is_debug_build():
		return
	for node in root.get_tree().get_nodes_in_group("balance_tool_ui"):
		if node is CanvasItem and node.visible:
			push_error("Release safety violation: visible balance tool UI found: %s" % node.get_path())
		_apply_balance_control_state(node, false)
	for node in root.get_tree().get_nodes_in_group("balance_tool_runtime"):
		push_warning("Release safety: balance runtime registered and blocked: %s" % node.get_path())

static func _apply_balance_control_state(node: Node, allowed: bool) -> void:
	if node is CanvasItem:
		node.visible = allowed
	if node is BaseButton:
		node.disabled = not allowed
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_STOP if allowed else Control.MOUSE_FILTER_IGNORE
	node.process_mode = Node.PROCESS_MODE_INHERIT if allowed else Node.PROCESS_MODE_DISABLED

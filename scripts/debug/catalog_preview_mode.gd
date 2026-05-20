class_name CatalogPreviewMode
extends RefCounted

const META_PREVIEW_MODE := "catalog_preview_mode"
const META_STATIC_PREVIEW := "catalog_static_preview"
const META_SELECTED_DEMO := "catalog_selected_demo"

static func mark_preview_tree(root: Node, static_preview: bool = true, selected_demo: bool = false) -> void:
	if root == null:
		return
	set_preview_mode(root, true)
	set_static_preview(root, static_preview)
	set_selected_demo(root, selected_demo)
	for child in root.get_children():
		mark_preview_tree(child, static_preview, selected_demo)

static func set_preview_mode(node: Node, enabled: bool) -> void:
	if node:
		node.set_meta(META_PREVIEW_MODE, enabled)

static func is_preview_node(node: Node) -> bool:
	return node != null and bool(node.get_meta(META_PREVIEW_MODE, false))

static func set_static_preview(node: Node, enabled: bool) -> void:
	if node:
		node.set_meta(META_STATIC_PREVIEW, enabled)

static func is_static_preview(node: Node) -> bool:
	return node != null and bool(node.get_meta(META_STATIC_PREVIEW, false))

static func set_selected_demo(node: Node, enabled: bool) -> void:
	if node:
		node.set_meta(META_SELECTED_DEMO, enabled)

static func is_selected_demo(node: Node) -> bool:
	return node != null and bool(node.get_meta(META_SELECTED_DEMO, false))

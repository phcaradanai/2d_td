extends RefCounted
class_name CosmeticTowerCatalog

const TOWERS_TREE_PATH := "res://data/towers_tree.json"

static func load_towers() -> Array[Dictionary]:
	var data := _load_json(TOWERS_TREE_PATH)
	var out: Array[Dictionary] = []
	for tower_id in data.keys():
		var cfg: Dictionary = data[tower_id]
		cfg["id"] = str(cfg.get("id", tower_id))
		out.append(cfg)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(a.get("shop_order", 999999))
		var order_b := int(b.get("shop_order", 999999))
		if order_a == order_b:
			return str(a.get("display_name", a.get("name", a.get("id", "")))) < str(b.get("display_name", b.get("name", b.get("id", ""))))
		return order_a < order_b
	)
	return out

static func display_name(cfg: Dictionary) -> String:
	return str(cfg.get("display_name", cfg.get("name", cfg.get("id", "Tower"))))

static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {}
	return json.data

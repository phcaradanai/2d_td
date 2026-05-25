## BakedAttackVFXSprite — plays pre-baked VFX frames as a Sprite2D.
## Positioned between origin and target; scales to fit the distance.
## Spawned by TowerAttackVFXService when AttackVFXFrameBaker has cached frames.
extends Sprite2D

func play(origin: Vector2, target_pos: Vector2, frames: Array,
		  duration: float, primary_color: Color) -> void:
	if frames.is_empty():
		queue_free()
		return
	var diff := target_pos - origin
	var dist := diff.length()
	# Place centered between origin and target; scale X to fill the distance.
	global_position = (origin + target_pos) * 0.5
	if dist > 0.5:
		global_rotation = diff.angle()
	scale = Vector2(dist / 160.0, 1.0)  # 160 = AttackVFXFrameBaker.BAKE_W
	centered = true
	modulate = primary_color
	texture = frames[0] as Texture2D
	visible = true
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		if is_instance_valid(self):
			var idx := clampi(int(t * frames.size()), 0, frames.size() - 1)
			texture = frames[idx] as Texture2D
	, 0.0, 1.0, duration)
	tw.tween_callback(queue_free)

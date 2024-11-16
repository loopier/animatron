extends Sprite2D

func _ready():
	await RenderingServer.frame_post_draw
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	var viewSize := get_window().size as Vector2

	if centered:
		set_position(viewSize/2)

	var scale2D := viewSize / texture.get_size()
	var leastScale: float = min(scale2D.x, scale2D.y)
	
	if leastScale == INF: leastScale = 1
	set_scale(Vector2(leastScale, leastScale))

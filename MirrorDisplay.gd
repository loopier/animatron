extends Sprite2D

func _ready():
	await RenderingServer.frame_post_draw
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	var viewportWidth: float = get_viewport().size.x
	var viewportHeight: float = get_viewport().size.y
	var scale := viewportWidth / texture.get_size().x

	if centered:
		set_position(Vector2(viewportWidth/2, viewportHeight/2))

	# Set same scale value horiz/vert to maintain aspect ratio
	set_scale(Vector2(scale, scale))

extends Sprite2D

func _ready():
	await RenderingServer.frame_post_draw
	get_viewport().connect("size_changed", _on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed():
	# Use content size rather than viewport size
	var viewSize: Vector2i = get_window().content_scale_size
	var viewWidth := viewSize.x as float
	var viewHeight:= viewSize.y as float

	if centered:
		set_position(Vector2(viewWidth/2, viewHeight/2))

	# Set same scale value horiz/vert to maintain aspect ratio
	#var scale := viewWidth / texture.get_size().x
	set_scale(Vector2(1, 1))

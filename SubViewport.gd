extends SubViewport

func _ready():
	get_window().connect("size_changed", _on_top_viewport_size_changed)
	_on_top_viewport_size_changed()

func _on_top_viewport_size_changed():
	size = get_window().content_scale_size

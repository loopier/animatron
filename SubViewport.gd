extends SubViewport
var userSetSize := false

func _ready():
	get_window().connect("size_changed", _on_top_viewport_size_changed)
	_on_top_viewport_size_changed()

func _on_top_viewport_size_changed():
	if not userSetSize:
		size = get_window().size

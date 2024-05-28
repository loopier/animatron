extends SubViewport
var userSetSize := false
var spout

func _ready():
	get_window().connect("size_changed", _on_top_viewport_size_changed)
	_on_top_viewport_size_changed()

func startSpout(name: String) -> Status:
	if OS.get_name() == "Windows":
		spout = Spout.new()
		spout.set_sender_name(name)
		RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
		return Status.ok();
	return Status.error("Spout only supported on Windows")
	
func _on_top_viewport_size_changed():
	if not userSetSize:
		size = get_window().size

func _on_frame_post_draw():
	if spout != null:
		#	var img := get_texture().get_image()
		#	var fmt := img.get_format()
		# Note that 0x1908 (6408) is Spout.FORMAT_RGBA, which is what we get if
		# we leave transparent_bg on for this SubViewport. Otherwise, we have
		# FORMAT_RGB, and then we'd need to specify format 0x1907 (6407), but
		# the performance is slower.
		# Alternatively, you can explicitly convert the format to whatever you
		# want here, but that's even slower. It's too bad we can't get the
		# texture handle directly, to avoid calling get_image() thereby reading
		# from the GPU, which kills performance!
		#	img.convert(Image.FORMAT_RGBA8)
		#	(spout as Spout).send_image(img, img.get_width(), img.get_height(), Spout.FORMAT_RGBA, false)

		# The fast way to send to Spout, without loading via CPU (Image)
		var viewport_texture := RenderingServer.viewport_get_texture(get_viewport_rid())
		var handle := RenderingServer.texture_get_native_handle(viewport_texture)
	
		# 0x0DE1 (3553) = GL_TEXTURE_2D in the Open GL API (Texture Target)
		(spout as Spout).send_texture(handle, 0x0DE1, size.x, size.y, false, 0)

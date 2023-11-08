extends GutTest

var main : Main

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child(main)

func after_each():
	gut.p("ran teardown logger", 2)
	main.queue_free()

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_listAssets():
	var result = main.evalCommand(["/assets/list"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	# commented the following because we may have different assets list
#	assert_eq(result.value, true)
#	assert_eq(result.msg, "")

func test_load():
	# asset doesn't exist
	var result = main.evalCommand(["/load", "xyz"], "127.0.0.1")
	assert_eq(result.type, Status.ERROR)
	assert_eq(result.value, null)
	assert_eq(result.msg, "Asset not found: user://assets/animations/xyz")
	# should pass
	result = main.evalCommand(["/load", "default"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, true)
	# commented the following because we may have different assets list
#	assert_eq(result.msg, "")

func test_createActor():
	# animation doesn't exist
	var result = main.evalCommand(["/create", "bla", "xyz"], "127.0.0.1")
	assert_eq(result.type, Status.ERROR)
	assert_eq(result.value, null)
	assert_eq(result.msg, "Animation not found: xyz")
	# should pass
	result = main.evalCommand(["/create", "bla", "default"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
#	assert_eq(result.value, true) # returns an object
	assert_eq(result.msg, "Created new actor 'bla': default")

func test_scale():
	var result = main.evalCommand(["/load", "default"], "127.0.0.1")
	result = main.evalCommand(["/create", "x", "default"], "127.0.0.1")
	result = main.evalCommand(["/scale", "x", 2], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, true)
	assert_eq(result.msg, "set_scale")

func test_speed():
	var result = main.evalCommand(["/load", "default"], "127.0.0.1")
	result = main.evalCommand(["/create", "x", "default"], "127.0.0.1")
	result = main.evalCommand(["/speed", "x", 2], "127.0.0.1")
	assert_eq(result.type, Status.OK)
#	assert_eq(result.value, true)
#	assert_eq(result.msg, "set_scale")

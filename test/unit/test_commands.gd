extends GutTest

var main : Main

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child_autoqfree(main)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_listAssets():
	var result := main.evalCommand(["/assets/list"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	# commented the following because we may have different assets list
#	assert_eq(result.value, true)
#	assert_eq(result.msg, "")

func test_load():
	# asset doesn't exist
	var result := main.evalCommand(["/load", "xyz"], "127.0.0.1")
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
	# Note we currently can't distinguish (at this point) whether the animation
	# existed or not...an empty Actor was created anyhow.
	var result := main.evalCommand(["/create", "bla", "unknown_xyz"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, true)
	assert_eq(result.msg, "")
	# should pass
	result = main.evalCommand(["/create", "bla", "default"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
#	assert_eq(result.value, true) # returns an object
	assert_true(result.msg.begins_with("Actor already exists: bla:"))
	assert_true(result.msg.ends_with("Setting new animation: default"))

func test_scale():
	var result := main.evalCommand(["/load", "default"], "127.0.0.1")
	result = main.evalCommand(["/create", "x", "default"], "127.0.0.1")
	result = main.evalCommand(["/scale", "x", 2], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, true)
	assert_eq(result.msg, "")

func test_speed():
	var result := main.evalCommand(["/load", "default"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	result = main.evalCommand(["/create", "x", "default"], "127.0.0.1")
	assert_eq(result.type, Status.OK)
	#result = main.evalCommand(["/speed/scale", "x", 2], "127.0.0.1") # To be added once setAnimationPropety is working
	assert_eq(result.type, Status.OK)
#	assert_eq(result.value, true)
#	assert_eq(result.msg, "set_scale")

func test_help():
	var result := main.evalCommand(["/help", "/create"], "")
	assert_eq(result.type, Status.OK)
	assert_is(result.value, CommandDescription)
	assert_typeof(result.msg, TYPE_STRING)
	# typo - no leading slash
	result = main.evalCommand(["/help", "create"], "")
	assert_eq(result.type, Status.OK)
	assert_is(result.value, CommandDescription)
	assert_typeof(result.msg, TYPE_STRING)
	# command does not exist
	result = main.evalCommand(["/help", "bla"], "")
	assert_eq(result.type, Status.ERROR)

func test_arrayCommandsDeferred():
	#----- Not deferred: -----
	"/set"
	var result := main.evalCommand(["/set", "myvar:f", "{3 + 0.14}"], "")
	assert_eq(result.type, Status.OK)
	assert_eq(VariablesManager.getValue("myvar"), 3.14, "/set using expression")
	result = main.evalCommand(["/set", "another:f", "{3 * $myvar}"], "")
	assert_eq(result.type, Status.OK)
	assert_eq(VariablesManager.getValue("another"), 3.14 * 3, "/set using expression and another variable")
	
	# Tests to be added:
	"/text/property"
	"/editor/property"
	"/post"
	result = main.evalCommand(["/post", "myvar=$myvar, doubled is", "{$myvar*2}"], "")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, ["myvar=3.14, doubled is 6.28"])
	
	"/front"
	"/behind"
	"/top"
	"/bottom"
	"/property"
	"/property/relative"
	"/method"
	"/animation/property"
	"/animation/method"
	"/animation/frames/method"

	#----- Deferred: -----
	# Tests to be added:
	"/routine"
	var oldLogLevel := Log.getLevel()
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	result = main.evalCommand(["/routine", "test", 1, 0.1, "/post", "$myvar", "{$myvar / 2}"], "")
	Log.setLevel(oldLogLevel)
	assert_eq(result.type, Status.OK)
	assert_eq(result.msg, "New routine 'test' (1 times every 0.1): [\"/post\", \"$myvar\", \"{$myvar / 2}\"]")
	var test := main.routines.get_node("test")
	assert_is(test, Routine)
	assert_eq((test as Routine).command, ["/post", "$myvar", "{$myvar / 2}"])
	assert_eq((test as Routine).lastCommand, [])
	
	"/routine/finished"
	result = main.evalCommand(["/routine/finished", "test", "/post", "{$myvar-2}"], "")
	assert_eq(result.type, Status.OK)
	assert_eq(result.msg, "Set last command for routine: test")
	assert_eq((test as Routine).lastCommand, ["/post", "{$myvar-2}"])

	"/wait"
	"/state/add"
	"/def"
	"/for"
	"/editor/append"
	"/osc/remote"
	"/osc/send"
	"/midi/cc"
	"/midi/noteon/num"
	"/midi/noteon/trig"
	"/midi/noteon/num/velocity"
	"/midi/noteon/velocity"
	"/midi/noteon"
	"/midi/noteoff/num"
	"/midi/noteoff"
	"/midi/list"
	"/rand"
	"/tween"

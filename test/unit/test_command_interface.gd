extends GutTest

var log : Log
var main : Main
var cmd

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	cmd.remove("x", cmd.variables)
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)
	log = Log.new() # preload("res://Log.gd")
	main = preload("res://main.tscn").instantiate()
	add_child(main)
	cmd = main.get_node("CommandInterface")

func after_all():
	gut.p("ran run teardown logger", 2)
	main.queue_free()
	log.free()

func test_getCommand():
	var aCommand = cmd.getCommandDescription("/load")
	assert_eq(aCommand.callable, cmd.loadAnimationAsset)
	assert_eq(aCommand.argsDescription, "animation:s")
	assert_eq(aCommand.description, "Load an ANIMATION asset from disk. It will create an animation with the same name as the asset. Wildcards are supported, so several animations can be loaded at once. See also: `/list/assets`.")
	assert_eq(aCommand.argsAsArray, false)
	assert_eq(aCommand.toGdScript, false)

func test_listCommands():
	assert_eq(cmd.listCommands(cmd.coreCommands).value, "
--
/actors/list
/animations
/animations/list
/assets
/assets/list
/color
/commands
/commands/list
/create
/free
/get
/load
/load/file
/log/level
/remove
/routine/free
/routine/start
/routine/stop
/routines
/set
/state/free
/state/next
/states
/test
")

func test_listAssets():
	assert_eq(cmd.listAnimationAssets().value, [])

func test_splitArray():
	var arr = ["/alo", ",", 1]
	assert_eq(cmd._splitArray(",", arr), [["/alo"],[1]])
	arr = ["/alo", "x", 1, ",", "/bla", "zzz"]
	assert_eq(cmd._splitArray(",", arr), [["/alo", "x", 1], ["/bla", "zzz"]])
	arr = ["/alo", "x", 1]
	assert_eq(cmd._splitArray(",", arr), [["/alo", "x", 1]])

func test_setDef():
	var def = ["/alo", "x", 1, ",", "/create", "ma", "mama"]
	assert_eq(cmd.defineCommand(def).value, ["/alo", ["x", 1], [["/create", "ma", "mama"]]])
	def = ["/alo", "x", 1, ",", "/create", "ma", "mama", ",", "/size", "ma", 0.5]
	assert_eq(cmd.defineCommand(def).value, ["/alo", ["x", 1], [["/create", "ma", "mama"], ["/size", "ma", 0.5]]])
	def = ["/red/mama", "argA", "argB", ",", "/create", "x", "mama", ",", "/speed", "x", 2]
	assert_eq(cmd.defineCommand(def).value, ["/red/mama", ["argA", "argB"], [["/create", "x", "mama"], ["/speed", "x", 2]]])

func test_parseCommand():
	cmd.setVar("/x", 1)
	gut.p("This one should return 1")
	var result = cmd.getVar("/x")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, 1)
	#assert_eq(main.evalCommands([["/get"] + ["/x"]]).value, null)

func test_parseArgs():
	cmd.setVar("/x", 1)
	pending
	#assert_eq(cmd.parseArgs([]), [])
	#assert_eq(cmd.parseArgs(["/x"]), [1])

func test_newRoutine():
	assert_eq(cmd.addRoutine(["routineA", "inf", 1, "/cmdA", "argA", 2]), Status.new())

func test_getTextBlocks():
	assert_eq(cmd.getTextBlocks("bla bla\nalo\n\nzirlit"), ["bla bla\nalo", "zirlit"])

func test_isDef():
	var def = "/def /bla x y\n /alo $x $y"
	assert_eq(cmd.isDef(def), true)

func test_convertDefBlockToCommand():
	var def = "/def /bla x y\n /alo $x $y\n /ixi $x 2"
	assert_eq(cmd.convertDefBlockToCommand(def), ["/def", "/bla", "x", "y", ",", "/alo", "$x", "$y", ",", "/ixi", "$x", "2"])

func test_arrayToVector():
	assert_eq(cmd.arrayToVector(["0", "0"]), Vector2(0.0,0.0))
	assert_eq(cmd.arrayToVector(["0", "0", "0"]), Vector3(0.0,0.0,0.0))
	assert_eq(cmd.arrayToVector(["0", "0", "0", "0"]), Vector4(0.0,0.0,0.0,0.0))

func test_evalExpr():
	assert_eq(cmd.evalExpr("5 + i", ["i"], [1]), 6)

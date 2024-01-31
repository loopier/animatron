extends GutTest

var main : Main
var cmd : CommandInterface

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child_autoqfree(main)
	cmd = main.get_node("CommandInterface")

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_getCommand():
	var aCommand = cmd.getCommandDescription("/load")
	assert_eq(aCommand.callable, cmd.loadAnimationAsset)
	assert_eq(aCommand.argsDescription, "animation:s")
	assert_eq(aCommand.description, "Load an ANIMATION asset from disk. It will create an animation with the same name as the asset. Wildcards are supported, so several animations can be loaded at once. See also: `/assets/list`.")
	assert_eq(aCommand.argsAsArray, false)
	assert_eq(aCommand.toGdScript, false)

func test_listCommands():
	assert_eq(cmd.listCommands(cmd.coreCommands).value, "
--
/actors/list
/animation/loop
/animation/property
/animations/list
/apply/scale
/assets/list
/assets/path
/behind
/bottom
/center
/children/list
/color
/commands/list
/commands/load
/create
/def
/editor/append
/editor/clear
/editor/open
/editor/open/from
/editor/property
/editor/save
/editor/save/to
/flip/h
/flip/v
/for
/front
/get
/help
/hide
/load
/log/level
/midi/cc
/midi/cc/free
/midi/free
/midi/list
/midi/noteoff
/midi/noteoff/free
/midi/noteoff/num
/midi/noteoff/num/free
/midi/noteon
/midi/noteon/free
/midi/noteon/num
/midi/noteon/num/free
/midi/noteon/num/velocity
/midi/noteon/num/velocity/free
/midi/noteon/trig
/midi/noteon/trig/free
/midi/noteon/velocity
/move
/move/x
/move/y
/offset
/offset/x
/offset/y
/opacity
/osc/remote
/osc/send
/parent
/parent/free
/play
/play/backwards
/post
/post/clear
/post/toggle
/property
/rand
/relative
/remove
/rotate
/routine
/routine/finished
/routine/free
/routine/start
/routine/stop
/routines
/scale
/scale/x
/scale/y
/set
/set/position
/show
/size
/size/x
/size/y
/state/add
/state/def
/state/free
/state/next
/states
/stop
/text/property
/top
/tween
/unload
/visible
/wait
")

func test_listAssets():
	assert_true(not cmd.listAnimationAssets().value.is_empty())

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
	cmd.setVar(["x:i", 1])
	gut.p("This one should return 1")
	var result = cmd.getVar("x")
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, 1)
	#assert_eq(main.evalCommands([["/get"] + ["/x"]]).value, null)

func test_parseArgs():
	#cmd.setVar(["x:i", 1])
	assert_true(true)
	pending
	#assert_eq(cmd.parseArgs([]), [])
	#assert_eq(cmd.parseArgs(["/x"]), [1])

func test_newRoutine():
	var result := cmd.addRoutine(["routineA", "inf", 1, "/cmdA", "argA", 2])
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, true)
	assert_eq(result.msg, "New routine 'routineA' (0 times every 1): [\"/cmdA\", \"argA\", 2]")
	assert_eq(main.routines.get_child_count(), 1)
	result = cmd.freeRoutine("routineA")
	assert_eq(main.routines.get_child_count(), 0)

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

func test_cmd_to_property():
	assert_eq(cmd._cmd_to_property("bla"), "bla")

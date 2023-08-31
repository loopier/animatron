extends GutTest

var log := preload("res://Log.gd")
var main := preload("res://main.tscn").instantiate()
var cmd: Node = main.get_node("CommandInterface")

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	cmd.remove("x", cmd.variables)
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_listCommands():
	assert_eq(cmd.listCommands().value, cmd.commands.keys())

func test_listAssets():
	assert_eq(cmd.listAssets().value, [])

func test_splitArray():
	var arr = ["/alo", ",", 1]
	assert_eq(cmd._splitArray(",", arr), [["/alo"],[1]])
	arr = ["/alo", "x", 1, ",", "/bla", "zzz"]
	assert_eq(cmd._splitArray(",", arr), [["/alo", "x", 1], ["/bla", "zzz"]])
	arr = ["/alo", "x", 1]
	assert_eq(cmd._splitArray(",", arr), [["/alo", "x", 1]])

func test_setDef():
	var def = ["/alo", "x", 1, ",", "/create", "ma", "mama"]
	assert_eq(cmd.setDef(def).value, ["/alo", ["x", 1], [["/create", "ma", "mama"]]])
	def = ["/alo", "x", 1, ",", "/create", "ma", "mama", ",", "/size", "ma", 0.5]
	assert_eq(cmd.setDef(def).value, ["/alo", ["x", 1], [["/create", "ma", "mama"], ["/size", "ma", 0.5]]])
	def = ["/red/mama", "argA", "argB", ",", "/create", "x", "mama", ",", "/speed", "x", 2]
	assert_eq(cmd.setDef(def).value, ["/red/mama", ["argA", "argB"], [["/create", "x", "mama"], ["/speed", "x", 2]]])

func test_parseCommand():
	cmd.setVar("/x", 1)
	assert_eq(cmd.parseCommand("/get", ["/x"], "").value, 1)

func test_parseArgs():
	cmd.setVar("/x", 1)
	assert_eq(cmd.parseArgs([]), [])
	assert_eq(cmd.parseArgs(["/x"]), [1])

func test_newRoutine():
	assert_eq(cmd.newRoutine(["routineA", "inf", 1, "/cmdA", "argA", 2]), Status.new())

func test_getTextBlocks():
	assert_eq(cmd.getTextBlocks("bla bla\nalo\n\nzirlit"), ["bla bla\nalo", "zirlit"])

func test_isDef():
	var def = "/def /bla x y\n /alo $x $y"
	assert_eq(cmd.isDef(def), true)

func test_convertDefBlockToCommand():
	var def = "/def /bla x y\n /alo $x $y\n /ixi $x 2"
	assert_eq(cmd.convertDefBlockToCommand(def), ["/def", "/bla", "x", "y", ",", "/alo", "$x", "$y", ",", "/ixi", "$x", "2"])

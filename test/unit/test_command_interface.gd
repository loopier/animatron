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
	var cmds = ["/alo", "x", 1]
	assert_eq(cmd.setDef(cmds), [["/alo", "x", 1]])

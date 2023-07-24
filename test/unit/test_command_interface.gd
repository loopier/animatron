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

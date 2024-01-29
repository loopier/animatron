extends GutTest

var log : Log
var main : Main
var cmd : CommandInterface

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	#cmd.remove("x", cmd.variables)
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

func test_defineState():
	var result := cmd.defineState("bla", "/blentry", "/blexit")
	assert_eq(result.msg, "") # was "Entry /def not found: /blentry"
	
	main.evalCommands([["/def", "/blentry", ",", "/post", "entry to bla"]], "")
	result = cmd.defineState("bla", "/blentry", "/blexit")
	assert_eq(result.msg, "") # "Exit /def not found: /blentry"
	
	main.evalCommands([["/def", "/blexit", ",", "/post", "exit to bla"]], "")
	result = cmd.defineState("bla", "/blentry", "/blexit")
	assert_eq(result.msg, "")

func test_addState():
	assert_eq(cmd.addState(["machineA", "stateA", "next_state_X", "next_state_B"]).msg, "")

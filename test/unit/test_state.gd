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

func test_defineState():
	assert_eq(cmd.defineState("bla", "/blentry", "/blexit").msg, "Entry /def not found: /blentry")
	main.evalCommands([["/def", "/blentry", ",", "/post", "entry to bla"]], "")
	assert_eq(cmd.defineState("bla", "/blentry", "/blexit").msg, "Exit /def not found: /blentry")
	main.evalCommands([["/def", "/blexit", ",", "/post", "exit to bla"]], "")
	assert_eq(cmd.defineState("bla", "/blentry", "/blexit").msg, "")

func test_addState():
	assert_eq(cmd.addState(["machineA", "stateA", "next_state_X", "next_state_B"]).msg, "")

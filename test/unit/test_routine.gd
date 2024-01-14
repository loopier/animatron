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

func test_addRoutine():
	var routine = ["bla",4,0.5,"/post alo"]
	assert_typeof(cmd.addRoutine(routine).value, TYPE_DICTIONARY)
	assert_eq(cmd.addRoutine(routine).value, cmd.routines["bla"])
	assert_eq(cmd.addRoutine(routine).value, {"repeats":4, "interval": 0.5, "subcommands": ["/post alo"]})
	routine = ["bla",4,0.5,"/post alo", "/post bye"]
	assert_eq(cmd.addRoutine(routine).value, {"repeats":4, "interval": 0.5, "subcommands": ["/post alo", "/post bye"]})

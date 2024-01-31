extends GutTest

var main : Main
var cmd : CommandInterface

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child_autoqfree(main)
	cmd = main.get_node("CommandInterface")

func after_each():
	#cmd.remove("x", cmd.variables)
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_addRoutine():
	var routine = ["bla",4,0.5,"/post alo"]
	var result : = cmd.addRoutine(routine)
	assert_eq(result.value, true)
	assert_eq(result.msg, "New routine 'bla' (4 times every 0.5): [\"/post alo\"]")
	var bla := cmd.routinesNode.get_node("bla")
	assert_eq(bla.command, [ "/post alo"] )
	assert_eq(bla.repeats, 4)
	assert_eq(bla.wait_time, 0.5)
	routine = ["bla",4,0.5,"/post alo", "/post bye"]
	result = cmd.addRoutine(routine)
	assert_eq(result.msg, "New routine 'bla' (4 times every 0.5): [\"/post alo\", \"/post bye\"]")
	assert_eq(bla.command, ["/post alo", "/post bye"])

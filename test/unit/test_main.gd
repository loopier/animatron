extends GutTest

var main : Main
var cmdInterface : CommandInterface


func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child(main)
	cmdInterface = main.get_node("CommandInterface")

func after_each():
	gut.p("ran teardown logger", 2)
	main.queue_free()

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_evalCommands():
	# stop upon error
	var cmds = [["/load", "default"], ["/bla", "alo", 1, 2.3], ["/create", "x", "default"]]
	var checkResult = main.evalCommands(cmds, "localhost")
	assert_eq(checkResult.type, Status.ERROR)
	assert_eq(checkResult.value, null)
	assert_eq(checkResult.msg, "Command not found: /bla")
	# should pass
	cmds = [["/load", "default"], ["/create", "x", "default"]]
	checkResult = main.evalCommands(cmds, "localhost")
	assert_eq(checkResult.type, Status.OK)
	assert_is(checkResult.value, CharacterBody2D)
	assert_typeof(checkResult.msg, TYPE_STRING)

func test_evalCommand():
	# command not found
	var cmd = ["/bla", "alo", 1, 2.3]
	var checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.ERROR)
	assert_eq(checkResult.value, null)
	assert_eq(checkResult.msg, "Command not found: /bla")
	# not enough arguments
	cmd = ["/create", "bla"]
	checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.ERROR)
	assert_eq(checkResult.value, null)
	assert_eq(checkResult.msg, "Not enough arguments - expected: 2 - received: 1")
	# more arguments than needed
	cmd = ["/load", "default", 1, 2.3]
	checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.OK)
	assert_eq(checkResult.value, true)
	assert_eq(checkResult.msg, "Loaded 1 sprites")
	# correct number of arguments
	cmd = ["/create", "x", "default"]
	checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.OK)
	assert_is(checkResult.value, CharacterBody2D)
	assert_eq(checkResult.msg, "Created new actor 'x': default")
	# no arguments
	cmd = ["/actors/list", ""]
	checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.OK)
	assert_typeof(checkResult.value, TYPE_ARRAY)
	assert_eq(checkResult.msg, "")
	# command not a callable
	cmd = ["/commands"]
	checkResult = main.evalCommand(cmd, "localhost")
	assert_eq(checkResult.type, Status.OK)
	assert_true(checkResult.value.begins_with("\nCore Commands:\n"))
	assert_true(checkResult.msg.begins_with("\nCore Commands:\n"))
	

func test_executeCommand():
	# less arguments than expected
	var cmdDescription = CommandDescription.new(func x(s: String) -> Status: return Status.ok(5, "all fine"), "str:s", "")
	var cmdArgs = []
	var checkResult = main.executeCommand(cmdDescription, cmdArgs)
	assert_eq(checkResult.type, Status.ERROR)
	assert_eq(checkResult.value, null)
	assert_eq(checkResult.msg, "Not enough arguments - expected: 1 - received: 0")
	# more arguments than expected
	cmdArgs = ["bla", 1, 2.1, "more"]
	checkResult = main.executeCommand(cmdDescription, cmdArgs)
	assert_eq(checkResult.type, Status.OK)
	assert_eq(checkResult.value, 5)
	assert_eq(checkResult.msg, "all fine")
	# exact number of arguments
	cmdArgs = ["bla"]
	checkResult = main.executeCommand(cmdDescription, cmdArgs)
	assert_eq(checkResult.type, Status.OK)
	assert_eq(checkResult.value, 5)
	assert_eq(checkResult.msg, "all fine")

func test_checkNumberNumberOfArguments():
	# less arguments than expected
	var argsDescription = CommandDescription.new(func x(): pass, "str:s int:i float:f", "").argsDescription
	var cmdArgs = []
	var checkResult = main.checkNumberOfArguments(argsDescription, cmdArgs)
	assert_eq(checkResult.type, Status.ERROR)
	assert_eq(checkResult.value, null)
	assert_eq(checkResult.msg, "Not enough arguments - expected: 3 - received: 0")
	# more arguments than expected
	cmdArgs = ["bla", 1, 2.1, "more"]
	checkResult = main.checkNumberOfArguments(argsDescription, cmdArgs)
	assert_eq(checkResult.type, Status.OK)
	assert_eq(checkResult.value, 3)
	assert_eq(checkResult.msg, "Received more arguments (4) than needed (3). Using: [\"bla\", 1, 2.1]")
	# exact number of arguments
	cmdArgs = ["bla", 1, 2.1]
	checkResult = main.checkNumberOfArguments(argsDescription, cmdArgs)
	assert_eq(checkResult.type, Status.OK)
	assert_eq(checkResult.value, 3)
	assert_eq(checkResult.msg, "")

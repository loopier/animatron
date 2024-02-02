extends GutTest

var main : Main

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_init(): 
	var cmd = CommandDescription.new(test_callable, "bla:s", "A very useful bla.")
	assert_eq(cmd.callable, test_callable)
	assert_eq(cmd.argsDescription, "bla:s")
	assert_eq(cmd.description, "A very useful bla.")

func test_callable():
	assert_true(true)
	print("called callable")

func test_execute():
	assert_eq(CommandDescription.new(test_callable, "bla:s", "A very useful bla.").execute(["/bla"]).type, Status.ERROR)

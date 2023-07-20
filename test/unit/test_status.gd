extends GutTest

var status := load("res://Status.gd")

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_status_ok():
	var status = Status.ok("x", "a message")
	assert_eq(status.type, Status.OK)
	assert_eq(status.value, "x", "Should match 'x'")
	assert_eq(status.msg, "a message", "Should match 'a message'")
	status = Status.error("an error message")
	assert_eq(status.type, Status.ERROR)
	assert_eq(status.value, null, "Should be NULL")
	assert_eq(status.msg, "an error message", "Should fail")

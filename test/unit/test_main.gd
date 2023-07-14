extends GutTest

var main := load("res://Main.gd")

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

#func test_assert_eq_on_osc_msg_received():
#	var action = main._on_osc_msg_received("/alo", [0,1], "127.0.0.1")
#	assert_eq(action, "nothing", "Should fail")

func test_assert_eq_alo():
	assert_eq(main.alo(), 0, "nose")

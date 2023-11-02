extends GutTest

var main : Main

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	add_child(main)

func after_each():
	gut.p("ran teardown logger", 2)
	main.queue_free()

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

#func test_assert_eq_on_osc_msg_received():
#	var action = main._on_osc_msg_received("/alo", [0,1], "127.0.0.1")
#	assert_eq(action, "nothing", "Should fail")

func test_createActor():
	assert_true(true, "Empty test")
	#assert_eq(main.cmdInterface.createActor("actor1", "bla"), null)
	#assert_eq(main.cmdInterface.createActor("actor1", "bla"), null)

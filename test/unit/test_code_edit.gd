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


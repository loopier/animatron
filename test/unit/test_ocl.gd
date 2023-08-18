extends GutTest

var oclFile := load("res://ocl.gd")
var ocl = OpenControlLanguage.new()

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_processReserveWord():
	assert_eq(ocl._processReservedWord("/for", ["i", 4, "/post", "$i"]), [])
	assert_eq(ocl._processReservedWord("/for", ["i", 4, "/post", "$i"]), [["/post", 0], ["/post", 1], ["/post", 2], ["/post", 4]])

func test_for():
	assert_eq(ocl._for(["i", 2, "/post", "$i"]), [["/post", 0], ["/post", 1]]) 
	assert_eq(ocl._for(["i", 4, "/post", "$i"]), [["/post", 0], ["/post", 1], ["/post", 2], ["/post", 3]]) 
	assert_eq(ocl._for(["i", 2, "/create", "x$i", "ball"]), [["/create", "x0", "ball"], ["/create", "x1", "ball"]]) 

func test__replaceVariable():
	assert_eq(ocl._replaceVariable("$i", 0, ["/post", "$i"]), ["/post", 0])
	assert_eq(ocl._replaceVariable("$i", 2, ["/scale", "bla", "$i", 0.5]), ["/scale", "bla", 2, 0.5])
	assert_eq(ocl._replaceVariable("$i", 2, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla2", 0.5, 0.5])
	
	assert_eq(ocl._replaceVariable("$i", 0, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla0", 0.5, 0.5])
	assert_eq(ocl._replaceVariable("$i", 1, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla1", 0.5, 0.5])

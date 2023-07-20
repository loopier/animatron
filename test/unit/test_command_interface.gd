extends GutTest

var log := preload("res://Log.gd")
var main := preload("res://main.tscn").instantiate()
var oscInterface: OscInterface = main.get_node("OscInterface")

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	oscInterface.remove("x", oscInterface.variables)
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_getVar():
	# types
	$OscInterface.setVar("/x", 1)
	assert_true(typeof($OscInterface.getVar("/x")) == TYPE_INT)
	assert_false(typeof($OscInterface.getVar("/x")) == TYPE_STRING)
	$OscInterface.setVar("/x", "1")
	assert_false(typeof($OscInterface.getVar("/x")) == TYPE_INT)
	assert_true(typeof($OscInterface.getVar("/x")) == TYPE_STRING)
	assert_true(typeof(int($OscInterface.getVar("/x"))) == TYPE_INT)
	$OscInterface.setVar("/x", "1.0")
	assert_true(typeof(float($OscInterface.getVar("/x"))) == TYPE_FLOAT)
	assert_true(typeof(int($OscInterface.getVar("/x"))) == TYPE_INT)
	$OscInterface.setVar("/x", "bla")
	assert_eq(float($OscInterface.getVar("/x")), 0)
	assert_eq(int($OscInterface.getVar("/x")), 0)

func test_setVar():
	assert_eq($OscInterface.getVar("x"), null)
	var avar = $OscInterface.setVar("x", 0)
	assert_eq($OscInterface.getVar("x"), 0)

func test_assert_eq_removeVar():
	assert_eq($OscInterface.getVar("x"), null, "Should be null")
	var avar = $OscInterface.setVar("x", 1)
	assert_eq($OscInterface.getVar("x"), 1)
	$OscInterface.remove("x", $OscInterface.variables)
	assert_eq($OscInterface.getVar("x"), null)

func test_oscStrToDict():
	var dict: Dictionary
	assert_eq($OscInterface.oscStrToDict(""), dict)
	dict["/zero"] = ["0"]
	assert_eq($OscInterface.oscStrToDict("/zero 0"), dict)

func test_parseCmd():
	var sender = "127.0.0.1"
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
#	assert_eq($OscInterface.parseCmd("/set", ["/x", 2], sender), 2)
#	assert_eq($OscInterface.parseCmd("/get", ["/x"], sender), 2)
#	assert_eq($OscInterface.parseCmd("/set", ["/x", 3.14], sender), 3.14)
#	assert_eq($OscInterface.parseCmd("/get", ["/x"], sender), 3.14)
#	assert_eq($OscInterface.parseCmd("/set", ["/x", "bla"], sender), "bla")
#	assert_eq($OscInterface.parseCmd("/get", ["/x"], sender), "bla")
#	assert_eq($OscInterface.parseCmd("/get", ["/y"], sender), null)
#	assert_eq($OscInterface.parseCmd("/noexistentcmd", ["/y", 2, 0.5, "bla"], sender), null)
	
	assert_eq($OscInterface.parseCmd("/create", ["bla", "blanim"], sender), true)
	assert_eq($OscInterface.parseCmd("/new", ["bla", "blanim"], sender), true)

func test_getActor():
	assert_eq(main.get_node("OscInterface").getActor("bla"), null)

func test_getImageSequence():
	assert_eq(oscInterface.loadImageSequence("user://assets/blob"), "blob", "Should pass")
	assert_eq(oscInterface.loadImageSequence("user://assets/bla"), "bla", "Should pass")

func test_loadAsset():
	assert_true(oscInterface.loadAsset("blob").value.has_animation("blob"))

func test_listAssets():
	assert_eq(oscInterface.listAssets().value, false)

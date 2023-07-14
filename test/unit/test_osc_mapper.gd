extends GutTest

var obj := preload("res://OscMapper.gd")
var mapper: OscMapper

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	OscMapper.remove("x", OscMapper.variables)
	gut.p("ran teardown logger", 2)

func before_all():
	mapper = OscMapper.new()
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_getVar():
	# types
	OscMapper.setVar("/x", 1)
	assert_true(typeof(OscMapper.getVar("/x")) == TYPE_INT)
	assert_false(typeof(OscMapper.getVar("/x")) == TYPE_STRING)
	OscMapper.setVar("/x", "1")
	assert_false(typeof(OscMapper.getVar("/x")) == TYPE_INT)
	assert_true(typeof(OscMapper.getVar("/x")) == TYPE_STRING)
	assert_true(typeof(int(OscMapper.getVar("/x"))) == TYPE_INT)
	OscMapper.setVar("/x", "1.0")
	assert_true(typeof(float(OscMapper.getVar("/x"))) == TYPE_FLOAT)
	assert_true(typeof(int(OscMapper.getVar("/x"))) == TYPE_INT)
	OscMapper.setVar("/x", "bla")
	assert_eq(float(OscMapper.getVar("/x")), 0)
	assert_eq(int(OscMapper.getVar("/x")), 0)

func test_setVar():
	assert_eq(OscMapper.getVar("x"), null)
	var avar = OscMapper.setVar("x", 0)
	assert_eq(OscMapper.getVar("x"), 0)

func test_assert_eq_removeVar():
	assert_eq(OscMapper.getVar("x"), null, "Should be null")
	var avar = OscMapper.setVar("x", 1)
	assert_eq(OscMapper.getVar("x"), 1)
	OscMapper.remove("x", OscMapper.variables)
	assert_eq(OscMapper.getVar("x"), null)

func test_oscStrToDict():
	var dict: Dictionary
	assert_eq(OscMapper.oscStrToDict(""), dict)
	dict["/zero"] = ["0"]
	assert_eq(OscMapper.oscStrToDict("/zero 0"), dict)

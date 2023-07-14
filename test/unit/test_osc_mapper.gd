extends GutTest

var obj := preload("res://OscMapper.gd")
var mapper: OscMapper

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	OscMapper.remove("x")
	gut.p("ran teardown logger", 2)

func before_all():
	mapper = OscMapper.new()
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)
#
#func test_assert_eq_number_equal():
#	assert_eq('asdf', 'asdf', "Should pass")
#
#func test_assert_true_with_true():
#	assert_true(true, "Should pass, true is true")

func test_assert_eq_getVar():
	assert_eq(OscMapper.getVar("bla"), null, "Should be null")
	assert_eq(OscMapper.getVar("/var1"), 0, "Should be 0")
	assert_true(OscMapper.variables.has("/var1"), "Should exist")
	assert_false(OscMapper.variables.has("/nonexistent"), "Should fail")
	assert_eq(OscMapper.getVar("/zero"), 0, "Should be 0")
	assert_eq(OscMapper.getVar("/one"), 1, "Should be 1")
	assert_eq(OscMapper.getVar("/pointone"), 0.1, "Should be 0.1")
	assert_eq(OscMapper.getVar("/bla"), "bla", "Should be 'bla'")
	assert_eq(OscMapper.getVar("/true"), true, "Should be true")
	assert_eq(OscMapper.getVar("/false"), false, "Should be true")

func test_assert_eq_setVar():
	assert_eq(OscMapper.getVar("x"), null)
	var avar = OscMapper.setVar("x", 0)
	assert_eq(OscMapper.getVar("x"), 0)

func test_assert_eq_removeVar():
	assert_eq(OscMapper.getVar("x"), null, "Should be null")
	var avar = OscMapper.setVar("x", 1)
	assert_eq(OscMapper.getVar("x"), 1)
	OscMapper.remove("x")
	assert_eq(OscMapper.getVar("x"), null)

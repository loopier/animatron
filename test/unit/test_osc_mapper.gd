extends GutTest

var obj := preload("res://OscMapper.gd")
var mapper: OscMapper

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
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
	assert_eq(mapper.getVar("bla"), null, "Should be null")
	assert_eq(mapper.getVar("/var1"), 0, "Should be 0")
	assert_true(mapper.memory.has("/var1"), "Should exist")
	assert_false(mapper.memory.has("/nonexistent"), "Should fail")
	assert_eq(mapper.getVar("/zero"), 0, "Should be 0")
	assert_eq(mapper.getVar("/one"), 1, "Should be 1")
	assert_eq(mapper.getVar("/pointone"), 0.1, "Should be 0.1")
	assert_eq(mapper.getVar("/bla"), "bla", "Should be 'bla'")
	assert_eq(mapper.getVar("/true"), true, "Should be true")
	assert_eq(mapper.getVar("/false"), false, "Should be true")

func test_assert_eq_setVar():
	assert_eq(mapper.getVar("x"), null)
	var avar = mapper.setVar("x", 0)
	assert_eq(mapper.getVar("x"), 0)

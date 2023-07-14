extends GutTest

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)
#
#func test_assert_eq_number_equal():
#	assert_eq('asdf', 'asdf', "Should pass")
#
#func test_assert_true_with_true():
#	assert_true(true, "Should pass, true is true")

func test_assert_eq_getLevel():
#	log.setLevel("LOG_LEVEL_DEBUG")
	var levelValue = Log.getLevel()
	var level = Log.getLevelName()
	assert_eq(level, "INFO", "Should be INFO")

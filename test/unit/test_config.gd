extends GutTest

var config = Config.new()

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_loadConfig():
	var status = config.loadConfig("bla")
	print(status.msg)
	assert_eq(status.value, ProjectSettings.globalize_path("user://config/bla"))

func test_getPathWithDefaultDir():
	assert_eq(Helper.getPathWithDefaultDir("bla", "alo"), "alo/bla")
	assert_eq(Helper.getPathWithDefaultDir("alo/bla", "zirlit"), "alo/bla")

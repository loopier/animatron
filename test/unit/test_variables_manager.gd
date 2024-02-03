extends GutTest

var vm : VariablesManager

func before_each():
	gut.p("ran setup logger", 2)

func after_each():
	gut.p("ran teardown logger", 2)

func before_all():
	gut.p("ran run setup logger", 2)
	vm = preload("res://VariablesManager.gd").new()

func after_all():
	gut.p("ran run teardown logger", 2)

func test_getter():
	#assert_almost_eq(vm.getValue("time"), 3.0, 3.0)
	assert_is(vm.getValue("rnd"), RandomNumberGenerator)

func test_setter():
	vm.setValue("a", 0)
	assert_eq(vm.getValue("a"), 0)
	vm.setValue("b", 0.4)
	assert_eq(vm.getValue("a"), 0)
	assert_eq(vm.getValue("b"), 0.4)
	vm.setValue("c", true)
	assert_eq(vm.getValue("a"), 0)
	assert_eq(vm.getValue("b"), 0.4)
	assert_true(vm.getValue("c"))
	vm.setValue("c", false)
	assert_false(vm.getValue("c"))
	vm.setValue("c", "bla")
	assert_eq(vm.getValue("c"), "bla")
	assert_null(vm.getValue("z"))

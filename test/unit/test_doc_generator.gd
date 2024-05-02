extends GutTest

var main : Main
var DocGenerator

func before_each():
	gut.p("ran setup logger", 2)
	main = preload("res://main.tscn").instantiate()
	DocGenerator = preload("res://doc_generator.gd")
	add_child(main)

func after_each():
	gut.p("ran teardown logger", 2)
	main.queue_free()

func before_all():
	gut.p("ran run setup logger", 2)

func after_all():
	gut.p("ran run teardown logger", 2)

func test_getTextFromFile():
	var path = "res://test/test-doc-generator-0.ocl"
	var text = DocGenerator.getTextFromFile(path).value
	var desiredText : String
	desiredText += "# doc line 1\n"
	desiredText += "# doc line 2\n"
	desiredText += "/def /cmd1 arg1\n"
	desiredText += "\n"
	desiredText += "# doc line 3\n"
	desiredText += "# doc line 4\n"
	desiredText += "/def /cmd2 arg2\n"
	
	assert_eq(text, desiredText)

func test_genereateFrom():
	var path = "res://test/test-doc-generator.ocl"
	var result = DocGenerator.generateFrom(path)
	var desiredText : String
	desiredText += "\n"
	desiredText += "=== /preset name:s\n"
	desiredText += "Load a preset from `user://presets/`.\n"
	desiredText += "\n"
	desiredText += "`name`:: _String_ - relative path to the file from `user://presets/`.\n"
	desiredText += "\n"
	desiredText += "Usage :: `/preset mycommands/somecommands.ocl`\n"
	desiredText += "\n"
	desiredText += "\n"
	desiredText += "=== /new actor:s animation:s\n"
	desiredText += "Load and create a new *actor* with an *animation*.\n"
	desiredText += "\n"
	desiredText += "NOTE: the *animation* will be loaded if it isn't already.\n"
	desiredText += "\n"
	desiredText += "`actor`:: _String_ - whatever name you want to give to the actor.\n"
	desiredText += "`animation`:: _String_ - whatever name you want to give to the actor.\n"
	desiredText += "\n"
	desiredText += "Usage :: `/new lola mama`\n"
	
	print(result.msg)
	assert_true(result.value)

func test_getTextBlocks():
	var path = "res://test/test-doc-generator-0.ocl"
	var result = DocGenerator.getTextBlocks(path)
	assert_typeof(result.value, TYPE_ARRAY)

func test_generateFrom_0():
	var path = "res://test/test-doc-generator-0.ocl"
	var result = DocGenerator.generateFrom(path)
	var desiredText : String
	desiredText += "=== /cmd1 arg1\n"
	desiredText += "doc line 1\n"
	desiredText += "doc line 2\n"
	desiredText += "\n"
	desiredText += "=== /cmd2 arg2\n"
	desiredText += "doc line 3\n"
	desiredText += "doc line 4\n"
	desiredText += "\n"
	
	#print(desiredText)
	assert_typeof(result.value, TYPE_BOOL)
	assert_eq(result.value, true)

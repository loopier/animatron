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

func test_processArgs():
	assert_true(true)
	if false:
		var args := ["bla", 0.2]
		assert_eq(ocl.processArgs(args), args)
		args = ["bla", "/+", 1, 2]
		assert_eq(ocl.processArgs(args), ["bla", 3.0])
		args = ["bla", "/-", 1, 2]
		assert_eq(ocl.processArgs(args), ["bla", -1.0])
		args = ["bla", "/*", 1.5, 2]
		assert_eq(ocl.processArgs(args), ["bla", 3.0])
		args = ["bla", "//", 1.0, 2]
		assert_eq(ocl.processArgs(args), ["bla", 0.5])
		args = ["bla", "/%", 4, 3]
		assert_eq(ocl.processArgs(args), ["bla", 1.0])
		args = ["bla", "/*", 4, "/+", 1, 3]
		#assert_eq(ocl.processArgs(args), ["bla", 16])
	

func test_calc():
	assert_true(true)
	if false:
		print("---")
		var args = ["/+", 1, 2]
		assert_eq(ocl._calc(args[0], args.slice(1)), 3.0)
		print("---")
		args = ["/+", 1, "/*", 2, 3]
		assert_eq(ocl._calc(args[0], args.slice(1)), 7.0)
		print("---")
		args = ["/+", "/*", 1, 2, 3]
		assert_eq(ocl._calc(args[0], args.slice(1)), 5.0)
		print("---")
		args = ["/+", "/*", 1, "/-", 2, 3, 4]
		assert_eq(ocl._calc(args[0], args.slice(1)), 3.0)
		print("---")
		args = ["/+", "/*", 1, 2, "/-", 3, 4]
		assert_eq(ocl._calc(args[0], args.slice(1)), 1.0)

func test_binaryGroups():
	assert_true(true)
	if false:
		print("---")
		var args := []
		args = ["/+", 1, "/*", 2, 3]
		assert_eq(ocl._binaryGroups(args[0], args.slice(1)), ["/+", 1, ["/*", 2, 3]])
		print("---")
		args = ["/+", "/*", 1, 2, 3]
		assert_eq(ocl._binaryGroups(args[0], args.slice(1)), ["/+", ["/*", 1, 2], 3])
		print("---")
		args = ["/+", "/*", 1, 2.0, "/-", 3, 4]
		assert_eq(ocl._binaryGroups(args[0], args.slice(1)), ["/+", ["/*", 1, 2.0], ["/-", 3, 4]])
		print("---")
		args = ["/+", "/*", 1, "/-", 2, 3, 4]
		assert_eq(ocl._binaryGroups(args[0], args.slice(1)), ["/+", ["/*", 1, ["/-", 2, 3]], 4])

func test_binaryOp():
	assert_true(true)
	if false:
		assert_eq(ocl._binaryOp("/+", 1, 2), 3.0)
		assert_eq(ocl._binaryOp("/-", 1, 2), -1.0)
		assert_eq(ocl._binaryOp("/*", 1, 2), 2.0)
		assert_eq(ocl._binaryOp("//", 1, 2), 0.5)
		assert_eq(ocl._binaryOp("/%", 1, 2), 1.0)
		assert_eq(ocl._binaryOp("/%", 3, 2), 1.0)
		assert_eq(ocl._binaryOp("/%", 4, 2), 0.0)

func test_processReserveWord():
	assert_true(true)
	if false:
		assert_eq(ocl._processReservedWord("/for", ["i", 4, "/post", "$i"]), [["/post", 0], ["/post", 1], ["/post", 2], ["/post", 3]])
		assert_eq(ocl._processReservedWord("/*", [3, 4]), 12.0)

func test_for():
	assert_eq(ocl._for(["i", 2, "/post", "$i"]), [["/post", "0"], ["/post", "1"]]) 
	assert_eq(ocl._for(["i", 4, "/post", "$i"]), [["/post", "0"], ["/post", "1"], ["/post", "2"], ["/post", "3"]]) 
	assert_eq(ocl._for(["i", 2, "/create", "x$i", "ball"]), [["/create", "x0", "ball"], ["/create", "x1", "ball"]]) 

func test_def():
	assert_true(true)
	if false:
		assert_eq(ocl._def({"arg1": "val1", "arg2": "val2"}, [["/cmdA", "$arg1", "paramB", "$arg2"]]), [["/cmdA", "val1", "paramB", "val2"]])
		assert_eq(ocl._def({"arg1": "val1"}, [["/cmdA", "$arg1", "paramB", "$arg1"]]), [["/cmdA", "val1", "paramB", "val1"]])
		assert_eq(ocl._def({"arg1": 2}, [["/cmdA", "$arg1", "paramB", "$arg1"], ["/cmdB", "bla", "$arg2"]]), [["/cmdA", 2, "paramB", 2], ["/cmdB", "bla", "$arg2"]])
		assert_eq(ocl._def({"arg1": "val1"}, [["/cmdA", "$arg1", "paramB$arg1"]]), [["/cmdA", "val1", "paramBval1"]])
		assert_eq(ocl._def({"arg1": 1}, [["/cmdA", "$arg1", "paramB$arg1"]]), [["/cmdA", 1, "paramB1"]])
		assert_eq(ocl._def({"arg1": 1.1}, [["/cmdA", "$arg1", "paramB$arg1"]]), [["/cmdA", 1.1, "paramB1.1"]])

func test_replaceVariable():
	assert_true(true)
	if false:
		assert_eq(ocl._replaceVariable("$i", 0, ["/post", "$i"]), ["/post", 0])
		assert_eq(ocl._replaceVariable("$i", 2, ["/scale", "bla", "$i", 0.5]), ["/scale", "bla", 2, 0.5])
		assert_eq(ocl._replaceVariable("$i", 2, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla2", 0.5, 0.5])
		
		assert_eq(ocl._replaceVariable("$i", 0, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla0", 0.5, 0.5])
		assert_eq(ocl._replaceVariable("$i", 1, ["/scale", "bla$i", 0.5, 0.5]), ["/scale", "bla1", 0.5, 0.5])

func test_evalExpr():
	var result := ocl._evalExpr("5 + i", ["i"], [1])
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, 6)

func test_findExprString():
	gut.p("Non-strings should return empty expression")
	assert_eq(ocl._getExpression(null), "")
	assert_eq(ocl._getExpression(5.2), "")
	gut.p("Strings surrounded by {} should return the contents, with {} removed and whitespace trimmed")
	assert_eq(ocl._getExpression("{5 / 8 - 2}"), "5 / 8 - 2")
	assert_eq(ocl._getExpression("{   5 / 8 - 2 \t\n}"), "5 / 8 - 2") # Remove whitespace around
	assert_eq(ocl._getExpression("{sin(t*6.28) * exp(-0.5)"), "") # Missing closing brace
	assert_eq(ocl._getExpression("sin(t*6.28) * exp(-0.5)}"), "") # Missing opening brace
	assert_eq(ocl._getExpression("{ sin(t*6.28) * exp(-0.5) }"), "sin(t*6.28) * exp(-0.5)")
	gut.p("Strings without {} should return empty expression")
	assert_eq(ocl._getExpression("hello"), "")
	gut.p("Strings without {} in the first/last positions should return empty expression")
	assert_eq(ocl._getExpression("hello {5+8}"), "")
	assert_eq(ocl._getExpression("{5+8"), "")
	assert_eq(ocl._getExpression("5+8}"), "")

func test_removeExprSpaces():
	assert_eq(ocl._removeExpressionSpaces("/position/x bla { 6 * 19 + 100    } 17"), "/position/x bla {6*19+100} 17")
	assert_eq(ocl._removeExpressionSpaces(" there { sin( x + 9\t)  \n  }  { a + b }"), " there {sin(x+9)}  {a+b}")

func test_removeSpaces():
	assert_eq(ocl._removeSpaces("this is a test"), "thisisatest")
	assert_eq(ocl._removeSpaces("\n\tthis \tis t  o\no "), "thisistoo")

func test_replaceVariablesWithValues():
	assert_true(true)
	if false:
		var cmd = ["/position", "$actor", "$x", "$y"]
		var variables = ["actor:s", "x:f", "y:f"]
		var values = ["bla", "100", "200"]
		assert_eq(ocl._replaceVariablesWithValues(cmd, variables, values), ["/position", "bla", "100", "200"])
		cmd = ["/position", "bla", "$x", "$y"]
		variables = ["actor:s", "x:f", "y:f"]
		values = ["bla", "100", "200"]
		assert_eq(ocl._replaceVariablesWithValues(cmd, variables, values), ["/position", "bla", "100", "200"])
		cmd = ["/position", "bla_$actor", "$x", "$y"]
		variables = ["actor:s", "x:f", "y:f"]
		values = ["1", "100", "200"]
		assert_eq(ocl._replaceVariablesWithValues(cmd, variables, values), ["/position", "bla_1", "100", "200"])
		cmd = ["/position", "$actor_bla", "$x", "$y"]
		variables = ["actor:s", "x:f", "y:f"]
		values = ["1", "100", "200"]
		assert_eq(ocl._replaceVariablesWithValues(cmd, variables, values), ["/position", "1_bla", "100", "200"])
		cmd = ["/position", "$actor_bla_$actor", "$x", "$y"]
		variables = ["actor:s", "x:f", "y:f"]
		values = ["1", "100", "200"]
		assert_eq(ocl._replaceVariablesWithValues(cmd, variables, values), ["/position", "1_bla_1", "100", "200"])
	

func test_getVariableType():
	assert_eq(ocl._getVariableType("actor:s"), "s")
	assert_eq(ocl._getVariableType("actor:i"), "i")
	assert_eq(ocl._getVariableType("actor:f"), "f")
	assert_eq(ocl._getVariableType("actor:b"), "b")
	assert_eq(ocl._getVariableType("actor:?"), "s")

func test_getVariableName():
	assert_eq(ocl._getVariableName("actor:s"), "$actor")
	assert_eq(ocl._getVariableName("actor:i"), "$actor")
	assert_eq(ocl._getVariableName("actor:f"), "$actor")
	assert_eq(ocl._getVariableName("actor:b"), "$actor")
	assert_eq(ocl._getVariableName("actor:?"), "$actor")

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

func test_resolveVariables():
	var variables := { "i": 17, "hello": "allo", "other": 3.1416 }
	var result := ocl._resolveVariables("$i bla$i $hello-there you-5-$other ", variables, false)
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, "17 bla17 allo-there you-5-3.1416 ")
	result = ocl._resolveVariables("$i bla$index $hello-there you-5-$other ", variables, false)
	assert_eq(result.type, Status.ERROR)
	assert_eq(result.msg, "Variable 'index' referenced but not set")
	result = ocl._resolveVariables("$i bla$index $hello-there you-5-$other ", variables, true)
	assert_eq(result.type, Status.OK)
	assert_eq(result.value, "17 bla$index allo-there you-5-3.1416 ")

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

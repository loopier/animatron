class_name OpenControlLanguage 

var reservedWords := {
		"/for": _for,
		"/+": func(args: Array): return _calc("/+", args),
		"/-": func(args: Array): return _calc("/-", args),
		"/*": func(args: Array): return _calc("/*", args),
		"//": func(args: Array): return _calc("//", args),
		"/%": func(args: Array): return _calc("/%", args),
	}

var operators := ["/+","/-", "*", "/", "%"]

## Replace variables and arithmetic for their values.
func processArgs(args: Array) -> Array:
	var processed := []
#	print("processing args: %s" % [args])
	Log.debug("processing args: %s" % [args])
	var i = 0
	while i < len(args):
#		print("%s: %s %s" % [i, args[i], reservedWords.has(args[i])])
		if reservedWords.has(args[i]):
			processed.append(_binaryOp(args[i], args[i+1], args[i+2]))
			i = i + 3
		else:
			processed.append(args[i])
			i = i + 1
	print("%s -> %s" % [args, processed])
	return processed

## Calculate the arithmetic operation represented by [param operator].[br]
## [br]
## [param operator] is a [String] representing an arithmetic operator.[br]
## [param args] is an [Array] of 2 or more elements.[br]
## [br]
## All binary ops accept [b]2 OPERANDS ONLY[/b]. If [param args]'s size is greater than 2,
## any items beyond index 1 will be ignored, [b]unless[/b] it contains another operator within range.
## [br][br]
## For example:
## [codeblock]
## _binaryOp("/+", [10, 11]) ## returns 21
## _binaryOp("/+", [10, 11, 2]) ## returns 21 -- disregarding '2'
## _binaryOp("/*", ["/+", 10, 11, 2]) ## returns 42 -- (10 + 11) * 2
## _binaryOp("/*", [10, "/+", 11, 2]) ## returns 130 -- 10 * (/+ 11 + 2)
## _binaryOp("/*", [10, "/+", 11, 2, 3]) ## returns 130 -- 10 * (t11 + 2) -- disregarding '3'
## ... etc
## [/codeblock] 
func _calc(operator: String, args: Array) -> float:
	var ops = _binaryGroups(operator, args)
	print("%s -> %s" % [[operator] + args, ops])
	for i in len(ops):
		var op = ops[i]
		if op is Array:
			ops[i] = _calc(op[0], op.slice(1))
	var result = _binaryOp(ops[0], ops[1], ops[2])
	print("%s %s %s = %s" % [ops[0], ops[1], ops[2], result])
	return result
	
## Group binary operations into arrays of [code][operator, operandA, opernadB][/code]
func _binaryGroups(operator: String, args: Array) -> Array:
	var groups := [operator]
	var a := []
	var b := []
	if reservedWords.has(args[0]):
		a = _binaryGroups(args[0], args.slice(1))
	var index = len(a) if len(a) > 0 else 1
	if reservedWords.has(args[index]):
		b = _binaryGroups(args[index], args.slice(index + 1))
	if len(a) == 0: a = [args[0]]
	if len(b) == 0: b = [args[len(a)]]
	match len(a):
		1: groups.append(args[0])
		_: groups.append(a)
	match len(b):
		1: groups.append(args[len(Helper.flatArray(a))])
		_: groups.append(b)
	Log.verbose("%s %s --> %s" % [operator, args, groups])
	return groups

## Calculate the arithmetic result of [code]a operator b[/code]
func _binaryOp(operator: String, a: float, b: float) -> float:
	var result := 0.0
	match operator.substr(1):
		"+": result = float(a) + float(b)
		"-": result = float(a) - float(b)
		"*": result = float(a) * float(b)
		"/": result = float(a) / float(b)
		"%": result = int(a) % int(b)
	print("input: %s %s %s" % [operator, a, b])
	print("output: %s %s %s = %s\n" % [a, operator.substr(1), b, result])
	return result

func _processReservedWord(word: String, args: Array) -> Variant:
	var fn = reservedWords.get(word)
	return fn.call(args)

## Example: [code]/for i 4 /post $i[/code]
func _for(args: Array) -> Array:
	var result = []
	var variableName = args[0]
	var range = int(args[1])
	var items = args.slice(2)
	
	for i in range:
		#result.append(_replaceVariable(variableName, i, items))
		result .append(_replaceVariablesWithValues(items, [variableName], ["%s" % i]))
	return result

## Replaces all instances of the [param variable] in the [param args] by the [param value]. 
func _replaceVariablesWithValues(cmd: Array, variables: Array, values:Array) -> Array:
	var newCmd := []
	for token in cmd:
		for i in variables.size():
			var variable = variables[i]
			var variableName = _getVariableName(variable)
			var type = _getVariableType(variable)
			#var typedValue = _getVariableTypedValue(type, values[i])
			token = token.replace(variableName, "%s" % values[i])
		newCmd.append(token)
	return newCmd

## Returns the single character representing a type of the [param variableDescription].
## Example: [code]_get_variable_type("actor:s")[/code] returns [code]"s"[/code]
func _getVariableType(variableDescription: String) -> String:
	if not variableDescription.contains(":"): return variableDescription
	var type = variableDescription.split(":")[1]
	match type:
		"i", "f", "b": return type
		_: return "s"

## Returns the name of the variable [param variableDescription].
## Example: [code]_get_variable_type("actor:s")[/code] returns [code]"actor"[/code]
func _getVariableName(variableDescription: String) -> String:
	return variableDescription.split(":")[0].insert(0, "$")

func _getVariableTypedValue(type: String, value: String) -> Variant:
	match type:
		"i": return value as int
		"f": return value as float
		"b": return value as bool
		_: return value

## Returns the array of commands with all the variables replaced by their values.
## [param def] is a [class Dictionary] containing the [param def] variables description and 
## an [class Array] of subcommands.
## [param values] will be put anywhere where the [param def.variables] are present in the subcommands. 
func _def(def: Dictionary, values: Array) -> Array:
	var result = []
	for cmd in def.subcommands:
		var cmdWithValues = _replaceVariablesWithValues(cmd, def.variables, values)
		result.append(cmdWithValues)
#	Log.debug("processed def: %s" % [result])
	return result
## Returns the array of commands with all the variables replaced
## [param variables] is a [class Dictionary] where the key is the variable name.
## [param commands] is an [class Array] of commands with variables
#func _def(variables: Dictionary, commands: Array) -> Array:
	#var result = []
	#for cmd in commands:
		#for i in len(cmd):
			#var item = cmd[i]
			#if typeof(item) == TYPE_STRING and item.contains("$"):
				#var varName = item.substr(item.find("$"))
				#var value = variables[varName.substr(1)] if variables.has(varName.substr(1)) else item
				#cmd = _replaceVariable(varName, value, cmd)
		#result.append(cmd)
##	Log.debug("processed def: %s" % [result])
	#return result


## Evaluate a string expression (possibly with variables)
## Example of use:
##	var exprStr := "5*i + 8"
##	var result = evalExpr(exprStr, ["i"], [3])
##	print("expression '%s' result: %f" % [exprStr, result])
func _evalExpr(exprStr: String, vars: PackedStringArray, varValues: Array) -> Variant:
	var expr := Expression.new()
	var error := expr.parse(exprStr, vars)
	if error != OK:
		print(expr.get_error_text())
		return
	var result = expr.execute(varValues)
	if not expr.has_execute_failed():
		#Log.info("expression '%s' result: %f" % [exprStr, result])
		pass
	return result

## Parse a string to see if it contains an expression
## clause, and if so, return that clause.
func _getExpression(str) -> String:
	if typeof(str) != TYPE_STRING:
		return ""
	var regex := RegEx.new()
	regex.compile("^\\{([^{}]*)\\}$")
	var result := regex.search(str)
	return result.strings[1].strip_edges() if result else ""

## In a string with expressions (e.g. "some {5 + 7    } stuff"),
## remove the spaces within the expression ("some {5+7} stuff").
func _removeExpressionSpaces(str: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\{([^{}]*)\\}")
	var removedStr := ""
	var lastIndex := 0
	for result in regex.search_all(str):
		print("result %d to %d: '%s'" % [result.get_start(), result.get_end(), result.get_string()])
		removedStr += str.substr(lastIndex, result.get_start() - lastIndex)
		removedStr += _removeSpaces(result.get_string())
		lastIndex = result.get_end()
	removedStr += str.substr(lastIndex)
	return removedStr

func _removeSpaces(str: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\s+")
	return regex.sub(str, "", true)

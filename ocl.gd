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
	var variableName = "$%s" % [args[0]]
	var range = int(args[1])
	var items = args.slice(2)
	
	for i in range:
		result.append(_replaceVariable(variableName, i, items))
	return result

## Replaces all instances of the [param variable] in the [param args] by the [param value]. 
func _replaceVariable(variable: String, value: Variant, args: Array) -> Array:
	var newArgs = args.duplicate()
	for i in len(newArgs):
		if typeof(newArgs[i]) == TYPE_STRING and variable in newArgs[i]:
			# just replace by the value if it's not part of a longer string
			if len(newArgs[i]) == len(variable):
				newArgs[i] = value
			else:
				newArgs[i] = newArgs[i].replace(variable, "%s" % [value])
	return newArgs

## Returns the array of commands with all the variables replaced
## [param variables] is a [class Dictionary] where the key is the variable name.
## [param commands] is an [class Array] of commands with variables
func _def(variables: Dictionary, commands: Array) -> Array:
	var result = []
	for cmd in commands:
		for i in len(cmd):
			var item = cmd[i]
			if typeof(item) == TYPE_STRING and item.contains("$"):
				var varName = item.substr(item.find("$"))
				var value = variables[varName.substr(1)] if variables.has(varName.substr(1)) else item
				cmd = _replaceVariable(varName, value, cmd)
		result.append(cmd)
#	Log.debug("processed def: %s" % [result])
	return result


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
		Log.info("expression '%s' result: %f" % [exprStr, result])
	return result

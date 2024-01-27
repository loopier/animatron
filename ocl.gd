class_name OpenControlLanguage

var rnd := RandomNumberGenerator.new()

## Example: [code]/for i 4 /post bla_$i or $i[/code]
func _for(args: Array) -> Array:
	var result = []
	var variableName = args[0]
	var range = int(args[1])
	var items = args.slice(2)
	for i in range:
		result .append(_parseVariables(items, [variableName], ["%s" % i]))
	return result

## Returns the array of commands with all the variables replaced by their values.
## [param def] is a [class Dictionary] containing the [param def] variables description and 
## an [class Array] of subcommands.
## [param values] will be put anywhere where the [param def.variables] are present in the subcommands. 
func _def(def: Dictionary, values: Array) -> Array:
	var result = []
	for cmd in def.subcommands:
		var cmdWithValues = _parseVariables(cmd, def.variables, values)
		result.append(cmdWithValues)
#	Log.debug("processed def: %s" % [result])
	return result

## Replaces all instances of the [param variable] in the [param args] by the [param value]. 
func _parseVariables(cmd: Array, cmdVariables: Array, cmdValues:Array) -> Array:
	var newCmd := []
	var appVariables = VariablesManager.getAll()
	for token in cmd:
		# it's better to parse def variables first to avoid partial-match with global variables
		# this must be fixed at some point
		for i in cmdVariables.size():
			var variable = cmdVariables[i]
			var variableName = _getVariableName(variable)
			var type = _getVariableType(variable)
			var value = cmdValues[i] if i < cmdValues.size() else []
			#var typedValue = _getVariableWithCorrectType(type, values[i])
			
			# '...' describes an arbitrary number of arguments
			# this can only happen in the last argument, so we get the rest of 
			# possible arguments as string
			if type == "...": value = " ".join(cmdValues.slice(i))
			
			var expr := _getExpression(value)
			if not expr.is_empty():
				value = _evalExpr(expr, cmdVariables, cmdVariables)
				
			#if appVariables.has(variableName): 
				#Log.warn("Overriding global variable: %s(%s) -> %s" % [appVariables, VariablesManager.getValue(variableName), value])
				
			token = token.replace(variableName, "%s" % value)
		
		for k in appVariables.keys():
			var variableName = "$%s" % k
			var value = appVariables[k]
			if typeof(value) == TYPE_CALLABLE: value = value.call()
			value = "%s" % value
			token = token.replace(variableName, value)
		
		newCmd.append(token)
	return newCmd

func _getValue(variable: Variant) -> Variant:
	var value: Variant
	return value

## Returns the single character representing a type of the [param variableDescription].
## Example: [code]_get_variable_type("actor:s")[/code] returns [code]"s"[/code]
func _getVariableType(variableDescription: String) -> String:
	if not variableDescription.contains(":"): return variableDescription
	var type = variableDescription.split(":")[1]
	match type:
		"i", "f", "b", "...": return type
		_: return "s"

## Returns the name of the variable [param variableDescription].
## Example: [code]_get_variable_type("actor:s")[/code] returns [code]"actor"[/code]
func _getVariableName(variableDescription: String) -> String:
	return variableDescription.split(":")[0].insert(0, "$")

func _getVariableWithCorrectType(type: String, value: String) -> Variant:
	match type:
		"i": return value as int
		"f": return value as float
		"b": return value as bool
		_: return value

## Evaluate a string expression (possibly with variables)
## Example of use:
##	var exprStr := "5*i + 8"
##	var result = evalExpr(exprStr, ["i"], [3])
##	print("expression '%s' result: %f" % [exprStr, result])
func _evalExpr(exprStr: String, vars: PackedStringArray, varValues: Array) -> Status:
	var expr := Expression.new()
	var error := expr.parse(exprStr, vars)
	if error != OK:
		print(expr.get_error_text())
		return
	var result = expr.execute(varValues)
	if not expr.has_execute_failed():
		#Log.info("expression '%s' result: %f" % [exprStr, result])
		pass
	return Status.ok(result)

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

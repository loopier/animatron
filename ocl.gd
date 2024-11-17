class_name OpenControlLanguage

var variableRegex := RegEx.create_from_string("\\$(\\w+)")
# Braces around {something} means expression, but double braces {{avoids}} expression evaluation
var fullExpressionRegex := RegEx.create_from_string("^(?<!\\{)\\{([^{}]+)\\}(?!\\})$") # RegEx.create_from_string("^\\{([^{}]+)\\}$")
var expressionRegex := RegEx.create_from_string(     "(?<!\\{)\\{([^{}]+)\\}(?!\\})")  #  RegEx.create_from_string("\\{([^{}]+)\\}")
var spacesRegex := RegEx.create_from_string("\\s+")

static func getActorArgument(nameOrActor: Variant, cmdInterface: CommandInterface) -> Array:
	if typeof(nameOrActor) == TYPE_OBJECT:
		var actor := nameOrActor as MetaNode
		if actor != null:
			return [actor]
	elif typeof(nameOrActor) == TYPE_ARRAY:
		return nameOrActor
	var resolvedActors = cmdInterface.getActors(nameOrActor)
	return resolvedActors.value if resolvedActors.isOk() else []

## Example: [code]/for i 4 /post bla_$i or $i[/code]
func _for(args: Array) -> Array:
	var result = []
	var variableName = args[0]
	var loopRange = int(args[1])
	var items = args.slice(2)
	var forVars := {}
	for i in loopRange:
		forVars[variableName] = i
		var newCmd := []
		for arg in items:
			var status := _resolveVariables(arg, forVars, true)
			newCmd.append(arg if status.isError() else status.value)
		result.append(newCmd)
	return result

## Returns the array of commands with all the variables replaced by their values.
## [param def] is a [class Dictionary] containing the [param def] variables description and 
## an [class Array] of subcommands.
## [param values] will be put anywhere where the [param def.variables] are present in the subcommands. 
func _def(def: Dictionary, values: Array, cmdInterface: CommandInterface) -> Array:
	var cmdArray := []
	var variables := VariablesManager.getAll()
	for i in def.variables.size():
		var nameAndType: PackedStringArray = def.variables[i].split(':')
		var varName: String = nameAndType[0]
		var varType := "s"
		if nameAndType.size() < 2: 
			Log.error("Variable type not specified for argument %d ('%s'). See '/help /def'" % [i, varName])
		else:
			varType = nameAndType[1]
		# def arguments take precedence over "app" vars
		if varType == "...":
			variables[varName] = " ".join(values.slice(i))
		elif varType == "a":
			variables[varName] = getActorArgument(values[min(i, values.size()-1)], cmdInterface)
		else:
			variables[varName] = values[min(i, values.size()-1)]
	for cmd in def.subcommands:
		var newCmd := []
		for arg in cmd:
			var status := _resolveVariables(arg, variables, false)
			newCmd.append(arg if status.isError() else status.value)
		cmdArray.append(newCmd)
#	Log.debug("processed def: %s" % [cmdArray])
	return cmdArray

func _resolveVariables(arg, variables: Dictionary, skipUnknown: bool) -> Status:
	var offset := 0
	while typeof(arg) == TYPE_STRING:
		var str : String = arg
		var match := variableRegex.search(str, offset)
		if not match: break
		var varName := match.get_string(1)
		if variables.has(varName):
			var value = variables[varName]
			if typeof(value) == TYPE_CALLABLE: value = value.call()
			if match.get_start(0) == 0 and match.get_end(1) == str.length():
				arg = value
			else:
				str = str.substr(0, match.get_start(0)) + ("%s" % [value]) + str.substr(match.get_end(1))
				offset = match.get_start(0)
#				print("Replaced var '%s', as '%s'" % [varName, str])
				arg = str
		elif skipUnknown:
			offset = match.get_end(1)
		else:
			return Status.error("Variable '%s' referenced but not set" % [varName])
	return Status.ok(arg)

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
				
			token = token.replace(variableName, "%s" % [value])
		
		for k in appVariables.keys():
			var variableName = "$%s" % k
			var value = appVariables[k]
			if typeof(value) == TYPE_CALLABLE: value = value.call()
			value = "%s" % value
			token = token.replace(variableName, value)
		
		newCmd.append(token)
	return newCmd

func _getValue(_variable: Variant) -> Variant:
	var value: Variant
	assert(false)
	return value

## Returns the single character representing a type of the [param variableDescription].
## Example: [code]_get_variable_type("actor:s")[/code] returns [code]"s"[/code]
func _getVariableType(variableDescription: String) -> String:
	if not variableDescription.contains(":"): return variableDescription
	var type = variableDescription.split(":")[1]
	match type:
		"a", "i", "f", "b", "...": return type
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
		Log.error(expr.get_error_text())
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
	var result := fullExpressionRegex.search(str)
	return result.strings[1].strip_edges() if result else ""

## In a string with expressions (e.g. "some {5 + 7    } stuff"),
## remove the spaces within the expression ("some {5+7} stuff").
func _removeExpressionSpaces(str: String) -> String:
	var removedStr := ""
	var lastIndex := 0
	for result in expressionRegex.search_all(str):
		Log.debug("result %d to %d: '%s'" % [result.get_start(), result.get_end(), result.get_string()])
		removedStr += str.substr(lastIndex, result.get_start() - lastIndex)
		removedStr += _removeSpaces(result.get_string())
		lastIndex = result.get_end()
	removedStr += str.substr(lastIndex)
	return removedStr

func _removeSpaces(str: String) -> String:
	return spacesRegex.sub(str, "", true)

class_name OpenControlLanguage 

var reservedWords: Dictionary = {
	"/for": _for
}

func _processReservedWord(word: String, args: Array) -> Variant:
	return reservedWords.get(word).callv(args)

func _for(args: Array) -> Array:
	var result = []
	var variableName = "$%s" % [args[0]]
	var range = int(args[1])
	var items = args.slice(2)
	
	for i in range:
		result.append(_getVariable(variableName, i, items))
	return result

## Replaces all instances of the [param variable] in the [param args] by the [param value]. 
func _getVariable(variable: String, value: Variant, args: Array) -> Array:
	var newArgs = args.duplicate()
	for i in len(newArgs):
		if typeof(newArgs[i]) == TYPE_STRING and variable in newArgs[i]:
			# just replace by the value if it's not part of a longer string
			if len(newArgs[i]) == len(variable):
				newArgs[i] = value
			else:
				newArgs[i] = newArgs[i].replace(variable, "%s" % [value])
	return newArgs

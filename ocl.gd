class_name OpenControlLanguage 

var reservedWords: Dictionary = {
	"/for": _for,
	"/+": _binaryOp,
	"/-": _binaryOp,
	"/*": _binaryOp,
	"//": _binaryOp,
	"/%": _binaryOp,
}

var operators: Array = ["/+","/-", "*", "/", "%"]

## Process arguments
func processArgs(args: Array) -> Array:
	var processed := []
	print("processing args: %s" % [args])
	Log.debug("processing args: %s" % [args])
	var i = 0
	while i < len(args):
#		print("%s: %s %s" % [i, args[i], reservedWords.has(args[i])])
		if reservedWords.has(args[i]):
			processed.append(_binaryOp(args[i].substr(1), args[i+1], args[i+2]))
			i = i + 3
		else:
			processed.append(args[i])
			i = i + 1
	print("%s" % [processed])
	return processed

func _binaryOp(operator: String, a: Variant, b: Variant) -> Variant:
	match operator:
		"+": return float(a) + float(b)
		"-": return float(a) - float(b)
		"*": return float(a) * float(b)
		"/": return float(a) / float(b)
		"%": return int(a) % int(b)
	return -1

func _processReservedWord(word: String, args: Array) -> Variant:
	return reservedWords.get(word).callv(args)

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

class_name CommandDescription

## Describes an OSC command including the documentation.

## Function to be called when command is received.
var callable: Callable
var callableObject: String
var callableMethod: String
## Arguments with type signature. For example: [code]name:s[/code].
var argsDescription: String
## Documentation string of the command.
var description: String
## If [code]true[/code], the [Callable] function will be called with arguments a single array.
## Otherwise they will be passed individually as function arguments.
## See [method Callable.call] vs. [method Callable.callv].
var argsAsArray: bool
var toGdScript: bool
var deferEvalExpressions: bool

# Inner helper class to specify the boolean flags for the CommandDescription constructor
class Flags:
	var argsAsArray := false
	var toGdScript := false
	var deferEvalExpressions := false
	var actorAndRest := false

	# args are converted to an array
	static func asArray(deferEvalExpr : bool):
		var f := Flags.new()
		f.argsAsArray = true
		f.deferEvalExpressions = deferEvalExpr
		return f
	
	# use OSC address as GDScript equivalent
	static func gdScript():
		var f := Flags.new()
		f.toGdScript = true
		return f
		
func _init(fn: Callable, args: String, desc: String, flags = null):
	callable = fn
	callableObject = callable.get_object().get_class()
	callableMethod = callable.get_method()
	argsDescription = args
	description = desc
	argsAsArray = flags.argsAsArray if typeof(flags) != TYPE_NIL else false
	toGdScript = flags.toGdScript if typeof(flags) != TYPE_NIL else false
	deferEvalExpressions = flags.deferEvalExpressions if typeof(flags) != TYPE_NIL else false

func execute(cmd: Array) -> Status:
	var result := Status.new()
	if argsAsArray: 
		result = callable.call(cmd.slice(1))
	else: 
		result = callable.callv(cmd.slice(1))
	Log.debug("Executing command from CommandDescription - %s (call:%s args:%s array:%s desc:%s)" % [cmd, callable.get_method(), argsDescription, argsAsArray, description])
	return result if result != null else Status.error("Command not executed: %s" % [cmd[0]])

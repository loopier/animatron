class_name CommandDescription
extends Node

## Describes an OSC command including the documentation.

## OSC command
var cmd: String
## Function to be called when command is received.
var callable: Callable
## Arguments with type signature. For example: [code]name:s[/code].
var argsDescription: String
## Documentation string of the command.
var description: String
## If [code]true[/code], the [Callable] function will be called with arguments a single array.
## Otherwise they will be passed individually as function arguments.
## See [method Callable.call] vs. [method Callable.callv].
var argsAsArray: bool
var toGdScript: bool

func _init(fn: Callable, args: String, desc: String, asArray := false, toGdScript := false):
	callable = fn
	argsDescription = args
	description = desc
	argsAsArray = asArray

func execute(cmd: Array) -> Status:
	var result := Status.new()
	if argsAsArray: 
		result = callable.call(cmd.slice(1))
	else: 
		result = callable.callv(cmd.slice(1))
	Log.debug("Executing command from CommandDescription - %s (call:%s args:%s array:%s desc:%s)" % [cmd, callable.get_method(), argsDescription, argsAsArray, description])
	return result if result != null else Status.error("Command not executed: %s" % [cmd[0]])

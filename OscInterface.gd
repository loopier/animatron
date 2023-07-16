class_name OscInterface
extends Node
## Map OSC commands to Godot functionality
##
## Using dictionaries to store variable values and function pointers.
##
## @tutorial:	TODO
## @tutorial(2):	TODO

## A dictionary used to store variables accessible from OSC messages.
static var variables: Dictionary
## A dictionary to store function calls.
static var cmds: Dictionary = {
	"/set": OscInterface.setVar,
	"/get": OscInterface.getVar,
}

func _init():
	Log.debug("init mapper")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

static func parseCmd(key, args, sender) -> Variant:
	Log.warn("TODO: filter messages by type (function, variable or OSC)")
	# all custom cmd methods must return anything other than 'null'
	var result: Variant
	# get OSC key from cmds dict
	var cmd = OscInterface.getCmd(key)
	Log.verbose("parsing '%s': %s %s" % [key, cmd, args])
	match typeof(cmd):
		TYPE_CALLABLE: result = cmd.callv(args)
		TYPE_STRING:
			# if it's a variable: get the value and return it to the parent command
			Log.warn("TODO: try calling '%s' as a GDScript function" % [key])
			result = OscInterface.getVar(cmd)
			# if it's a cmd: parse arguments
			if result == null:
				result = OscInterface.getCmd(cmd)
		_: result = null
		
	# if none of the above worked: try calling it as if it was a GDScript function
	if result == null:
		if key.begins_with("/"): cmd = key.substr(1)
#		result = callv(cmd, args)
		Log.warn("TODO: should be calling a GDScript with '%s'" % [cmd])
	
	# else: it doesn't, report error back to sender
	if result == null:
		Log.warn("TODO: send '%s' error back to the sender" % [key])
	Log.debug("Parsed '%s': %s %s => %s" % [key, cmd, args, result])
	return result

## Read a file with a [param filename] and return its OSC constent in a string
static func loadFile( filename ) -> String:
	Log.verbose("Reading: %s" % [filename])
	var file = FileAccess.open(filename, FileAccess.READ)
	var content = file.get_as_text()
	return content

## Return a dictionary based on the string [param oscStr] of OSC messages.[br]
## The address is the key of the dictionary (or the first element), and the 
## array of arguments the value.
static func oscStrToDict( oscStr: String ) -> Dictionary:
	var dict: Dictionary
	var lines = oscStr.split("\n")
	for line in lines:
		var items: Array = line.split(" ")
		if items[0] == "": continue
		dict[items[0]] = items.slice(1)
	return dict

## Get a variable value by [param name].
##
## This method returns a single value. If by any reason the value holds
## more than one, it will return only the first one.
static func getVar( name ) -> Variant:
	var value = variables[name][0] if variables.has(name) else null
	Log.verbose("Looking for var '%s': %s" % [name, value])
	if value == null: Log.warn("Variable '%s' not found" % [name])
	return value

## Set and store new [param value] in a variable with a [param name]
static func setVar( name, value ) -> bool:
	variables[name] = [value]
	if Log.getLevel() == Log.LOG_LEVEL_VERBOSE:
		OscInterface.list(OscInterface.variables)
	return true

static func getCmd( cmd ) -> Variant:
	var value = cmds[cmd] if cmds.has(cmd) else null
	if value == null: Log.warn("Command '%s' not found" % [cmd])
	return value

## Remove the [param key] and its value from [param dict]
static func remove( key, dict ):
	if variables.has(key): variables.erase(key)

## List contents of [param dict]
static func list( dict ):
	for key in dict:
		print("%s: %s" % [key, dict[key]])

static func listCmds():
	OscInterface.list(OscInterface.cmds)

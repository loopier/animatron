class_name OscMapper
extends Node
## Map OSC messages to Godot functionality
##
## Using dictionaries to store variable values and function pointers.
##
## @tutorial:	TODO
## @tutorial(2): TODO

## Store variables in memory for later use. Use 'getVar' and 'setVar' to
## manage them.
static var variables: Dictionary = {
	"/var1": 0,
	"/zero": 0,
	"/one": 1,
	"/pointone": 0.1,
	"/bla": "bla",
	"/true": true,
	"/false": false,
}

var funcs: Dictionary

func _init():
	Log.debug("init mapper")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

## Read a file with a FILENAME and put its OSC constent in a TARGET dictionary
static func loadFile( filename, target ):
	Log.debug("Reading '%s': %s" % [filename, target])

## Get a variable value by NAME
static func getVar( name ) -> Variant:
	var value = variables[name] if variables.has(name) else null
	Log.verbose("Looking for var '%s': %s" % [name, value])
	return variables[name] if variables.has(name) else null

## Set and store new VALUE in a variable with a NAME
static func setVar( name, value ):
	variables[name] = value

## Remove a variable with a NAME
static func remove( name ):
	if variables.has(name): variables.erase(name)

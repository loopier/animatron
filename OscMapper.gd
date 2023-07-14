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
var memory: Dictionary = {
	"/var1": 0,
	"/zero": 0,
	"/one": 1,
	"/pointone": 0.1,
	"/bla": "bla",
	"/true": true,
	"/false": false,
}

var funcs: Dictionary

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

## get a variable value by name
func getVar( name ) -> Variant:
	var value = memory[name] if memory.has(name) else null
	Log.debug("Looking for var '%s': %s" % [name, value])
	return memory[name] if memory.has(name) else null

## set and store new value
func setVar( name, value ):
	memory[name] = value


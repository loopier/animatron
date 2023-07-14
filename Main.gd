extends Node2D

var osc: OscReceiver
static var configPath = "res://variables.osc"

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary
	OscMapper.loadFile(configPath, OscMapper.variables)
	# is it possible to save function maps to .osc files?
	# if it is:  bdload osc function maps to a dictionary

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(delta):
	pass

func _on_osc_msg_received(addr, args, sender):
	# map incoming OSC message to a function
	Log.warn("TODO: Map incoming messages to functions: Main._on_osc_msg_received")
	return [addr, args, sender]

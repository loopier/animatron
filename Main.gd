extends Node2D

var osc: OscReceiver
static var variablesPath = "res://config/vars.ocl"
static var configPath = "res://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
#@onready var oscInterface := get_node("OscInterface")

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	get_node("CommandInterface").command_finished.connect(_on_command_finished)
	get_node("CommandInterface").command_error.connect(_on_command_error)
	
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(delta):
	pass

func _on_osc_msg_received(addr, args, sender):
	get_node("CommandInterface").parseCommand(addr, args, sender)
#	OscInterface.listCmds()
	pass

func _on_command_finished(msg: String, sender: String):
	Log.info("Command finished:\n%s" % [msg])
	Log.debug("TODO: Report message back to: %s" % [sender])

func _on_command_error(msg: String, sender: String):
	Log.error("Command error: %s" % [msg])
	Log.debug("TODO: Report error back to: %s" % [sender])

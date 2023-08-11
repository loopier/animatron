extends Node2D

var osc: OscReceiver
static var variablesPath := "res://config/vars.ocl"
static var configPath := "res://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
@onready var cmdInterface := get_node("CommandInterface") as CommandInterface

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	cmdInterface.command_finished.connect(_on_command_finished)
	cmdInterface.command_error.connect(_on_command_error)
	
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _on_osc_msg_received(addr: String, args: Array, sender: String):
	cmdInterface.parseCommand(addr, args, sender)
#	osc.sendTo(sender, "/testing", [16])

func _on_command_finished(msg: String, sender: String):
	Log.info("Command finished:\n%s" % [msg])
	if sender:
		osc.sendMessage(sender, "/status/reply", [msg])

func _on_command_error(msg: String, sender: String):
	Log.error("Command error: %s" % [msg])
	if sender:
		osc.sendMessage(sender, "/error/reply", [msg])

extends Node2D

var osc: OscReceiver
static var variablesPath = "res://lib/vars.ocl"
static var configPath = "res://lib/config.ocl"

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary
	_initVariables()

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(delta):
	pass

func _on_osc_msg_received(addr, args, sender):
	OscInterface.parseCmd(addr, args, sender)
#	OscInterface.listCmds()

func _initVariables():
	var variablesStr = OscInterface.loadFile(variablesPath)
	OscInterface.variables = OscInterface.oscStrToDict(variablesStr)

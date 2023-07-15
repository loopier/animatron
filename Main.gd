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
	Log.warn("TODO: filter messages by type (function, variable or OSC)")
	# get OSC key from cmds dict
	var cmd = CmdManager.getCmd(addr)
	Log.verbose("parsing '%s': %s %s" % [addr, cmd, args])
	# all custom cmd methods must return anything other than 'null'
	var result: Variant
	match typeof(cmd):
		TYPE_CALLABLE: result = cmd.callv(args)
		TYPE_STRING:
			# if it's a variable: get the value and return it to the parent command
			Log.warn("TODO: try calling '%s' as a GDScript function" % [addr])
			result = CmdManager.getVar(cmd)
			# if it's a cmd: parse arguments
			if result == null:
				result = CmdManager.getCmd(cmd)
		_: result = null
	if result == null:
		if addr.begins_with("/"): cmd = addr.substr(1)
		result = callv(cmd, args)
	# if none of the above: try calling it as if it was a GDScript function
	if result == null:
		Log.warn("TODO: try calling '%s' as a GDScript function" % [addr])
	
	# else: it doesn't exist and must send msg back to sender
	if result == null:
		Log.debug("TODO: send '%s' back to the sender if none of the above worked" % [addr])
	Log.debug("Parsed '%s': %s %s => %s" % [addr, cmd, args, result])
	return [addr, args, sender]

func _initVariables():
	var variablesStr = CmdManager.loadFile(variablesPath)
	CmdManager.variables = CmdManager.oscStrToDict(variablesStr)

extends Node2D

var osc: OscReceiver
var mapper: OscMapper
static var variablesPath = "res://lib/vars.ocl"
static var configPath = "res://lib/config.ocl"

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	
	mapper = OscMapper.new()
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary
	_initVariables()
	
#	var c = Callable(OscMapper, "salo")
#	Callable(OscMapper, "salo").callv(["bla"])
#	Callable(self, "setVar").call(["/x", 1])
#	var c = Callable(self, "alo")
#	c.call("bla")

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(delta):
	pass

func _on_osc_msg_received(addr, args, sender):
	Log.warn("TODO: filter messages by type (function, variable or OSC)")
	# get OSC key from cmds dict
	var cmd = OscMapper.getCmd(addr)
	Log.debug("Map func: %s(%s)" % [cmd, typeof(cmd)])
	Log.debug("Map args(%d): %s" % [len(args), args])
	# if it's a core function: call it
	var result: Variant
	match typeof(cmd):
		TYPE_CALLABLE: result = cmd.callv(args)
		TYPE_STRING:
			# if it's a variable: get the value and modify the arguments accordingly
			result = OscMapper.getVar(cmd)
			# if it's a cmd: parse arguments
			if result == null:
				result = OscMapper.getCmd(cmd)
		_: result = null
	if result == null:
		if addr.begins_with("/"): cmd = addr.substr(1)
		result = callv(cmd, args)
	# if none of the above: try calling it as if it was a GDScript function
	if result == null:
		Log.debug("TODO: try calling '%s' as a GDScript function" % [addr])
	
	# else: it doesn't exist and must send msg back to sender
	if result == null:
		Log.debug("TODO: send '%s' back to the sender if none of the above worked" % [addr])
	Log.debug("Cmd '%s': %s(%s)" % [cmd, result, typeof(result)])
	return [addr, args, sender]

func _initVariables():
	var variablesStr = OscMapper.loadFile(variablesPath)
	OscMapper.variables = OscMapper.oscStrToDict(variablesStr)

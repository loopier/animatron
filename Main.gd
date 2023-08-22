extends Node2D

var osc: OscReceiver
static var variablesPath := "res://config/vars.ocl"
static var configPath := "res://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
@onready var cmdInterface := get_node("CommandInterface")
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := get_node("Routines")

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	cmdInterface.command_finished.connect(_on_command_finished)
	cmdInterface.command_error.connect(_on_command_error)
	cmdInterface.list_routines.connect(_on_list_routines)
	cmdInterface.new_routine.connect(_on_new_routine)
	cmdInterface.free_routine.connect(_on_free_routine)
	cmdInterface.start_routine.connect(_on_start_routine)
	cmdInterface.stop_routine.connect(_on_stop_routine)
	
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

func _on_list_routines():
	var routineNames = routines.keys()
	routineNames.sort()
	for routineName in routineNames:
		# FIX: send OSC message
		Log.info(routineName)

func _on_new_routine(name: String, repeats: int, interval: float, command: Array):
	Log.verbose("New routine '%s' (%s times every %s): %s" % [name, repeats, interval, command])
	var routine: Node
	if routines.has_node(name):
		routine = routines.get_node(name)
	else:
		routine = Routine.instantiate()
		routine.name = name
		routines.add_child(routine)
	routine.repeats = repeats
	routine.set_wait_time(interval)
	routine.command = command
	routine.start()

func _on_free_routine(name: String):
	if routines.has_node(name):
		var routine = routines.get_node(name)
		routine.stop()
		routine.remove_and_skip()
		# FIX: change the following line to send OSC message
		Log.verbose("Routine removed: %s" % [name])
	else:
		# FIX: change the following line to send OSC message
		Log.error("Routine not found: %s" % [name])

func _on_start_routine(name: String):
	routines.get_node(name).start()
	
func _on_stop_routine(name: String):
	routines.get_node(name).stop()

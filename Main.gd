extends Node2D
class_name Main

var osc: OscReceiver
static var variablesPath := "res://config/vars.ocl"
static var configPath := "res://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
@onready var cmdInterface : CommandInterface = get_node("CommandInterface")
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := get_node("Routines")
var StateMachine := preload("res://StateMachine.gd")
var config := preload("res://Config.gd").new()
@onready var editor := get_node("HSplitContainer/CodeEdit")
@onready var helpWindow := get_node("HSplitContainer/VBoxContainer/HelpWindow")
@onready var postWindow := get_node("HSplitContainer/VBoxContainer/PostWindow")

@onready var stateMachines := {}

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
#	Log.setLevel(Log.LOG_LEVEL_DEBUG)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	config.load_config.connect(_on_load_config)
	cmdInterface.command_finished.connect(_on_command_finished)
	cmdInterface.command_error.connect(_on_command_error)
	cmdInterface.list_routines.connect(_on_list_routines)
	cmdInterface.add_routine.connect(_on_add_routine)
	cmdInterface.free_routine.connect(_on_free_routine)
	cmdInterface.start_routine.connect(_on_start_routine)
	cmdInterface.stop_routine.connect(_on_stop_routine)
	cmdInterface.list_states.connect(_on_list_states)
	cmdInterface.add_state.connect(_on_add_state)
	cmdInterface.free_state.connect(_on_free_state)
	cmdInterface.next_state.connect(_on_next_state)
	
	editor.eval_code.connect(_on_eval_code)
	
	# saving osc maps for variables to .osc files can be used as config files
	# load osc variable maps to a dictionary

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _on_osc_msg_received(addr: String, args: Array, sender: String):
	# TODO: send [addr, args] to OCL interpreter and receive an array of commands
	var dummyArrayOfCmds := [[addr] + args]
	# TODO: iterate the array of commands to evaluate them
	Log.debug("osc_msg_received: %s %s - %s" % [addr, args, sender])
	evalCommands(dummyArrayOfCmds, sender)

func evalCommands(cmds: Array, sender: String):
	for cmd in cmds:
		var addr : String = cmd[0]
		var args : Array = cmd.slice(1)
		var callable : Variant
		var result := Status.new()
		if cmdInterface.coreCommands.has(addr):
			callable = cmdInterface.coreCommands[addr]
			Log.debug("core cmd: %s %s" % [addr, callable])
			if callable is String:
				evalCommands([[callable] + args], sender)
				return
			result = callable.callv(args)
		elif cmdInterface.nodeCommands.has(addr):
			callable = cmdInterface.nodeCommands[addr]
			Log.debug("node cmd: %s %s" % [addr, callable])
			if callable is String:
				evalCommands([[callable] + args], sender)
				return
			result = callable.call(addr, args)
		elif cmdInterface.arrayCommands.has(addr):
			callable = cmdInterface.arrayCommands[addr]
			Log.debug("array cmd: %s %s" % [addr, callable])
			if callable is String:
				evalCommands([[callable] + args], sender)
				return
			result = callable.call(args)
		# elif cmdInterface.defCommands.has(addr):
		# 	Log.debug("def cmd: %s %s" % [addr, cmdInterface.defCommands[addr]])
		else:
			result = Status.error("cmd not found: %s %s" % [addr, args])
		
		match result.type:
			Status.OK: _on_command_finished(result.msg, sender)
			Status.ERROR: _on_command_error(result.msg, sender)
			_: pass

func _on_load_config(filename: String):
	var configCmds = cmdInterface.loadCommandFile(filename).value
	for cmd in configCmds:
		cmdInterface.parseCommand(cmd[0], cmd.slice(1), "")

func _on_eval_code(text: String):
	var cmds := []
	if text.begins_with("/def"):
		# putting /def cmd in an array so we can use the same call for both cases
		cmds.append(cmdInterface.convertDefBlockToCommand(text))
	else:
		cmds = cmdInterface.convertTextBlockToCommands(text)
	evalCommands(cmds, "NULL_SENDER")

func _on_command_finished(msg: String, sender: String):
	if not msg.is_empty():
		Log.verbose("Command finished:\n%s" % [msg])
		if sender:
			osc.sendMessage(sender, "/status/reply", [msg])

func _on_command_error(msg: String, sender: String):
	Log.error("Command error: %s" % [msg])
	if sender:
		osc.sendMessage(sender, "/error/reply", [msg])

func _on_list_routines():
	var routineList := []
	for child in routines.get_children():
		routineList.append("%s(%s/%s): %s" % [child.name, child.iteration, child.repeats, child.command])
	routineList.sort()
	for routine in routineList:
		# FIX: send OSC message
		Log.info(routine)

func _on_add_routine(name: String, repeats: int, interval: float, command: Array):
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
	# FIX: change the following line to send OSC message
	Log.debug("Removing routine: %s" % [name])
	Log.debug(routines.find_children(name))
	Log.debug(routines.get_children()[0].name)
	Log.debug(routines.find_child(name,true, false))
	for routine in routines.find_children(name, "", true, false):
		routine.stop()
		routines.remove_child(routine)
		routine.queue_free()
		# FIX: change the following line to send OSC message
		Log.debug("Routine removed: %s" % [name])

func _on_start_routine(name: String):
	routines.get_node(name).start()
	
func _on_stop_routine(name: String):
	routines.get_node(name).stop()

func _on_routine_finished(name: String):
	_on_free_routine(name)

## List all state machines
func _on_list_states():
	# FIX: change to send OSC
	Log.info("State machines:")
	var machines = stateMachines.keys()
	machines.sort()
	for machine in machines:
		Log.info("%s(%s): %s" % [machine, stateMachines[machine].status(), stateMachines[machine].list()])

## Add a [param state] to a [param mijachine]
func _on_add_state(machine: String, state: String, commands: Array):
	if not stateMachines.has(machine): 
		stateMachines[machine] = StateMachine.new()
		stateMachines[machine].name = machine
	stateMachines[machine].addState(state, commands)

## Remove a [param state] from a [param machine] -- wildcard matching
func _on_free_state(machine: String, state: String):
	# There's no wildcard matching for Dictionary so we need to implement it ourselves
	for machineKey in stateMachines.keys():
		if machineKey.match(machine):
			stateMachines[machineKey].removeState(state)
			if stateMachines[machineKey].isEmpty():
				stateMachines.erase(machineKey)

func _on_next_state(machine: String):
	for machineKey in stateMachines.keys():
		if machineKey.match(machine):
			stateMachines[machineKey].next()
			cmdInterface.parseCommand(stateMachines[machineKey].status(), [], "")

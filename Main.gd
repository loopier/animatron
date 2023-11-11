extends Node2D
class_name Main

var osc: OscReceiver
static var configPath := "user://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
@onready var cmdInterface : CommandInterface = get_node("CommandInterface")
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := get_node("Routines")
var StateMachine := preload("res://StateMachine.gd")
var OpenControlLanguage := preload("res://ocl.gd")
var ocl: OpenControlLanguage
var config := preload("res://Config.gd").new()
@onready var editor := get_node("HSplitContainer/CodeEdit")
@onready var helpWindow := get_node("HSplitContainer/VBoxContainer/HelpWindow")
@onready var postWindow := get_node("HSplitContainer/VBoxContainer/PostWindow")
var rnd := RandomNumberGenerator.new()

@onready var stateMachines := {}

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
#	Log.setLevel(Log.LOG_LEVEL_DEBUG)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
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
	
	ocl = OpenControlLanguage.new()
	editor.eval_code.connect(_on_eval_code)
	
	loadConfig(configPath)

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _on_osc_msg_received(addr: String, args: Array, sender: String):
	# TODO: send [addr, args] to OCL interpreter and receive an array of commands
	var dummyArrayOfCmds := [[addr] + args]
	# TODO: iterate the array of commands to evaluate them
	Log.debug("osc_msg_received: %s %s - %s" % [addr, args, sender])
	evalCommands(dummyArrayOfCmds, sender)

func evalCommands(cmds: Array, sender: String) -> Status:
	var result : Status
	for cmd in cmds:
		result = evalCommand(cmd, sender)
		if result.isError(): break
	return result

func evalCommand(cmdArray: Array, sender: String) -> Status:
	var cmd : String = cmdArray[0]
	var args : Array = cmdArray.slice(1)
	var callable : Variant
	var result := Status.new()
	var cmdDescription : Variant = cmdInterface.getCommandDescription(cmd)
	if cmdDescription is String: 
		result = evalCommand([cmdDescription] + args, sender)
	elif cmdDescription is Dictionary:
		var subcommands = ocl._def(cmdDescription.variables, cmdDescription.subcommands)
		result = evalCommands(subcommands, sender)
	elif cmdDescription is CommandDescription:
		if cmdDescription.toGdScript: args = cmdArray
		result = executeCommand(cmdDescription, args)
	else:
		result = Status.error("Command not found: %s" % [cmd])
	
	# post and reply result
	_on_command_finished(result, sender)
	return result

## Executes a [param command] described in a [CommandDescription], with the given [param args].
func executeCommand(command: CommandDescription, args: Array) -> Status:
	var result := checkNumberOfArguments(command.argsDescription, args)
	if result.isError(): return result
	# Handle expressions in arguments
	for i in args.size():
		var expr := ocl._getExpression(args[i])
		if not expr.is_empty():
			var expResult : float = ocl._evalExpr(expr, ["time", "rnd"], [Time.get_ticks_msec() * 1e-3, rnd])
			args[i] = expResult
	if args.size() == 0:
		result = command.callable.call()
	elif command.argsAsArray:
		result = command.callable.call(args)
	elif command.toGdScript:
		result = command.callable.call(args[0], args.slice(1))
	else:
		# Reduce the number of args to the expected size, else callv will fail
		result = command.callable.callv(args.slice(0, result.value))
	return result

func checkNumberOfArguments(argsDescription: String, args: Array) -> Status:
	var expectedNumberOfArgs := argsDescription.split(" ").size() if len(argsDescription) > 0 else 0
	# For now, allow arbitrary upper bound when the argsDescription includes repeats
	if argsDescription.contains("..."):
		expectedNumberOfArgs = max(expectedNumberOfArgs, args.size())
	var actualNumberOfArgs := args.size()
	if actualNumberOfArgs < expectedNumberOfArgs:
		return Status.error("Not enough arguments - expected: %s - received: %s" % [expectedNumberOfArgs, actualNumberOfArgs])
	if actualNumberOfArgs > expectedNumberOfArgs:
		return Status.ok(expectedNumberOfArgs, "Received more arguments (%s) than needed (%s). Using: %s" % [actualNumberOfArgs,  expectedNumberOfArgs, args.slice(0,expectedNumberOfArgs)])
	return Status.ok(expectedNumberOfArgs, "")

func loadConfig(filename: String):
	var configCmds = cmdInterface.loadCommandFile(filename).value
	evalCommands(configCmds, "config")
#	for cmd in configCmds:
#		cmdInterface.parseCommand(cmd[0], cmd.slice(1), "")

func _on_eval_code(text: String):
	var cmds := []
	if text.begins_with("/def"):
		# putting /def cmd in an array so we can use the same call for both cases
		cmds.append(cmdInterface.convertDefBlockToCommand(text))
	else:
		cmds = cmdInterface.convertTextBlockToCommands(text)
	evalCommands(cmds, "NULL_SENDER")

func _on_command_finished(result: Status, sender: String):
	if result.isError():
		_on_command_error(result.msg, sender)
		return
	if result.msg.is_empty(): return
	Log.verbose("Command finished:\n%s" % [result.msg])
	if sender:
		osc.sendMessage(sender, "/status/reply", [result.msg])

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

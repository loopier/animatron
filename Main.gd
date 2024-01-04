extends Node2D
class_name Main

var osc: OscReceiver
var oscSender: OscReceiver # FIX: this is misleading.
static var configPath := "user://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := get_node("Actors")
@onready var cmdInterface : CommandInterface = get_node("CommandInterface")
@onready var lastSender : String = "localhost"
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := get_node("Routines")
@onready var StateMachine := preload("res://StateMachine.gd")
@onready var stateMachines := {}
@onready var midiCommands := []
var OpenControlLanguage := preload("res://ocl.gd")
var ocl: OpenControlLanguage
var config := preload("res://Config.gd").new()
@onready var editor := get_node("HSplitContainer/CodeEdit")
@onready var helpWindow := get_node("HSplitContainer/VBoxContainer/HelpWindow")
@onready var postWindow := get_node("HSplitContainer/VBoxContainer/PostWindow")
var rnd := RandomNumberGenerator.new()

@onready var animationsLibrary : SpriteFrames
func _init_midi():
	# separate commands by channel
	midiCommands.resize(16)
	# create a different dictionary for each channel
	midiCommands.fill({"noteOn": [], "noteOnNum": [], "noteOnTrig": [], "noteOnNumVelocity": [], "noteOnVelocity": [], "noteOff": [], "noteOffNum": [], "cc": []})
	for chan in midiCommands:
		chan["cc"].resize(128)
		chan["noteOnTrig"].resize(128)
		chan["noteOnNumVelocity"].resize(128)

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
#	Log.setLevel(Log.LOG_LEVEL_DEBUG)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	cmdInterface.commandManger = self
	cmdInterface.command_finished.connect(_on_command_finished)
	cmdInterface.command_error.connect(_on_command_error)
	cmdInterface.command_file_loaded.connect(_on_command_file_loaded)
	cmdInterface.routine_added.connect(_on_routine_added)
	
	var animationsLibraryNode = AnimatedSprite2D.new()
	animationsLibraryNode.set_sprite_frames(SpriteFrames.new())
	animationsLibrary = animationsLibraryNode.get_sprite_frames()
	add_child.call_deferred(animationsLibraryNode)
	cmdInterface.animationsLibrary = animationsLibrary
	cmdInterface.actorsNode = get_node("Actors")
	cmdInterface.postWindow = get_node("HSplitContainer/VBoxContainer/PostWindow")
	cmdInterface.routinesNode = get_node("Routines")
	cmdInterface.stateMachines = Dictionary(stateMachines)
	_init_midi()
	cmdInterface.midiCommands = midiCommands
	
	ocl = OpenControlLanguage.new()
	editor.eval_code.connect(_on_eval_code)
	
	$Midi.midi_noteon.connect(_on_midi_noteon)
	$Midi.midi_noteoff.connect(_on_midi_noteoff)
	$Midi.midi_cc.connect(_on_midi_cc)
	
	loadConfig(configPath)

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _input(event):
	if event.is_action_pressed("toggle_editor", true):
		$HSplitContainer.set_visible(not($HSplitContainer.is_visible()))

func _on_osc_msg_received(addr: String, args: Array, sender: String):
	# TODO: send [addr, args] to OCL interpreter and receive an array of commands
	var dummyArrayOfCmds := [[addr] + args]
	# TODO: iterate the array of commands to evaluate them
	Log.debug("osc_msg_received: %s %s - %s" % [addr, args, sender])
	evalCommands(dummyArrayOfCmds, sender)
	lastSender = sender

func evalCommands(cmds: Array, sender: String) -> Status:
	var result : Status
	for cmd in cmds:
		if len(cmd) <= 0: continue
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
		# put variable values from the OSC command into the 
		# CommandDescritpion.variables dictionary
		for i in len(cmdDescription.variables.keys()):
			var key = cmdDescription.variables.keys()[i]
			cmdDescription.variables[key] = args[i]
		var subcommands = ocl._def(cmdDescription.variables, cmdDescription.subcommands)
		result = evalCommands(subcommands, sender)
	elif cmdDescription is CommandDescription:
		if cmdDescription.toGdScript: args = cmdArray
		result = executeCommand(cmdDescription, args)
	else:
		result = Status.error("Command not found: %s" % [cmd])
	
	# post and reply result
	_on_command_finished(result, sender)
	post(result.msg)
	return result

## Executes a [param command] described in a [CommandDescription], with the given [param args].
func executeCommand(command: CommandDescription, args: Array) -> Status:
	var result := checkNumberOfArguments(command.argsDescription, args)
	if result.isError(): return result
	if not command.deferEvalExpressions:
		# Don't modify the incoming arguments (so expression strings stay as exprsesions)
		args = args.duplicate()
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
	text = ocl._removeExpressionSpaces(text)
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

func _on_command_file_loaded(cmds: Array):
	evalCommands(cmds, lastSender)

func _on_routine_added(name: String):
	var routine = $Routines.find_child(name, true, false)
	# we need to capture the signal emmited when a routine has been added by OSC
	# so we can set a call to `Main.evalCommand` from within the `Routine`.
	# Doing it like this decouples `Routine` from `Main`, because `Routine` doesn't
	# need to know what object calling the method (in this case `Main`).
	routine.callOnNext = Callable(evalCommand)

func _on_midi_noteon(ch: int, num: int, velocity: int):
	Log.verbose("MIDI Note On: %s %s %s" % [ch, num, velocity])
	
	#var NewValue = (((OldValue - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin
	# var result = (num - 0) * (max - min) / (127 - 0) + min
	pass

func _on_midi_noteoff(ch: int, num: int, velocity: int):
	Log.verbose("MIDI Note Off: %s %s %s" % [ch, num, velocity])

func _on_midi_cc(ch: int, num: int, velocity: int):
	Log.verbose("MIDI CC: %s %s %s" % [ch, num, velocity])

func post(msg: String):
	$HSplitContainer/VBoxContainer/PostWindow.set_text($HSplitContainer/VBoxContainer/PostWindow.get_text() + msg)

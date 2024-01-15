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
#@onready var helpWindow := get_node("HSplitContainer/VBoxContainer/HelpWindow")
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
		chan["cc"].fill([])
		chan["noteOnTrig"].resize(128)
		chan["noteOnTrig"].fill([])
		chan["noteOnNumVelocity"].resize(128)
		chan["noteOnNumVelocity"].fill([])

func _ready():
	Log.setLevel(Log.LOG_LEVEL_VERBOSE)
#	Log.setLevel(Log.LOG_LEVEL_DEBUG)
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	cmdInterface.commandManager = self
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
	cmdInterface.editor = $HSplitContainer/CodeEdit
	cmdInterface.postWindow = get_node("HSplitContainer/PostWindow")
	cmdInterface.routinesNode = get_node("Routines")
	cmdInterface.stateMachines = Dictionary(stateMachines)
	cmdInterface.stateChangedCallback = Callable(self, "_on_state_changed")
	cmdInterface.saveFileDialog = $SaveFileDialog
	cmdInterface.openFileDialog = $OpenFileDialog
	_init_midi()
	cmdInterface.midiCommands = midiCommands
	
	ocl = OpenControlLanguage.new()
	
	$SaveFileDialog.set_current_path(OS.get_user_data_dir() + "/animatron")
	$OpenFileDialog.set_current_path(OS.get_user_data_dir() + "/animatron")
	$SaveFileDialog.confirmed.connect(editor._on_save_dialog_confirmed)
	$SaveFileDialog.file_selected.connect(editor.saveFile)
	$OpenFileDialog.confirmed.connect(editor._on_load_dialog_confirmed)
	$OpenFileDialog.file_selected.connect(editor.openFile)
	editor.saveDialog = $SaveFileDialog
	editor.loadDialog = $OpenFileDialog
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
		_ignoreEvent()
	if event.is_action_pressed("toggle_post", true):
		#$HSplitContainer/VBoxContainer.set_visible(not($HSplitContainer/VBoxContainer.is_visible()))
		evalCommand(["/post/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("clear_post", true):
		$HSplitContainer/VBoxContainer/PostWindow.clear()
		_ignoreEvent()
	if event.is_action_pressed("open_text_file", true):
		$OpenFileDialog.popup()
		_ignoreEvent()
	if event.is_action_pressed("save_text_file", true):
		$SaveFileDialog.popup()
		_ignoreEvent()
		
func _ignoreEvent():
	get_parent().set_input_as_handled()

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
	if len(result.msg) < 0: post(result.msg)
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
				var expResult = ocl._evalExpr(expr, ["time", "rnd"], [Time.get_ticks_msec() * 1e-3, rnd])
				if not expResult: return Status.error("Invalid expression")
				args[i] = expResult as float
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

# "noteOn", "noteOnNum", "noteOnTrig", "noteOnNumVelocity", "noteOnVelocity"
func _on_midi_noteon(ch: int, num: int, velocity: int):
	Log.verbose("MIDI Note On: %s %s %s" % [ch, num, velocity])
	for cmd in midiCommands[ch]["noteOnNum"]:
		var value = Midi.map(num, cmd[-2], cmd[-1])
		cmd = cmd.slice(0,-2)
		cmd.append(value)
		evalCommand(cmd, "")
	for cmd in midiCommands[ch]["noteOnVelocity"]:
		var value = Midi.map(velocity, cmd[-2], cmd[-1])
		cmd = cmd.slice(0,-2)
		cmd.append(value)
		evalCommand(cmd, "")
	for cmd in midiCommands[ch]["noteOnNumVelocity"][num]:
		var value = Midi.map(velocity, cmd[-2], cmd[-1])
		cmd = cmd.slice(0,-2)
		cmd.append(value)
		evalCommand(cmd, "")
	for cmd in midiCommands[ch]["noteOnTrig"][num]:
		evalCommand(cmd, "")
	for cmd in midiCommands[ch]["noteOn"]:
		evalCommand(cmd, "")

# "noteOff", "noteOffNum"
func _on_midi_noteoff(ch: int, num: int, velocity: int):
	Log.verbose("MIDI Note Off: %s %s %s" % [ch, num, velocity])

# "cc"
func _on_midi_cc(ch: int, num: int, velocity: int):
	Log.verbose("MIDI CC: %s %s %s" % [ch, num, velocity])

func post(msg: String):
	$HSplitContainer/VBoxContainer/PostWindow.set_text("%s\n%s" % [$HSplitContainer/VBoxContainer/PostWindow.get_text(), msg])
	$HSplitContainer/VBoxContainer/PostWindow.set_caret_line($HSplitContainer/VBoxContainer/PostWindow.get_line_count())

func _on_state_changed(cmd: Array):
	Log.debug("Received signal -- State changed: %s" % [cmd])
	evalCommand(cmd, "")

func _on_load_dialog_confirmed():
	Log.debug("Main load confirmed: %s" % [$LoadDialog.current_path])

func _on_save_dialog_confirmed():
	Log.debug("Main save confirmed: %s" % [$SaveDialog.current_path])

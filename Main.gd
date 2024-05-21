extends Node2D
class_name Main

var Osc := preload("res://osc_receiver.tscn")
var osc: OscReceiver
var oscSender: OscReceiver
static var defaultConfigPath := "res://config/default.ocl"
static var configPath := "user://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := $Actors
@onready var cmdInterface : CommandInterface = $CommandInterface
@onready var lastSender : String = "localhost"
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := $Routines
@onready var stateMachines := {}
@onready var midiCommands := []
@onready var loadedCmdFiles := [] # keep track of loaded files to generate docs on the fly
var ocl: OpenControlLanguage
var config := preload("res://Config.gd").new()
@onready var editor := $HSplitContainer/CodeEdit
@onready var postWindow := $HSplitContainer/PostWindow

#@onready var variablesManager: VariablesManager

@onready var animationsLibrary : SpriteFrames
@onready var animationDataLibrary : AnimationLibrary

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

func _init():
	printVersion()

func createUserConfig(path: String):
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_absolute(path.get_base_dir())
		Log.verbose("Created dir: %s" % [path.get_base_dir()])
	if not FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.WRITE_READ)
		Log.verbose("User config file not found in: %s" % [path])
		file.store_string("# Write your config here")
		Log.verbose("Created config file: %s" % [path])

func getAnimatronVersion() -> String:
	return ProjectSettings.get_setting("application/config/version")

func printVersion():
	Log.info("Animatron version: %s" % [getAnimatronVersion()])

func initPostWindowMsg():
	var msg = ""
	msg += "Animatron\nversion %s\n" % [getAnimatronVersion()]
	msg += "---\n"
	msg += "To see the tutorial write:\n\n"
	msg += "/tutorial\n\n"
	msg += "and press SHIFT + ENTER while the cursor is on that line.\n"
	msg += "---\n\n"
	$HSplitContainer/PostWindow.set_text(msg)

func _ready():
	# if you need to change the log level, do it from the res://config/default.ocl
	Log.setLevel(Log.LOG_LEVEL_INFO)
	initPostWindowMsg()
	
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
	animationDataLibrary = AnimationLibrary.new()
	cmdInterface.animationsLibrary = animationsLibrary
	cmdInterface.animationDataLibrary = animationDataLibrary
	cmdInterface.actorsNode = $Actors
	cmdInterface.editor = $HSplitContainer/CodeEdit
	cmdInterface.textContainer = $HSplitContainer
	cmdInterface.postWindow = $HSplitContainer/PostWindow
	cmdInterface.routinesNode = $Routines
	cmdInterface.stateMachines = Dictionary(stateMachines)
	cmdInterface.stateChangedCallback = Callable(self, "_on_state_changed")
	cmdInterface.saveFileDialog = $SaveFileDialog
	cmdInterface.openFileDialog = $OpenFileDialog
	cmdInterface.loadPresetDialog = $LoadPresetDialog
	_init_midi()
	cmdInterface.midiCommands = midiCommands
	
	ocl = OpenControlLanguage.new()
	
	# using a lambda allows to get the latest version of the dictionary on each call
	#cmdInterface.variablesManager = variablesManager
	#ocl.variablesManager = variablesManager
	
	$SaveFileDialog.set_current_path(OS.get_user_data_dir() + "/animatron")
	$OpenFileDialog.set_current_path(OS.get_user_data_dir() + "/animatron")
	$SaveFileDialog.confirmed.connect(editor._on_save_dialog_confirmed)
	$SaveFileDialog.file_selected.connect(editor.saveFile)
	$OpenFileDialog.confirmed.connect(editor._on_load_dialog_confirmed)
	$OpenFileDialog.file_selected.connect(editor.openFile)
	$LoadPresetDialog.confirmed.connect(_on_load_preset_dialog_confirmed)
	editor.saveDialog = $SaveFileDialog
	editor.loadDialog = $OpenFileDialog
	editor.eval_code.connect(_on_eval_code)
	
	$Midi.midi_noteon.connect(_on_midi_noteon)
	$Midi.midi_noteoff.connect(_on_midi_noteoff)
	$Midi.midi_cc.connect(_on_midi_cc)
	
	loadConfig(defaultConfigPath)
	if not FileAccess.file_exists(configPath):
		createUserConfig(configPath)
	loadConfig(configPath)
	cmdInterface.loadCommandFile("res://commands/extended.ocl")

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _input(event):
	if event.is_action_pressed("toggle_editor", true):
		#$HSplitContainer.set_visible(not($HSplitContainer.is_visible()))
		evalCommand(["/editor/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("clear_post", true):
		postWindow.clear()
		evalCommand(["/post/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("toggle_post", true):
		#$HSplitContainer/VBoxContainer.set_visible(not($HSplitContainer/VBoxContainer.is_visible()))
		evalCommand(["/post/toggle"], "")
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
		if result.isError(): return result
	return Status.ok()

func evalCommand(cmdArray: Array, sender: String) -> Status:
	# we only parse the cmd address because if it's a /def it woul override the def's variables
	var cmd : String = cmdArray[0]
	var args : Array = cmdArray.slice(1)
	var result := Status.new()
	var cmdDescription : Variant = cmdInterface.getCommandDescription(cmd)
	if cmdDescription is String: 
		return evalCommand(cmdArray, sender)
	elif cmdDescription is Dictionary: # it's a /def
		# put variable values from the OSC command into the 
		# CommandDescritpion.variables dictionary
		var subcommands = ocl._def(cmdDescription, args)
		result = evalCommands(subcommands, sender)
	elif cmdDescription is CommandDescription:
		if cmdDescription.toGdScript: args = cmdArray
		result = executeCommand(cmdDescription, args)
	else:
		result = Status.error("Command not found: %s" % [cmd])
	
	# post and reply result
	_on_command_finished(result, sender)
	if result.msg.length() > 0: post(result.msg)
	return result

## Executes a [param command] described in a [CommandDescription], with the given [param args].
func executeCommand(command: CommandDescription, args: Array) -> Status:
	var result := checkNumberOfArguments(command.argsDescription, args if not command.toGdScript else args.slice(1))
	if result.isError(): return result
	var variables = VariablesManager.getAll()
	if not command.deferEvalExpressions:
		# Don't modify the incoming arguments (so expression strings stay as exprsesions)
		args = args.duplicate()
		# Handle expressions in arguments
		for i in args.size():
			result = ocl._resolveVariables(args[i], variables, false)
			if result.isError(): return result
			args[i] = result.value
			var expr := ocl._getExpression(args[i])
			if not expr.is_empty():
				var expResult := ocl._evalExpr(expr, variables.keys(), variables.values())
				if expResult.isError() or expResult.value == null: return Status.error("Invalid expression: %s" % [expr])
				#if not expResult: return Status.error("Invalid expression")
				match typeof(expResult.value):
					TYPE_CALLABLE: args[i] = expResult.value.call()
					_: args[i] = expResult.value as float
	if args.size() == 0 and not command.argsAsArray:
		result = command.callable.call()
	elif command.argsAsArray:
		result = command.callable.call(args)
	elif command.toGdScript:
		var subargs = convertArguments(command.argsDescription, args.slice(1))
		result = command.callable.call(args[0], subargs)
	else:
		# Reduce the number of args to the expected size, else callv will fail.
		# Exceeding arguments will be grouped into an array and passed as the last argument.
		var callableNumArgs = getNumArgsForMethod(command.callable, command.callable.get_method())
		var excessArgs = args.slice(callableNumArgs)
		var finalArgs = args.slice(0, callableNumArgs)
		result = command.callable.callv(finalArgs)
	return result

func getMethodSignature(callable: Callable, methodName: String) -> Variant:
	var args := []
	for method in callable.get_object().get_method_list():
		if methodName == method.name: 
			for arg in method.args:
				args.append(arg.name)
			return args
	return []

func getNumArgsForMethod(callable: Callable, methodName: String) -> int:
	return getMethodSignature(callable, methodName).size()

func checkNumberOfArguments(argsDescription: String, args: Array) -> Status:
	var expectedNumberOfArgs := argsDescription.split(" ").size() if len(argsDescription) > 0 else 0
	# For now, allow arbitrary upper bound when the argsDescription includes repeats
	var actualNumberOfArgs := args.size()
	if argsDescription.contains("..."):
		expectedNumberOfArgs = actualNumberOfArgs
	if actualNumberOfArgs < expectedNumberOfArgs:
		return Status.error("Not enough arguments:\nexpected (%s) -> %s\nreceived (%s) -> %s" % [expectedNumberOfArgs, argsDescription, actualNumberOfArgs, args])
	if actualNumberOfArgs > expectedNumberOfArgs:
		return Status.ok(expectedNumberOfArgs, "Received more arguments (%s) than needed (%s). Using: %s" % [actualNumberOfArgs,  expectedNumberOfArgs, args.slice(0,expectedNumberOfArgs)])
	return Status.ok(expectedNumberOfArgs, "")

## Converts the given [param args] to the type described in [param argsDescription]
func convertArguments(argsDescription: String, args: Array) -> Array:
	var typedArgs := []
	var splitDescriptions := argsDescription.split(" ")
	for i in splitDescriptions.size():
		match splitDescriptions[i].split(":")[1]:
			"i": typedArgs.append(int(args[i]))
			"f": typedArgs.append(float(args[i]))
			"b": 
				if args[i] == "t" or args[i] == "true": args[i] = "1"
				elif args[i] == "f" or args[i] == "false": args[i] = "0"
				typedArgs.append(bool(int(args[i])))
			_: 
				if i < args.size(): typedArgs.append(args[i])
	return typedArgs

func loadConfig(filename: String):
	cmdInterface.loadCommandFile(filename)

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
	if postWindow == null: postWindow = $HSplitContainer/PostWindow
	postWindow.set_text("%s\n%s\n" % [postWindow.get_text(), msg])
	postWindow.set_caret_line(postWindow.get_line_count())

func _on_state_changed(cmd: Array):
	Log.debug("Received signal -- State changed: %s" % [cmd])
	evalCommand(cmd, "")

func _on_load_dialog_confirmed():
	Log.debug("Main load confirmed: %s" % [$LoadDialog.current_path])

func _on_save_dialog_confirmed():
	Log.debug("Main save confirmed: %s" % [$SaveDialog.current_path])
	
func _on_load_preset_dialog_confirmed():
	var path = $LoadPresetDialog.get_current_path()
	evalCommand(["/commands/load", path], "gdscript")
	Log.verbose("Loading preset from: %s" % [path])

func _on_animation_finished(name):
	if stateMachines.has(name):
		var actor = actors.find_child(name)
		var animation = actor.get_node("Animation").get_animation()
		if not stateMachines[name].states.has(animation): return
		var nextStates = stateMachines[name].states[animation]
		var nextState = nextStates[randi() % nextStates.size()]
		if animationsLibrary.has_animation(nextState):
			evalCommands([["/create", name, nextState]], "gdscript")
		Log.debug("%s state machine - %s(%s): %s" % [name, animation, nextState, nextStates])
	pass

extends Node2D
class_name Main

var Osc := preload("res://osc_receiver.tscn")
var osc: OscReceiver
static var historyLogFile := ""
static var defaultConfigPath := "res://config/default.ocl"
static var configPath := "user://config/config.ocl"
var metanode := preload("res://meta_node.tscn")
@onready var actors := $IndirectView/Actors
@onready var cmdInterface : CommandInterface = $CommandInterface
@onready var lastSender : String = "localhost"
@onready var Routine := preload("res://RoutineNode.tscn")
@onready var routines := $Routines
@onready var stateMachines := {}
@onready var midiCommands := []
@onready var loadedCmdFiles := [] # keep track of loaded files to generate docs on the fly
var ocl: OpenControlLanguage
var config := preload("res://Config.gd").new()
@onready var vsplit := $VSplitContainer
@onready var editor := $VSplitContainer/CodeEdit
@onready var postWindow := $VSplitContainer/PostWindow

#@onready var variablesManager: VariablesManager

@onready var animationsLibrary : SpriteFrames
@onready var animationDataLibrary : AnimationLibrary

@onready var lastMouseClick : Vector2:
	get(): return lastMouseClick

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
	msg += "Animatron v%s\n" % [getAnimatronVersion()]
	#msg += "---\n"
	#msg += "To see the tutorial write:\n\n"
	#msg += "/tutorial\n"
	msg += "\n"
	msg += "type /help /commands\n"
	msg += "and press CTRL + ENTER.\n"
	#msg += "---\n"
	msg += "\n"
	postWindow.set_text(msg)

func createSessionHistoryLogFile():
	var timeDict := Time.get_datetime_dict_from_system()
	var time = "%04d%02d%02d_%02d%02d%02d" % [timeDict["year"], timeDict["month"], timeDict["day"], timeDict["hour"], timeDict["minute"], timeDict["second"]]
	historyLogFile = "user://logs/animatron-session-history-%s.ocl" % [time]
	var file = FileAccess.open(historyLogFile, FileAccess.WRITE)
	file.store_string("# animatron session - %s\n" % [time])
	file.close()

func _ready():
	# Have the content area fit to fill the main window
	# To change the "stage" size to something of fixed resolution,
	# use `/view/size sizeX sizeY`
	get_window().content_scale_size = Vector2i(0, 0)
	
	# if you need to change the log level, do it from the res://config/default.ocl
	Log.setLevel(Log.LOG_LEVEL_INFO)
	Log.setLevel(Log.LOG_LEVEL_DEBUG)
	
	
	osc = OscReceiver.new()
	self.add_child.call_deferred(osc)
	osc.startServer()
	osc.osc_msg_received.connect(_on_osc_msg_received)
	cmdInterface.commandManager = self
	cmdInterface.command_finished.connect(_on_command_finished)
	cmdInterface.command_error.connect(_on_command_error)
	cmdInterface.command_file_loaded.connect(_on_command_file_loaded)
	cmdInterface.routine_added.connect(_on_routine_added)
	cmdInterface.oscSender = osc
	
	var animationsLibraryNode = AnimatedSprite2D.new()
	animationsLibraryNode.set_sprite_frames(SpriteFrames.new())
	animationsLibrary = animationsLibraryNode.get_sprite_frames()
	add_child.call_deferred(animationsLibraryNode)
	animationDataLibrary = AnimationLibrary.new()
	cmdInterface.animationsLibrary = animationsLibrary
	cmdInterface.animationDataLibrary = animationDataLibrary
	cmdInterface.actorsNode = $IndirectView/Actors
	cmdInterface.editor = $VSplitContainer/CodeEdit
	cmdInterface.textContainer = $VSplitContainer
	cmdInterface.postWindow = $VSplitContainer/PostWindow
	cmdInterface.mirrorDisplay = $MirrorDisplay
	cmdInterface.indirectView = $IndirectView
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
	editor.font_size_changed.connect(_on_editor_font_size_chaned.bind(editor))
	createSessionHistoryLogFile()
	editor.historyFile = historyLogFile
	
	$Midi.midi_noteon.connect(_on_midi_noteon)
	$Midi.midi_noteoff.connect(_on_midi_noteoff)
	$Midi.midi_cc.connect(_on_midi_cc)
	
	loadConfig(defaultConfigPath)
	if not FileAccess.file_exists(configPath):
		createUserConfig(configPath)
	loadConfig(configPath)
	var argsConfig := getPathFromArgs()
	if argsConfig.length() > 0: loadConfig(argsConfig)
	cmdInterface.loadCommandFile("res://commands/extended.ocl")
	var helpContents := DocGenerator.asciidocFromCommandsFile("res://commands/extended.ocl")
	helpContents += DocGenerator.asciidocFromCommandDescriptions(cmdInterface.coreCommands)
	DocGenerator.writeTextToFile("res://docs/help.adoc", helpContents)
	DocGenerator.generateTutorial("res://docs/tutorial.adoc", "res://tutorial/")
	initPostWindowMsg()
	updateVSplitOffset()

func getPathFromArgs() -> String:
	Log.verbose("CLI args: %s" % [OS.get_cmdline_args()])
	Log.verbose("CLI user args: %s" % [OS.get_cmdline_user_args()])
	var path := ""
	for arg in OS.get_cmdline_user_args():
		var keyValue = arg.split("=")
		if keyValue[0] == "--file": return keyValue[1]
	return path
	

# Called every frame. 'delta' is the elapsed time since the previous frame./
func _process(_delta):
	pass

func _input(event):
	updateVSplitOffset()
	if event.is_pressed():
		editor.grab_focus()
	if event.is_action_pressed("mouse_click", true):
		setLastMouseClick()
	if event.is_action_pressed("toggle_editor", true):
		evalCommand(["/editor/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("clear_editor", true):
		evalCommand(["/editor/clear"], "")
		_ignoreEvent()
	if event.is_action_pressed("clear_post", true):
		postWindow.clear()
		evalCommand(["/post/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("toggle_post", true):
		evalCommand(["/post/toggle"], "")
		_ignoreEvent()
	if event.is_action_pressed("open_text_file", true):
		$OpenFileDialog.popup()
		_ignoreEvent()
	if event.is_action_pressed("save_text_file", true):
		$SaveFileDialog.popup()
		_ignoreEvent()
	if event.is_action_pressed("eval_block"): 
		editor._input(event)
	if event.is_action_pressed("eval_line"): 
		editor._input(event)
	if event.is_action_pressed("increase_editor_font"): 
		editor._input(event)
	if event.is_action_pressed("decrease_editor_font"): 
		editor._input(event)
	if event.is_action_pressed("previous_command"):
		editor._input(event)
	if event.is_action_pressed("next_command"):
		editor._input(event)

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
	if cmdArray.size() == 0: return
	var cmd : String = cmdArray[0]
	var result : Status
	var cmdDescription : Variant = cmdInterface.getCommandDescription(cmd)
	if cmdDescription is String: 
		return evalCommand(cmdArray, sender)
	elif cmdDescription is Dictionary: # it's a /def
		# put variable values from the OSC command into the 
		# CommandDescritpion.variables dictionary
		var args : Array = cmdArray.slice(1)
		var subcommands = ocl._def(cmdDescription, args, cmdInterface)
		result = evalCommands(subcommands, sender)
	elif cmdDescription is CommandDescription:
		var args : Array = cmdArray.slice(1)
		if cmdDescription.toGdScript: args = cmdArray
		result = executeCommand(cmdDescription, args)
	else:
		result = Status.warning("Command not found: %s" % [cmd])
	
	# post and reply result
	Log.verbose("> %s" % [" ".join(cmdArray)])
	_on_command_finished(result, sender)
	#if result.msg.length() > 0: post(result.msg)
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
		var finalArgs = args.slice(0, callableNumArgs)
		result = command.callable.callv(finalArgs)
	if result == null: return Status.ok()
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

func updateVSplitOffset():
	var offset = editor.getFontSize() * (editor.get_line_count() + 0.5) - vsplit.get_size().y
	vsplit.set_split_offset(offset)

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
	#if result.msg.is_empty(): return
	match result.type:
		Status.NULL: return
		Status.INFO: _on_command_info(result.msg, sender)
		Status.ERROR: _on_command_error(result.msg, sender)
		Status.WARNING: _on_command_warning(result.msg, sender)
		_: 
			Log.verbose("Command finished:\n%s" % [result.msg])
			return

func _on_command_info(msg: String, sender: String):
	Log.info(msg)
	cmdInterface.post([msg])
	if sender:
		osc.sendMessage(sender, "/status/reply", [msg])

func _on_command_error(msg: String, sender: String):
	Log.error("Command error: %s" % [msg])
	if sender:
		osc.sendMessage(sender, "/error/reply", [msg])

func _on_command_warning(msg: String, sender: String):
	Log.warn(msg)
	if sender:
		osc.sendMessage(sender, "/warning/reply", [msg])

func _on_command_file_loaded(cmds: Array):
	evalCommands(cmds, lastSender)

func _on_routine_added(routineName: String):
	var routine = $Routines.find_child(routineName, true, false)
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
	for cmd in midiCommands[ch]["noteOffNum"]:
		var value = Midi.map(num, cmd[-2], cmd[-1])
		cmd = cmd.slice(0,-2)
		cmd.append(value)
		evalCommand(cmd, "")
	for cmd in midiCommands[ch]["noteOff"]:
		evalCommand(cmd, "")

# "cc"
func _on_midi_cc(ch: int, num: int, value: int):
	Log.verbose("MIDI CC: %s %s %s" % [ch, num, value])
	for cmd in midiCommands[ch]["cc"][num]:
		value = Midi.map(value, cmd[-2], cmd[-1])
		cmd = cmd.slice(0,-2)
		cmd.append(value)
		evalCommand(cmd, "")

func post(msg: Variant):
	if postWindow == null: postWindow = $VSplitContainer/PostWindow
	prependText(postWindow, msg)

func prependText(target: TextEdit, msg: Variant):
	target.set_line(0, "%s\n%s" % [msg, target.get_line(0)])

func setLastMouseClick():
		lastMouseClick = get_viewport().get_mouse_position()
		evalCommand(["/set","mousex:f",lastMouseClick.x],"main")
		evalCommand(["/set","mousey:f",lastMouseClick.y],"main")
		evalCommand(["/post","mouse: ", lastMouseClick.x, lastMouseClick.y],"main")

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

func _on_animation_finished(actorName):
	if stateMachines.has(actorName):
		var actor = actors.find_child(actorName)
		var animation = actor.get_node("Animation").get_animation()
		if not stateMachines[actorName].states.has(animation): return
		var nextStates = stateMachines[actorName].states[animation]
		var nextState = nextStates[randi() % nextStates.size()]
		if animationsLibrary.has_animation(nextState):
			evalCommands([["/animation", actorName, nextState]], "gdscript")
		Log.debug("%s state machine - %s(%s): %s" % [actorName, animation, nextState, nextStates])
	pass

func _on_resized() -> void:
	updateVSplitOffset()

func _on_editor_font_size_chaned(obj: CodeEdit) -> void:
	#if editor == null: return
	Log.debug("font : %s" % [obj.getFontSize()])
	updateVSplitOffset()

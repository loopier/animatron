class_name CommandInterface
extends Node

## Map OSC commands to Godot functionality
##
## Using dictionaries to store variable values and function pointers.
##
## @tutorial:	TODO
## @tutorial(2):	TODO

signal command_finished(msg, sender)
signal command_error(msg, sender)
signal command_file_loaded(cmds)
signal routine_added(name)

@onready var thread: Thread
@onready var mutex: Mutex

var ocl := preload("res://ocl.gd").new()
var status := preload("res://Status.gd")
var metanode := preload("res://meta_node.tscn")
@onready var Routine := preload("res://RoutineNode.tscn")
var assetHelpers := preload("res://asset_helpers.gd").new()
@onready var editor: CodeEdit
@onready var openFileDialog: FileDialog
@onready var saveFileDialog: FileDialog
@onready var postWindow: Node
@onready var actorsNode: Node
@onready var routinesNode: Node
@onready var stateMachines: Dictionary
@onready var stateChangedCallback: Callable
@onready var commandManager: Node
@onready var midiCommands: Array
@onready var oscSender: OscReceiver
var animationsLibrary: SpriteFrames ## The meta node containing these frames needs to be initialized in _ready
var assetsPath := "user://assets"
var animationAssetsPath := assetsPath + "/animations"
var Flags := CommandDescription.Flags

## Core commands map.[br]
var coreCommands: Dictionary = {
	"/help": CommandDescription.new(getHelp, "cmd:s", "Get documentation about CMD."),
#	"/test": CommandDescription.new(getActor, "", "This is just a test"), ## used to test random stuff
	"/set": CommandDescription.new(setVar, "variable:type value:ifbs...", "Set a user VARIABLE with a VALUE, specifying the TYPE (:i = int, :f = float, :b = bool, :s string, :... = arbitrary number of arguments passed as array).\n\nUsage: /set x:f 3.14", Flags.asArray(false)),
	"/get": CommandDescription.new(getVar, "variable:s", "Get the value of a VARIABLE."),
	# log
	"/log/level": CommandDescription.new(setLogLevel, "level:s", "Set the log level to either 'fatal', 'error', 'warn', 'debug' or 'verbose'"),
	# general commands
	"/commands/list": CommandDescription.new(listAllCommands, "", "Get list of available commands."),
	"/commands/load": CommandDescription.new(loadCommandFile, "path:s", "Load a custom command definitions file, which should have the format described below."),
	# assets
	"/load": CommandDescription.new(loadAnimationAsset, "animation:s", "Load an ANIMATION asset from disk. It will create an animation with the same name as the asset. Wildcards are supported, so several animations can be loaded at once. See also: `/assets/list`."),
	"/unload": CommandDescription.new(unloadAnimationAsset, "animation:s", "Removes the ANIMATION asset from disk. This allows to free memory, and to reload a fresh version of the animation."),
	"/assets/list": CommandDescription.new(listAnimationAssets, "", "Get the list of available (unloaded) assets. Assets must be loaded as animations in order to create actor instances."), # available in disk
	"/assets/path": CommandDescription.new(setAssetsPath, "path:s", "Set the path for the parent directory of the assets."), # available in disk
	"/animations/list": CommandDescription.new(listAnimations, "", "Get the list of available (loaded) animations."), # loaded
	
	# label
	"/text/property": CommandDescription.new(_setTextProperty, "property:s actor:s value:...", "Change the ACTOR's text GDScript PROPERTY. Slashes ('/') will be replaced for underscores '_'. Leading slash is optional.\n\nUsage: `/text/property /text target alo bla`", Flags.asArray(true)),
	"/editor/property": CommandDescription.new(_setEditorProperty, "property:s value:...", "Change the editor's font GDScript PROPERTY. Slashes ('/') will be replaced for underscores '_'. Leading slash is optional.\n\nUsage: `/editor/property /font/size 32`", Flags.asArray(true)),
	
	"/actors/list": CommandDescription.new(listActors, "", "Get list of current actor instances. Returns /list/actors/reply OSC message."),
	"/create": CommandDescription.new(createActor, "actor:s animation:s", "Create an ACTOR that plays ANIMATION."),
	"/remove": CommandDescription.new(removeActor, "actor:s", "Delete the ACTOR by name (remove its instance). "),
	"/color": CommandDescription.new(colorActor, "actor:s r:f g:f b:f", "Add an RGB colour to the ACTOR. R, G and B should be in the 0-1 range (can be negative to subtract colour). Set to black (0,0,0) to restore its original colour."),
	"/opacity": CommandDescription.new(setActorOpacity, "actor:s opacity:f", "Set OPACITY of ACTOR and its children."),
	# routines
	"/routine": CommandDescription.new(addRoutine, "name:s repeats:i interval:f cmd:...", "Start a routine named NAME that sends CMD every INTERVAL of time (in seconds) for an arbitrary number of REPEATS.", Flags.asArray(true)),
	"/routines": CommandDescription.new(listRoutines, "", "Get the list of routines."),
	"/routine/start": CommandDescription.new(startRoutine, "name:s", "Start the routine named NAME."),
	"/routine/stop": CommandDescription.new(stopRoutine, "name:s", "Stop the routine named NAME."),
	"/routine/free": CommandDescription.new(freeRoutine, "name:s", "Remove the routine named NAME"),
	"/routine/finished": CommandDescription.new(finishedRoutine, "routine:s cmd:s", "Set the CMD to be sent when the ROUTINE (name) is finished.", Flags.asArray(true)),
	"/wait": CommandDescription.new(wait, "time:f cmd:...", "Wait some TIME to execute the CMD.", Flags.asArray(true)),
	# state machine
	"/state/def": CommandDescription.new(defineState, "state:s entry:s exit:s", "Define a STATE with an ENTRY `/def` to be executed when the state begins, and an EXIT `/def` to be executed when it ends. Both should be existing `/def`s without parameters.\n\nSee `/state/add` and `/state/next`"),
	"/state/add": CommandDescription.new(addState, "machine:s state:s next:s", "Add a STATE with a name to the state MACHINE. NEXT states is an arbitrary number of next possible states. Example: `/state/add mymachine stateA state1 state2` would create a new stateA in `mymachine` that would either repeat or move on to `state2.\n\nSee `/state/def`", Flags.asArray(true)),
	"/states": CommandDescription.new(listStates, "", "Get a list of states for the given ACTOR."),
	"/state/free": CommandDescription.new(freeState, "machine:s state:s", "Remove the STATE from the state MACHINE."),
	"/state/next": CommandDescription.new(nextState, "machine:s", "Change MACHINE to next state.  This will send the 'exit' command of the current state, and the 'entry' command of the next state.\n\nSee `/state/def`"),
	# def
	"/def": CommandDescription.new(defineCommand, "cmdName:s [args:v] subcommands:c", "Define a custom OSC command that is a list of other OSC commands. This may be recursive, so each SUBCOMMAND may reference one of the built-in commands, or another custom-defined command. Another way to define custom commands is via the file commands/init.osc. The CMDNAME string (first argument) may include argument names (ARG1 ... ARGN), which may be referenced as SUBCOMMAND arguments using $ARG1 ... $ARGN. Example: /def \"/addsel actor anim\" \"/create $actor $anim\" \"/select $actor\". ", Flags.asArray(true)),
	# for (loop)
	"/for": CommandDescription.new(forCommand, "varName:s iterations:i cmd:s", "Iterate `iterations` times over `varName`, substituting the current iteration value in each call to `cmd`.", Flags.asArray(true)),
	# editor
	"/editor/append": CommandDescription.new(appendTextToEditor, "text:...", "Append TEXT to the last line of the editor.", Flags.asArray(true)),
	"/editor/clear": CommandDescription.new(clearEditor, "", "Delete all text from the editor."),
	"/editor/open": CommandDescription.new(openTextFile, "", "Open a file dialog and append the selected file contents at the end."),
	"/editor/save": CommandDescription.new(saveTextFile, "", "Save the code using a file dialog."),
	"/editor/open/from": CommandDescription.new(openTextFileFrom, "path:s", "Load code from PATH and append it to the end."),
	"/editor/save/to": CommandDescription.new(saveTextFileTo, "path:s", "Save the code to PATH."),
	# post
	"/post": CommandDescription.new(post, "msg:s", "Print MSG in the post window.", Flags.asArray(false)),
	"/post/show": CommandDescription.new(showPost, "", "Show post window."),
	"/post/hide": CommandDescription.new(hidePost, "", "Hide post window."),
	"/post/toggle": CommandDescription.new(togglePost, "", "Toggle post window visibility."),
	"/post/clear": CommandDescription.new(clearPost, "", "Clear post window contents."),
	# osc
	"/osc/remote": CommandDescription.new(connectOscRemote, "ip:s port:i", "Set the IP address and PORT number of a remote OSC server.", Flags.asArray(true)),
	"/osc/send": CommandDescription.new(sendOscMsg, "msg:s", "Send an OSC message to a remote server. See `/osc/remote`.", Flags.asArray(true)),
	# midi
	"/midi/cc": CommandDescription.new(midiCC, "channel:i cmd:s", "Map the control value to a CMD. The last 2 CMD arguments should be MIN and MAX, in that order. Example: /midi/cc 0 /position/x target 0 1920. *WARNING: this only works with commands that accept 1 argument.*", Flags.asArray(true)),
	"/midi/noteon/num": CommandDescription.new(midiNoteOnNum, "channel:i cmd:s", "Map the pressed note number to a CMD. The last 2 CMD arguments should be MIN and MAX, in that order. Example: /midi/noteon/num 0 /position/x target 0 1920. *WARNING: this only works with commands that accept 1 argument.*", Flags.asArray(true)),
	"/midi/noteon/trig": CommandDescription.new(midiNoteOnTrig, "channel:i note:i cmd:s", "Execute a CMD when a note-on event is triggered on a specific NOTE.", Flags.asArray(true)),
	"/midi/noteon/num/velocity": CommandDescription.new(midiNoteOnNumVelocity, "channel:i note:i cmd:s", "Map the NOTE velocity to a CMD. The last 2 CMD arguments should be MIN and MAX, in that order. Example: /midi/noteon/num 0 60 /position/y target 0 1080. *WARNING: this only works with commands that accept 1 argument.*", Flags.asArray(true)),
	"/midi/noteon/velocity": CommandDescription.new(midiNoteOnVelocity, "channel:i cmd:s", "Map the velocity of any note to a CMD. The last 2 CMD arguments should be MIN and MAX, in that order. Example: /midi/noteon/num 0 /position/y target 0 1080. *WARNING: this only works with commands that accept 1 argument.*.", Flags.asArray(true)),
	"/midi/noteon": CommandDescription.new(midiNoteOn, "channel:i cmd:s", "Execute a CMD when a note-on MIDI event is triggered on any note.", Flags.asArray(true)),
	"/midi/noteoff/num": CommandDescription.new(midiNoteOffNum, "channel:i cmd:s", "Map the released NOTE number to a CMD. The last 2 CMD arguments should be MIN and MAX, in that order. Example: /midi/noteon/num 0 /position/x target 0 1920. *WARNING: this only works with commands that accept 1 argument.*",Flags.asArray(true)),
	"/midi/noteoff": CommandDescription.new(midiNoteOff, "channel:i cmd:s", "Execute a CMD when a note-off MIDI event is triggered on any note.", Flags.asArray(true)),
	"/midi/list": CommandDescription.new(midiList, "event:s [args:v]", "List commands for the EVENT in CHANNEL and optional NUM. Events is one of: noteon, noteonnum, noteonvelocity, noteonnumvelocity (NUM), noteontrig (NUM), noteoff, noteoffnum, cc (NUM)", Flags.asArray(true)),
	"/midi/noteon/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/noteon/num/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/noteon/num/velocity/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/noteon/trig/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/noteoff/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/noteoff/num/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/cc/free": CommandDescription.new(freeMidi, "channel:i [num:i]", "Remove a cmd from the event.", Flags.gdScript()),
	"/midi/free": CommandDescription.new(clearMidi, "", "Remove all commands from MIDI events."),
	# utils
	"/rand": CommandDescription.new(randCmdValue, "cmd:s actor:s min:f max:f", "Send a CMD to an ACTOR with a random value between MIN and MAX. If a wildcard is used, e.g. `bl*`, all ACTORs with with a name that begins with `bl` will get a different value. *WARNING: This only works with single-value commands.*", Flags.asArray(true)),
	"/tween": CommandDescription.new(tweenActorProperty, "dur:f transition:s property:s actor:s value:f", "Tweens a PROPERTY of an ACTOR between the current value and final VALUE in a span of time equal to DURation, in seconds. The TRANSITION must be one of: linear, sine, quint, quart, quad, expo, elastic, cubic, circ, bounce, back and spring.", Flags.asArray(true)),
	# Node
	"/flip/v": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip/ ACTOR vertically.", Flags.gdScript()),
	"/flip/h": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip ACTOR horizontally.", Flags.gdScript()),
	"/visible": CommandDescription.new(toggleActorProperty, "actor:s visibility:b", "Set ACTOR's VISIBILITY to either true or false.", Flags.gdScript()),
	"/parent": CommandDescription.new(parentActor, "child:s parent:s", "Set an actor to be the CHILD of another PARENT actor."),
	"/parent/free": CommandDescription.new(parentActorFree, "child:s", "Free the CHILD actor from it's parent."),
	"/children/list": CommandDescription.new(listChildren, "parent:s", "List all PARENT's children actors."),
	"/front": CommandDescription.new(setInFrontOfActor, "actor:s target:s", "Draw the ACTOR in front of the TARGET.", Flags.asArray(false)),
	"/behind": CommandDescription.new(setBehindActor, "actor:s target:s", "Draw the ACTOR behind the TARGET.", Flags.asArray(false)),
	"/top": CommandDescription.new(setTopActor, "actor:s", "Draw the ACTOR on top of everything else.", Flags.asArray(false)),
	"/bottom": CommandDescription.new(setBottomActor, "actor:s", "Draw the ACTOR behind everything else.", Flags.asArray(false)),
	"/center": CommandDescription.new(center, "actor:s", "Set the ACTOR to the center of the screen."),
	
	# actors
	"/property": CommandDescription.new(setActorProperty, "property:s actor:s value:...", "Generic command to set the VALUE to any PROPERTY of an ACTOR.", Flags.asArray(false)),
	"/property/relative": CommandDescription.new(setActorRelativeProperty, "property:s actor:s value:...", "Generic command to set the VALUE to any PROPERTY of an ACTOR.", Flags.asArray(false)),
	"/method": CommandDescription.new(callActorMethod, "method:s actor:s args:...", "Generic command to call an ACTOR's METHOD with some ARGS.", Flags.asArray(false)),
	# animation
	"/animation/property": CommandDescription.new(setAnimationProperty, "property:s actor:s value:...", "Change the ACTOR's ANIMATION GDScript PROPERTY. Slashes ('/') will be replaced for underscores '_'. Leading slash is optional.\n\nUsage: `/animation/property /rotation/degrees target 75`", Flags.asArray(false)),
	"/animation/method": CommandDescription.new(callAnimationMethod, "method:s actor:s args:...", "Call a METHOD on the ACTOR's animation with some ARGS.", Flags.asArray(false)),
	"/animation/frames/method": CommandDescription.new(callAnimationFramesMethod, "method:s actor:s args:...", "Call a METHOD on the ACTOR's animation with some ARGS.", Flags.asArray(false)),
}

## Custom command definitions
var defCommands := {}

# Called when the node enters the scene tree for the first time.
func _ready():
	oscSender = OscReceiver.new()
	thread = Thread.new()
	mutex = Mutex.new()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

## Adds a custom command definition
## The subcommands need to be an array, so we have to use an array for the whole arguments.
## It would be better to separate the arguments in the signature (defCommand: String, defArgs: Array, commandList: Array)
## but then we'd need to do it in parseCommand and would clutter the code. Maybe we can change it when
## we implement other methods with comma-sparated arguments -- or any other separator
func defineCommand(args: Array) -> Status:
	var splits = _splitArray(",", args)
	var commandDef = splits[0]
	var commandName = commandDef[0]
	var commandVariables = commandDef.slice(1)
	var subCommands = splits.slice(1)
	defCommands[commandName] = {"variables": commandVariables, "subcommands": subCommands}
	return Status.ok([commandName, commandVariables, subCommands], "Added command def: %s %s" % [commandName, commandVariables, subCommands])

func forCommand(args: Array) -> Status:
	var cmds: Array = ocl._for(args);
	return commandManager.evalCommands(cmds, "CommandInterface")
	
## Load commands from a file and return an array
func loadCommandFile(path: String) -> Status:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null: file = FileAccess.open("user://" + path, FileAccess.READ)
	if file == null: return Status.ok([], "No command file '%s' found to load" % [path])
	var contents = file.get_as_text(true)
	var cmds: Array = convertTextToCommands(contents).value
	command_file_loaded.emit(cmds)
	return Status.ok(cmds, "Loaded commands from: %s" % [path])

## Converts multiple lines of text to an array of commands, ignoring empty lines and comments
func convertTextToCommands(input: String) -> Status:
	var cmds := []
	var blocks := getTextBlocks(input)
	for block in blocks:
		if isDef(block):
			cmds.append(convertDefBlockToCommand(block))
		else:
			cmds.append_array(convertTextBlockToCommands(block))
	return Status.ok(cmds)

func convertTextBlockToCommands(block: String) -> Array:
	var cmds := []
	var lines := Array(getTextLines(block)) # convert from PackedStringArray
	lines = lines.filter(filterComments)
	lines = lines.filter(filterEmptyLines)
	
	for line in lines:
		var cmd := convertTextLineToCommand(line)
		cmds.append(cmd)
	Log.verbose("Converted text block to command: %s" % [cmds])
	return cmds

## Converts a [method /def] block of text, to a parsable [method /def] command
## inserting "," between lines
func convertDefBlockToCommand(input: String) -> Array:
	var lines := getTextLines(input)
	lines = lines.filter(filterComments)
	lines = lines.filter(filterEmptyLines)
	var def := []
	for i in len(lines):
		var cmd = convertTextLineToCommand(lines[i])
		def.append_array(cmd)
		if i < len(lines) - 1:
			def.append(",")
	Log.verbose("Converted text def block to command: %s" % [def])
	return def

func convertTextLineToCommand(line: String) -> Array:
	return line.strip_edges().split(" ")

func isDef(input: String) -> bool:
	var regex = RegEx.new()
	# accept as def a block with a comment, it's be removed when converted to command
	regex.compile("(^#.*\\n)*/def\\s+(.*)(\\n\\s+.*|^\\s#)*")
	var result = regex.search(input)
	return result != null

## Returns an array of strings as text blocks
func getTextBlocks(input: String) -> Array:
	return input.split("\n\n")

func getTextLines(input: String) -> Array:
	return input.split("\n")

## To be used with [method Array.filter()]
func filterComments(line: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^\\s*#")
	var result = regex.search(line)
	return not result

## To be used with [method Array.filter()]
func filterEmptyLines(line: String) -> bool:
	return not line.is_empty()

## Similar to [method String.split] but with for arrays.
## Returns a 2D array
func _splitArray(delimiter: String, args: Array) -> Array:
	var result := []
	var last := 0
	for i in len(args):
		if typeof(args[i]) == TYPE_STRING and args[i] == delimiter:
			result.append(args.slice(last, i))
			i += 1
			last = i
	# when no delimiter is found, append everything as one single item, or
	# append everything after the last delimiter.
	result.append(args.slice(last))
	return result

func setLogLevel(level: String) -> Status:
	match level:
		"fatal": Log.setLevel(Log.LOG_LEVEL_FATAL)
		"error": Log.setLevel(Log.LOG_LEVEL_ERROR)
		"warn": Log.setLevel(Log.LOG_LEVEL_WARNING)
		"info": Log.setLevel(Log.LOG_LEVEL_INFO)
		"debug": Log.setLevel(Log.LOG_LEVEL_DEBUG)
		"verbose": Log.setLevel(Log.LOG_LEVEL_VERBOSE)
	return Status.ok(Log.getLevel(), "Log level: %s" % [Log.getLevel()])

func appendTextToEditor(args: Array) -> Status:
	var msg = " ".join(args) if args.size() > 0 else ""
	editor.set_line(editor.get_line_count()-1, editor.get_line(editor.get_line_count()-1) + "\n" + msg)
	return Status.ok()

func clearEditor() -> Status:
	editor.set_text("")
	return Status.ok()

func saveTextFile() -> Status:
	saveFileDialog.popup()
	return Status.ok()

func saveTextFileTo(path: String) -> Status:
	editor.saveFile(path)
	return Status.ok()

func openTextFile() -> Status:
	openFileDialog.popup()
	return Status.ok()

func openTextFileFrom(path: String) -> Status:
	editor.openFile(path)
	return Status.ok()

func post(args: Array) -> Status:
	args = " ".join(PackedStringArray(args)).split("\\n")
	for arg in args:
		Log.info(arg)
	postWindow.set_line(postWindow.get_line_count()-1, postWindow.get_line(postWindow.get_line_count()-1) + " ".join(args) + "\n")
	postWindow.set_caret_line(postWindow.get_line_count())
	return Status.ok(args)

func showPost() -> Status:
	postWindow.set_visible(true)
	return Status.ok()

func hidePost() -> Status:
	postWindow.set_visible(false)
	return Status.ok()

func togglePost() -> Status:
	postWindow.set_visible(not(postWindow.is_visible()))
	return Status.ok()

func clearPost() -> Status:
	postWindow.set_text("")
	return Status.ok()

func connectOscRemote(args: Array) -> Status:
	oscSender.senderIP = args[0]
	oscSender.senderPort = int(args[1])
	return Status.ok(oscSender.senderIP, "Connecting to OSC server: %s:%s" % [oscSender.senderIP, oscSender.senderPort])

func sendOscMsg(msg: Array) -> Status:
	var target = "%s/%s" % [oscSender.senderIP, oscSender.senderPort]
	oscSender.sendMessage(target, msg[0], msg.slice(1))
	return Status.ok()

func midiCC(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	# convert las 2 arguments (min and max)
	args[-2] = float(args[-2])
	args[-1] = float(args[-1])
	midiCommands[chan]["cc"][num].append(args.slice(2))
	return Status.ok()

func midiNoteOnNum(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	# convert las 2 arguments (min and max)
	args[-2] = float(args[-2])
	args[-1] = float(args[-1])
	midiCommands[chan]["noteOnNum"].append(args.slice(1))
	return Status.ok()

func midiNoteOnTrig(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	midiCommands[chan]["noteOnTrig"][num] = [args.slice(2)]
	return Status.ok()

func midiNoteOnNumVelocity(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	# convert las 2 arguments (min and max)
	args[-2] = float(args[-2])
	args[-1] = float(args[-1])
	midiCommands[chan]["noteOnNumVelocity"][num].append(args.slice(2))
	return Status.ok()

func midiNoteOnVelocity(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	# convert las 2 arguments (min and max)
	args[-2] = float(args[-2])
	args[-1] = float(args[-1])
	midiCommands[chan]["noteOnVelocity"].append(args.slice(1))
	return Status.ok()

func midiNoteOn(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	midiCommands[chan]["noteOn"].append(args.slice(2))
	return Status.ok()

func midiNoteOffNum(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	# convert las 2 arguments (min and max)
	args[-2] = float(args[-2])
	args[-1] = float(args[-1])
	midiCommands[chan]["noteOffNum"].append(args.slice(1))
	return Status.ok()

func midiNoteOff(args: Array) -> Status:
	var chan = int(args[0])
	var num = int(args[1])
	midiCommands[chan]["noteOff"].append(args.slice(2))
	return Status.ok()

func midiList(args: Array) -> Status:
	var event = args[0]
	var ch = int(args[1])
	args = args.slice(2)
	match event:
		"noteon": return Status.ok(true, "%s" % [midiCommands[ch]["noteOn"]])
		"noteonnum": return Status.ok(true, "%s" % [midiCommands[ch]["noteOnNum"]])
		"noteonvelocity": return Status.ok(true, "%s" % [midiCommands[ch]["noteOnVelocity"]])
		"noteonnumvelocity": 
			if len(args) > 0:
				return Status.ok(true, "%s" % [midiCommands[ch]["noteOnNumVelocity"][int(args[0])]])
			return Status.ok(true, "%s" % [midiCommands[ch]["noteOnNumVelocity"]])
		"noteontrig": 
			if len(args) > 0:
				return Status.ok(true, "%s" % [midiCommands[ch]["noteOnTrig"][int(args[0])]])
			return Status.ok(true, "%s" % [midiCommands[ch]["noteOnTrig"]])
		"noteoff": return Status.ok(true, "%s" % [midiCommands[ch]["noteOff"]])
		"noteoffnum": return Status.ok(true, "%s" % [midiCommands[ch]["noteOffNum"]])
		"cc": 
			if len(args) > 0:
				return Status.ok(true, "%s" % [midiCommands[ch]["cc"][int(args[0])]])
			return Status.ok(true, "%s" % [midiCommands[ch]["cc"]])
		_: return Status.error("event not found: %s.\n Try one of: noteon, noteonnum, noteonvelocity, noteonnumvelocity, noteontrig, noteoff, noteoffnum, cc")
	return Status.ok()

func freeMidi(cmd: String, args: Array) -> Status:
	# remove the `/midi/` begining and trailing `/free`
	var event = cmd.substr(5,len(cmd)-10).replace("/", "_").to_pascal_case()
	event = event.substr(0,1).to_lower() + event.substr(1)
	event = event.replace("noteo", "noteO")
	var chan = int(args[0])
	var num = args.slice(1)
	midiCommands[chan][event].clear()	
	Log.debug("event: %s args: %s" % [event, args])
	return Status.ok()

func clearMidi() -> Status:
	for ch in len(midiCommands):
		midiCommands[ch]["noteOn"].clear()
		midiCommands[ch]["noteOnNum"].clear()
		midiCommands[ch]["noteOnVelocity"].clear()
		midiCommands[ch]["noteOnNumVelocity"].clear()
		midiCommands[ch]["noteOnTrig"].clear()
		midiCommands[ch]["noteOff"].clear()
		midiCommands[ch]["noteOffNum"].clear()
		midiCommands[ch]["cc"].clear()
	return Status.ok()

func getHelp(cmd: String) -> Status:
	var cmdDesc = getCommandDescription(cmd)
	if not(cmd.begins_with("/")): 
		return getHelp("/" + cmd)
	if cmdDesc == null:
		return Status.error("Help not found: %s" % [cmd])
	
	postWindow.set_visible(true)
	postWindow.set_text("")
	# if it's a /def dump the def's code
	if typeof(cmdDesc) == TYPE_DICTIONARY: 
		var msg := "[HELP] custom definition\n\n/def %s" % [cmd]
		for key in cmdDesc.variables:
			msg += " %s" % [key]
		msg += "\n"
		for subcmd in cmdDesc.subcommands:
			msg += "\t%s\n" % [" ".join(subcmd)]
		return Status.ok(cmdDesc, msg)
	
	# it's a core command
	var msg = "[HELP] %s %s\n\n%s" % [cmd, cmdDesc.argsDescription, cmdDesc.description]
	return Status.ok(cmdDesc, msg)

## Return a dictionary based on the string [param oscStr] of OSC messages.[br]
## The address is the key of the dictionary (or the first element), and the 
## array of arguments the value.
func oscStrToDict(oscStr: String) -> Dictionary:
	var dict := {}
	var lines = oscStr.split("\n")
	for line in lines:
		var items: Array = line.split(" ")
		if items[0] == "": continue
		dict[items[0]] = items.slice(1)
	return dict

func isActor(actorName: String) -> bool:
	return false if actorsNode.find_child(actorName) == null else true

## Set and store new [param value] in a variable with a [param varName]
## Returns the value stored in the variable
func setVar(args: Array) -> Status:
	if not args[0].contains(":"): return Status.error("Missing type. %s:?" % [args[0]])
	var varName = args[0].split(":")[0]
	var type = args[0].split(":")[1]
	args = args.slice(1)
	match type:
		"i": VariablesManager.setValue(varName, args[0] as int)
		"f": VariablesManager.setValue(varName, args[0] as float)
		"b": VariablesManager.setValue(varName, args[0] as bool)
		"s": VariablesManager.setValue(varName, " ".join(args))
		"...": VariablesManager.setValue(varName, args)
	return getVar(varName)

## Get a variable value by [param varName].
##
## This method returns a single value. If by any reason the value holds
## more than one, it will return only the first one.
func getVar(varName: String) -> Status:
	var value = VariablesManager.getValue(varName)
	# error managment cannot be done from a static method (in this case in VariablesManager.getValue())
	if value == null: return Status.error("Variable '%s' not found return: %s" % [varName, value])
	if typeof(value) == TYPE_CALLABLE: value = value.call()
	#return Status.ok(value, "Variable '%s': %s" % [varName, value])
	return Status.ok(value)

## Returns the value of a command to be executed.
## If no description is found, it returns [code]null[/code].
func getCommandDescription(command: String) -> Variant:
	if coreCommands.has(command): return coreCommands[command]
	elif defCommands.has(command): return defCommands[command]
	else: return null

## Remove the [param key] and its value from [param dict]
#func remove(key, dict) -> Status:
	#if variables.has(key): 
		#variables.erase(key)
		#return Status.ok(null, "Removed '%s' from %s" % [key, dict])
	#else:
		#return Status.error("Key not found in %s: '%s'" % [dict, key])

## List contents of [param dict]
func _list(dict: Dictionary) -> Status:
	var list := []
	var msg := ""
	for key in dict.keys():
		list.append(key)
		msg += "%s: %s" % [key, dict[key]]
	list.sort()
	return Status.ok(list, msg)

func listAllCommands() -> Status:
	var list := "\nCore Commands:\n"
	list += listCommands(coreCommands).value
	list += "\nDef Commands:\n"
	list += listCommands(defCommands).value
	return Status.ok(list, list)

func listCommands(commands: Dictionary) -> Status:
	var list := "\n--\n"
	var keys = commands.keys()
	keys.sort()
	for command in keys:
		list += "%s\n" % [command]
	return Status.ok(list)

func listActors() -> Status:
	var actorsList := []
	var actors: Array[Node] = getAllActors().value
	#Log.info("List of actors (%s)" % [len(actors)])
	for actor in actors:
		var actorName := actor.get_name()
		var anim: String = actor.get_node("Animation").get_animation()
		actorsList.append("%s (%s)" % [actorName, anim])
		#Log.info(actorsList.back())
	actorsList.sort()
	var msg := "List of actors (%s)\n" % [len(actors)]
	for name in actorsList:
		msg += "%s\n" % [name]
	return Status.ok(actorsList, msg)

func listAnimations() -> Status:
	var animationNames = animationsLibrary.get_animation_names()
	var msg := "List of animations (%s):\n" % [len(animationNames)]
	for animName in animationNames:
		var frameCount = animationsLibrary.get_frame_count(animName)
		msg += "%s (%s)\n" % [animName, frameCount]
	return Status.ok(animationNames, msg)

func listAnimationAssets() -> Status:
	var dir := DirAccess.open(animationAssetsPath)
	var assetNames := []
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			assetNames.append(filename)
			filename = dir.get_next()
	assetNames.sort()
	var msg := "Assets at '%s':\n" % [ProjectSettings.globalize_path(animationAssetsPath)]
	for assetName in assetNames:
		msg += "%s\n" % [assetName]
	return Status.ok(assetNames, msg)

func setAssetsPath(path: String) -> Status:
	if path == "null": return Status.ok(animationAssetsPath, animationAssetsPath)
	animationAssetsPath = path;
	return Status.ok()

func unloadAnimationAsset(assetName: String) -> Status:
	if not animationsLibrary.has_animation(assetName):
		return Status.error("Animation not loaded: %s" % [assetName])
	animationsLibrary.remove_animation(assetName)
	return Status.ok(true, "Animation removed from memory: %s" % [assetName])

func loadAnimationAsset(assetName: String) -> Status:
	var result : Status
	var path := animationAssetsPath.path_join(assetName)
	var dir := DirAccess.open(animationAssetsPath)
	var assets := assetHelpers.getAssetFilesMatching(animationAssetsPath, assetName)
	if not assets.sprites.is_empty():
		result = assetHelpers.loadSprites(animationsLibrary, assets.sprites)
		if result.isError(): return Status.error("Image asset not loaded: %s" % [path])
	if not assets.seqs.is_empty():
		for seqPath in assets.seqs:
			result = loadImageSequence(seqPath)
			if result.isError(): return result if result.msg else Status.error("Image sequence assets not loaded: %s" % [path])
	if assets.sprites.is_empty() and assets.seqs.is_empty():
		return Status.error("Asset not found: %s" % [path])
	return result

func loadImageSequence(path: String) -> Status:
	var filenames := DirAccess.get_files_at(path)
	var animName := path.get_basename().split("/")[-1]
	var names = animationsLibrary.get_animation_names()
	if animName != "default" and animationsLibrary.has_animation(animName):
		return Status.error("Animation already loaded: '%s'" % [animName])
	animationsLibrary.add_animation(animName)
	addImageFiles(path, animName, filenames)
	return Status.ok(true, "Loaded %s frames: %s" % [animationsLibrary.get_frame_count(animName), animName])

## Adds image files to Animations Library
func addImageFiles(path: String, animName: String, filenames: PackedStringArray):
	for file in filenames:
		if file.ends_with(".png"):
#			Log.debug("Loading img to '%s': %s" % [animName, path.path_join(file)])
			var texture := assetHelpers.loadImage(path.path_join(file))
			animationsLibrary.add_frame(animName, texture)

func getAllActors() -> Status:
	return Status.ok(actorsNode.get_children(true))

## Returns an actor by exact name match (see [method getActors])
func getActor(actorName: String) -> Status:
	var actor = actorsNode.find_child(actorName, true, false)
	if actor == null: return Status.error("Actor not found: %s" % [actorName])
	return Status.ok(actor)

## Returns an array of children matching the name pattern
func getActors(namePattern: String) -> Status:
	var actors = actorsNode.find_children(namePattern, "Node", true, false)
	if actors == null or len(actors) == 0: return Status.error("No actors found: %s" % [namePattern])
	return Status.ok(actors)

func createActor(actorName: String, anim: String) -> Status:
	var actor: Variant
	var msg: String
	var result = getActor(actorName)
#	Log.debug(result.msg)
	if result.value != null:
		actor = getActor(actorName).value
		msg = "Actor already exists: %s\n" % [actor]
		msg += "Setting new animation: %s" % [anim]
	else:
		actor = metanode.instantiate()
		msg = "Created new actor '%s': %s" % [actorName, anim]
#	Log.debug(msg)
	actor.set_name(actorName)
	result = createAnimationActor(actor, anim)
	actorsNode.add_child(actor)
	center(actorName)
	
	# Need to set an owner so it appears in the SceneTree and can be found using
	# Node.finde_child(pattern) -- see Node docs
	actor.set_owner(actorsNode)
	
	if result.isError():
		result = setActorText([actorName, actorName])
		return result
	
	actor.get_node("Animation").animation_finished.connect(_on_animation_finished)
	return Status.ok(actor, msg)

func _on_animation_finished():
	#Log.debug("animation finished")
	pass

func createAnimationActor(actor: Node, anim: String) -> Status:
	# FIX: this may not be necessary. Maybe we can call setAnimationProperty("animation", "anim")
	if not animationsLibrary.has_animation(anim):
		return Status.error("Animation not found: %s" % [anim])
	var animationNode = actor.get_node("Animation")
	animationNode.set_sprite_frames(animationsLibrary)
	animationNode.play(anim)
	animationNode.get_sprite_frames().set_animation_speed(anim, 12)
	return Status.ok()

func removeActor(actorName: String) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		actorsNode.remove_child(actor)
	return Status.ok()

func setActorAnimation(actorName, animation) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	if not animationsLibrary.has_animation(animation): return Status.error("Animation not found: %s" % [animation])
	for actor in result.value:
		actor.get_node("Animation").play(animation)
	# return Status.ok(true, "Set animation for '%s': %s" % [actorName, animation])
	return Status.ok()

func loopAnimation(actorName: String) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		var animationNode = actor.get_node("Animation")
		animationNode.get_sprite_frames().set_animation_loop(animationNode.get_animation(), false)
	
	return Status.ok()

## Converts a command to GDScript property setter syntax.
## For example: [code]/visible/ratio[/code] is converted to [code]set_visible_ratio[/code]
func _cmdToGdScriptSetter(property: String) -> String:
	property = property.substr(1) if property.begins_with("/") or property.begins_with("_") else property
	return "set_%s" % [property.replace("/", "_")]

## Converts a command to GDScript property syntax.
## For example: [code]/visible/ratio[/code] is converted to [code]visible_ratio[/code]
func _cmdToGdScript(cmd: String) -> String:
	if cmd.begins_with("/") or cmd.begins_with("_"):
		cmd = cmd.substr(1)
	else:
		cmd
	return cmd.replace("/", "_")

func setActorProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var property = _cmdToGdScript(args[0])	
	for actor in result.value:
		result = getArgsAsPropertyType(actor, property, args.slice(2))
		if result.isError(): return result
		property = result.value.propertyName
		var value = result.value.propertyValue
		actor.set(property, value)
	return Status.ok()

func setActorRelativeProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var property = _cmdToGdScript(args[0])
	args = args.slice(2) 
	for actor in result.value:
		result = getArgsAsPropertyType(actor, property, args)
		if result.isError(): return result
		var propertyValue = getProperty(actor, property).value
		var newValue = propertyValue + result.value.propertyValue
		actor.set(property, newValue)
	return Status.ok()

func callActorMethod(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var method = _cmdToGdScript(args[0])
	args = args.slice(2)
	for actor in result.value:
		result = getObjectMethod(actor, method)
		if result.isError(): return result
		
		var methodArgs = result.value.args
		if methodArgs.size() < 1: 
			actor.call(method)
			return Status.ok()
		
		# FIX: implement methods with mulpile arguments
		# currently it only accepts 1 argument
		# should probably move it to a dedicated method or function
		match methodArgs[0].type:
			TYPE_INT: methodArgs = args[0] as int
			TYPE_FLOAT: methodArgs = args[0] as float
			TYPE_BOOL: methodArgs = args[0] as bool
			TYPE_VECTOR2: methodArgs = Vector2(args[0] as float, args[1] as float)
			TYPE_VECTOR3: methodArgs = Vector3(args[0] as float, args[1] as float, args[2] as float)
			TYPE_VECTOR4: methodArgs = Vector4(args[0] as float, args[1] as float, args[2] as float, args[3] as float)
			TYPE_COLOR: methodArgs = Color(args[0] as float, args[1] as float, args[2] as float)
			_: methodArgs = " ".join(args)
		actor.call(method, methodArgs)
	return Status.ok()

func getObjectMethod(obj: Object, methodName: String) -> Status:
	var methods = obj.get_method_list()
	for method in obj.get_method_list():
		if method.name == methodName: 
			return Status.ok(method)
	return Status.error("Method not found: %s(%s):%s" % [obj.name, obj.get_class(), methodName])

## Converts and returns an array of anything into the correct types for the given method
func argsToMethodTypes(object: Object, methodName: String, args: Array) -> Array:
	var method = getObjectMethod(object, methodName).value
	var types = []
	for i in method.args.size():
		match method.args[i].type:
			TYPE_INT: types.append(args[i] as int)
			TYPE_FLOAT: types.append(args[i] as float)
			TYPE_BOOL: types.append(args[i] as int as bool)
			_: types.append(args[i])
	return types

func setAnimationProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var property = _cmdToGdScript(args[0])	
	for actor in result.value:
		var animation = actor.get_node("Animation")
		var propertyArgs = args.slice(2)
		result = getArgsAsPropertyType(animation, property, propertyArgs)
		if result.isError(): return result
		property = result.value.propertyName
		var value = result.value.propertyValue
		var calledProperty = _cmdToGdScriptSetter(property)
		animation.call(calledProperty, value)
	return Status.ok()


func _setTextProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var property = _cmdToGdScript(args[0])
	for actor in result.value:
		var actorLabel = actor.get_node("RichTextLabel") 
		#.get_theme().get_default_font()
		var propertyArgs = args.slice(2)
		result = getArgsAsPropertyType(actorLabel, property, propertyArgs)
		if result.isError(): return result
		property = result.value.propertyName
		var value = result.value.propertyValue
		var calledProperty = _cmdToGdScriptSetter(property)
		actorLabel.call(calledProperty, value)
	return Status.ok()

func _setEditorProperty(args: Array) -> Status:
	var property = _cmdToGdScript(args[0])
	if property.begins_with("_"): property = property.substr(1)
	var method = "add_theme_%s_override" % [property]
	var valueType := typeof(editor.call("get_theme_%s" % [property], property))
	var value: Variant
	match valueType:
		TYPE_INT: value = args[1] as int
		TYPE_FLOAT: value = args[1] as float
		TYPE_COLOR: value = Color(args[1] as float, args[2] as float, args[3] as float)
		TYPE_STRING: value = args[1] as String
		_: # try TYPE_OBJECT
			Log.warn("I don't know what to do with this: %s" % [args[1]])
			return
	editor.call(method, property, value)
	return Status.ok()

func setAnimationFramesProperty(property, args) -> Status:
	return callAnimationFramesMethod(["/set" + property] + [args])

func toggleProperty(property, object) -> Status:
	if property.begins_with("/"): property = property.substr(1)
	property = property.replace("/", "_")
	var value = object.get(property)
	object.set(property, not(value))
#	Log.verbose("Toggle %s.%s: %s -> %s" % [object.name, property, value, object.get(property)])
	return Status.ok(object.get(property))

func toggleActorProperty(property, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		toggleProperty(property, actor)
	return Status.ok()

func toggleAnimationProperty(property, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		var animation = actor.get_node("Animation")
		toggleProperty(property, animation)
	return Status.ok()

func arrayToVector(input: Array) -> Variant:
	for i in len(input):
		input[i] = float(input[i])
	match len(input):
		2: return Vector2(input[0], input[1])
		3: return Vector3(input[0], input[1], input[2])
		4: return Vector4(input[0], input[1], input[2], input[3])
		_: return null

func callAnimationMethod(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var method = _cmdToGdScript(args[0].substr(1))
	args = args.slice(2)
	for actor in result.value:
		var animation = actor.get_node("Animation")
		if len(args) == 0:
			result = animation.call(method)
		else:
			result = animation.callv(method, args)
	#return Status.ok(result, "Called %s.%s.%s(%s): %s" % [actor.get_name(), animation.get_animation(), method, args, result])
	return Status.ok()

func callAnimationFramesMethod(args) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var method = _cmdToGdScript(args[0].substr(1))
	args = args.slice(2)
	for actor in result.value:
		var animation = actor.get_node("Animation")
		var frames = animation.get_sprite_frames()
		# replace first argument with animation name
		# most of the SpriteFrames methods need the animation name as first argument
		args.insert(0, animation.get_animation())
		args = argsToMethodTypes(frames, method, args)
		result = frames.callv(method, args)
	return Status.ok()

# Note that the red/green/blue arguments can't have static typing,
# because the Callable.callv() call will fail (Array members can't
# have types) if the args are Strings or ints and thus need conversion
# to float. See https://github.com/godotengine/godot/issues/62838
func colorActor(actorName: String, red, green, blue) -> Status:
	var result := getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		var animation := actor.get_node("Animation") as AnimatedSprite2D
		var rgb := Vector3(red as float, green as float, blue as float)
		setImageShaderUniform(animation, "uAddColor", rgb)
		setTextColor(actorName, red, green, blue)
	return Status.ok()

func setActorOpacity(actorName: String, alpha: Variant) -> Status:
	var result := getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		var animation := actor.get_node("Animation") as AnimatedSprite2D
		setImageShaderUniform(animation, "uAlpha", alpha as float)
	return result

static func setImageShaderUniform(image: AnimatedSprite2D, uName: StringName, uValue: Variant) -> void:
	image.material.set_shader_parameter(uName, uValue)


func listRoutines() -> Status:
	var routineList := []
	for child in routinesNode.get_children():
		routineList.append("%s(%s/%s): %s" % [child.name, child.iteration, child.repeats, child.command])
	routineList.sort()
	for routine in routineList:
		# FIX: send OSC message
		Log.info(routine)
	return Status.ok(true)

func addRoutine(args: Array) -> Status:
	var name: String = args[0]
	var repeats := args[1] as int
	var interval: float = args[2] as float
	var command: Array = args.slice(3)
	var routine: Routine
	if routinesNode.has_node(name):
		routine = routinesNode.get_node(name)
		routine.reset()
	else:
		routine = Routine.instantiate()
		routine.name = name
		routinesNode.add_child(routine)
		routine_added.emit(name) # see Main._on_routine_added

	routine.repeats = repeats
	routine.set_wait_time(interval)
	routine.command = command
	routine.start()
	if Log.getLevel() == Log.LOG_LEVEL_VERBOSE:
		return Status.ok(true, "New routine '%s' (%s times every %s): %s" % [name, repeats, interval, command])
	return Status.ok()

func freeRoutine(name: String) -> Status:
	for routine in routinesNode.find_children(name, "", true, false):
		routine.stop()
		routinesNode.remove_child(routine)
		routine.queue_free()
	return Status.ok(true, "Routine removed: %s" % [name])

func startRoutine(name: String) -> Status:
	routinesNode.get_node(name).start()
	return Status.ok(true)

func stopRoutine(name: String) -> Status:
	routinesNode.get_node(name).stop()
	return Status.ok(true)

func finishedRoutine(args: Array) -> Status:
	var routine = routinesNode.get_node(args[0])
	if routine == null:
		return Status.error("Routine not found: %s" % [args[0]])
	routine.lastCommand = args.slice(1)
	return Status.ok(routine.name, "Set last command for routine: %s" % [routine.name])

func wait(args: Array) -> Status:
	var time := args[0] as float
	return addRoutine(["wait_%s" % [Time.get_ticks_msec()], 1, time] + args.slice(1))

func listStates() -> Status:
	var machines := stateMachines.keys()
	machines.sort()
	var msg := "State machines:\n"
	for machine in machines:
		msg += "%s(%s): %s" % [machine, stateMachines[machine].status(), stateMachines[machine].list()]
	return Status.ok(machines, msg)

func addStateMachine(name: String):
	var machine = StateMachine.new()
	machine.state_changed.connect(stateChangedCallback)
	machine.name = name
	stateMachines[name] = machine

func defineState(name: String, entry: String, exit: String) -> Status:
	StateMachine.defineState(name, entry, exit)
	return Status.ok()

func addState(args: Array) -> Status:
	var machineName = args[0]
	if not(stateMachines.has(machineName)): addStateMachine(machineName)
	stateMachines[machineName].addState(args[1], args.slice(2))
	return Status.ok(stateMachines[machineName])

func freeState(machine: String, state: String) -> Status:
	if stateMachines.has(machine):
		stateMachines[machine].removeState(state)
		return Status.ok(true, "%s -> Removed state: %s" % [machine, state])
	return Status.error("Machine not found: %s" % [machine])

func nextState(machine: String) -> Status:
	if stateMachines.has(machine):
		stateMachines[machine].next()
		return Status.ok(true, "%s -> Next state: %s" % [machine, stateMachines[machine].status()])
	return Status.error("Machine not found: %s" % [machine])

func center(actorName: String) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		actor.set_position(Vector2(0.5,0.5) * get_parent().get_viewport_rect().size)
	return Status.ok()

func parentActor(childName: String, parentName: String) -> Status:
	var result = getActor(parentName)
	if result.isError(): return result
	var parent = result.value
	result = getActors(childName)
	if result.isError(): return result
	for child in result.value:
		var oldParent = child.get_parent()
		oldParent.remove_child(child)
		parent.add_child(child)
		# preserve children transforms
		child.transform = parent.transform.affine_inverse() * child.transform
		Log.verbose("%s emmancipated from %s" % [child.name, oldParent.name])
		Log.verbose("%s is child of %s" % [child.name, parent.name])
	return Status.ok()

func parentActorFree(childName: String) -> Status:
	var result = getActors(childName)
	if result.isError(): return result
	for child in result.value:
		var parent = child.get_parent()
		parent.remove_child(child)
		actorsNode.add_child(child)
		# preserve children transforms
		child.transform = parent.transform * child.transform
	return Status.ok()

func listChildren(parentName: String) -> Status:
	var result = getActor(parentName)
	if result.isError(): return result
	var parent = result.value
	var children := []
	for child in parent.get_children():
		children.append(child.name)
	children.sort()
	return Status.ok(children, "%s" % [children])

func setInFrontOfActor(args: Array) -> Status:
	var result = getActor(args[0])
	var targetResult = getActors(args[1])
	if result.isError(): return result
	if targetResult.isError(): return targetResult
	var actor = result.value
	for target in targetResult.value:
		actorsNode.move_child(actor, target.get_index()+1)
	return Status.ok()

func setBehindActor(args: Array) -> Status:
	var result = getActor(args[0])
	var targetResult = getActors(args[1])
	if result.isError(): return result
	if targetResult.isError(): return targetResult
	var actor = result.value
	for target in targetResult.value:
		actorsNode.move_child(actor, max(0, target.get_index()-1))
	return Status.ok()

func setTopActor(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actorsNode.move_child(actor, actorsNode.get_child_count())
	return Status.ok(true)

func setBottomActor(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actorsNode.move_child(actor, 0)
	return Status.ok()

func randCmdValue(args: Array) -> Status:
	var command = args[0]
	var result = getActors(args[1])
	if result.isError(): return result
	for actor in result.value:
		var value = randf_range(float(args[2]), float(args[3]))
		commandManager.evalCommand([command, actor.name, value], "CommandInterface")
	return Status.ok(true)

func tweenActorProperty(args: Array) -> Status:
	var result = getActors(args[3])
	if result.isError(): return result
	var dur = args[0] as float
	var transitionType = getTransitionType(args[1])
	var property = args[2].replace("/", "_")
	if property.begins_with("_"): property = property.substr(1)
	var propertyArgs = args.slice(4)
	for actor in result.value:
		var tween = create_tween()
		result = getArgsAsPropertyType(actor, property, propertyArgs)
		if result.isError(): return result
		var node = result.value.node
		property = result.value.propertyName
		var value = result.value.propertyValue
		tween.set_trans(transitionType)
		tween.tween_property(node, property, value, dur)
	return Status.ok()

func getTransitionType(transition: String) -> int:
	match transition:
		"linear": return Tween.TRANS_LINEAR
		"sine": return Tween.TRANS_SINE
		"quint": return Tween.TRANS_QUINT
		"quart": return Tween.TRANS_QUART
		"quad": return Tween.TRANS_QUAD
		"expo": return Tween.TRANS_EXPO
		"elastic": return Tween.TRANS_ELASTIC
		"cubic": return Tween.TRANS_CUBIC
		"circ": return Tween.TRANS_CIRC
		"bounce": return Tween.TRANS_BOUNCE
		"back": return Tween.TRANS_BACK
		"spring": return Tween.TRANS_SPRING
	return -1

## converts the array of arguments given by the command to the appropriate 
## type depending on the property
func getArgsAsPropertyType(node: Object, propertyName: String, args: Array) -> Status:
	var property = node.get(propertyName)
	var propertyType = typeof(property)
	var value: Variant
	var axisName = getAxis(propertyName)
	if axisName: 
		axisName = axisName.value
		propertyType = TYPE_NIL
		propertyName = propertyName.split("_")[0]
		property = node.get(propertyName)
	if property == null: return Status.error("Property not found: %s.%s" % [node, propertyName])
	match propertyType:
		TYPE_VECTOR2: value = Vector2(args[0] as float, args[1] as float)
		TYPE_VECTOR3: value = Vector3(args[0] as float, args[1] as float, args[2] as float)
		TYPE_VECTOR4: value = Vector4(args[0] as float, args[1] as float, args[2] as float, args[3] as float)
		TYPE_COLOR: value = Color(args[0] as float, args[1] as float, args[2] as float)
		TYPE_STRING, TYPE_STRING_NAME: value = " ".join(args)
		TYPE_FLOAT: value = args[0] as float
		TYPE_INT: value = args[0] as float
		_: 
			# if it's none of the above, probably is an axis of a vector or a color 
			# we take the whole vector and assign the command value to the 
			# according axis keeping the rest intact
			match axisName:
				"x": property.x = args[0] as float
				"y": property.y = args[0] as float
				"z": property.z = args[0] as float
				"r": property.r = args[0] as float
				"g": property.g = args[0] as float
				"b": property.b = args[0] as float
				"a": property.a = args[0] as float
			# convert back to vector with the new value
			value = property
	return Status.ok({"node": node, "propertyName": propertyName, "propertyValue": value})

func getAxis(propertyName: String) -> Status:
	var regex = RegEx.new()
	regex.compile("[_\\/]{1}\\w$")
	var result = regex.search(propertyName)
	if result == null: return result
	return Status.ok(result.get_string().substr(1))
	

func getProperty(obj: Object, propertyName: String) -> Status:
	propertyName = _cmdToGdScript(propertyName)
	var value = obj.get(propertyName)
	if value == null: 
		return Status.error("Property not found: %s(%s):%s" % [obj.name, obj.get_class(), propertyName])
	return Status.ok(value)

func setActorText(nameAndMsg: Array) -> Status:
	var actorName = nameAndMsg[0]
	var msg = " ".join(nameAndMsg.slice(1))
	var result = getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		var label = actor.get_node("RichTextLabel")
		label.set_text(msg)
	return Status.ok()

func setTextProperty(textProperty: String, args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	var property = textProperty.replace("/text/", "set/")
	return callTextMethod(property, args)

func callTextMethod(textProperty: String, args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	var method = textProperty.replace("/text/", "").replace("/", "_")
	var gdArgs: Variant
	match args.slice(1).size():
		1: gdArgs = args[1] as float
		2: gdArgs = Vector2(args[1] as float, args[2] as float)
		3: gdArgs = Color(args[1] as float, args[2] as float, args[3] as float)
	for actor in result.value:
		actor.get_node("RichTextLabel").call(method, gdArgs)
	return Status.ok()

## see colorActor comments about non-typing the arguments
func setTextColor(actorName: String, red, green, blue) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	var color = Color(red as float, green as float, blue as float)
	for actor in result.value:
		var label = actor.get_node("RichTextLabel")
		label.set_modulate(color)
	return Status.ok()

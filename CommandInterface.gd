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

## A dictionary used to store variables accessible from OSC messages.
## They are stored in a file, and loaded into this dictionary.
var variables: Dictionary:
	set(value): variables = value
	get: return variables
## Core commands map.[br]
var coreCommands: Dictionary = {
	"/help": CommandDescription.new(getHelp, "cmd:s", "Get documentation about CMD."),
#	"/test": CommandDescription.new(getActor, "", "This is just a test"), ## used to test random stuff
	"/set": CommandDescription.new(setVar, "", "TODO"),
	"/get": CommandDescription.new(getVar, "", "TODO"),
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
	# actors
	"/property": CommandDescription.new(setActorProperty, "property:s actor:s value:...", "Generic command to set the VALUE to any PROPERTY of an ACTOR.", Flags.asArray(true)),
	
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
	"/editor/append": CommandDescription.new(appendTextToEditor, "text:s", "Append TEXT to the last line of the editor.", Flags.asArray(true)),
	"/editor/clear": CommandDescription.new(clearEditor, "", "Delete all text from the editor."),
	"/editor/open": CommandDescription.new(openTextFile, "", "Open a file dialog and append the selected file contents at the end."),
	"/editor/save": CommandDescription.new(saveTextFile, "", "Save the code using a file dialog."),
	"/editor/open/from": CommandDescription.new(openTextFileFrom, "path:s", "Load code from PATH and append it to the end."),
	"/editor/save/to": CommandDescription.new(saveTextFileTo, "path:s", "Save the code to PATH."),
	# post
	"/post": CommandDescription.new(post, "msg:s", "Print MSG in the post window.", Flags.asArray(false)),
	"/post/toggle": CommandDescription.new(togglePost, "", "Toggle post window visibility.", Flags.asArray(false)),
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
	"/relative": CommandDescription.new(setRelativeProperty, "", "TODO", Flags.asArray(false)),
	"/rand": CommandDescription.new(randCmdValue, "cmd:s actor:s min:f max:f", "Send a CMD to an ACTOR with a random value between MIN and MAX. If a wildcard is used, e.g. `bl*`, all ACTORs with with a name that begins with `bl` will get a different value. *WARNING: This only works with single-value commands.*", Flags.asArray(true)),
	"/tween": CommandDescription.new(tweenActorProperty, "dur:f transition:s property:s actor:s value:f", "Tweens a PROPERTY of an ACTOR between the current value and final VALUE in a span of time equal to DURation, in seconds. The TRANSITION must be one of: linear, sine, quint, quart, quad, expo, elastic, cubic, circ, bounce, back and spring.", Flags.asArray(true)),
	# Node
	"/animation": CommandDescription.new(setAnimationProperty, "actor:s animation:s", "Change the ACTOR's ANIMATION.", Flags.gdScript()),
	"/play": CommandDescription.new(callAnimationMethod, "actor:s", "Start playing ACTOR's image sequence.", Flags.gdScript()),
	"/play/backwards": CommandDescription.new(callAnimationMethod, "actor:s", "Play ACTOR's animation backwards.", Flags.gdScript()),
	"/animation/loop": CommandDescription.new(setAnimationFramesProperty, "actor:s loop:b", "Set the ACTOR's animation to either LOOP or not.", Flags.gdScript()),
	"/stop": CommandDescription.new(callAnimationMethod, "actor:s", "Stop playing the ACTOR's animation.", Flags.gdScript()),
	"/frame": CommandDescription.new(setAnimationProperty, "actor:s frame:i", "Set the ACTOR's current FRAME.", Flags.gdScript()),
	#"/frame/progress": CommandDescription.new(setAnimationProperty, "", "", Flags.gdScript()),
	"/speed/scale": CommandDescription.new(setAnimationProperty, "actor:s speed:f", "Set the ACTOR's animation SPEED (1 = normal speed, 2 = 2 x speed).", Flags.gdScript()),
	"/start/frame": CommandDescription.new(setAnimationProperty, "actor:s frame:i", "Set the first FRAME of the loop in ACTOR's animation. Defaults to 0.", Flags.gdScript()),
	"/end/frame": CommandDescription.new(setAnimationProperty, "actor:s frame:i", "Set the last FRAME of the loop in ACTOR's animation. Defaults to number of frames of the animation.", Flags.gdScript()),
	"/flip/v": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip/ ACTOR vertically.", Flags.gdScript()),
	"/flip/h": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip ACTOR horizontally.", Flags.gdScript()),
	"/visible": CommandDescription.new(toggleActorProperty, "actor:s visibility:b", "Set ACTOR's VISIBILITY to either true or false.", Flags.gdScript()),
	"/hide": CommandDescription.new(callActorMethod, "actor:s", "Show ACTOR (set visibility to true).", Flags.gdScript()),
	"/show": CommandDescription.new(callActorMethod, "actor:s", "Hide ACTOR (set visibility to false).", Flags.gdScript()),
	"/offset": CommandDescription.new(setAnimationPropertyWithVector, "actor:s x:i y:i", "Set the ACTOR's animation drawing offset in pixels.", Flags.gdScript()),
	"/offset/x": CommandDescription.new(setAnimationPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's animation drawing offset on the X axis.", Flags.gdScript()),
	"/offset/y": CommandDescription.new(setAnimationPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's animation drawing offset on the Y axis.", Flags.gdScript()),
	"/parent": CommandDescription.new(parentActor, "child:s parent:s", "Set an actor to be the CHILD of another PARENT actor."),
	"/parent/free": CommandDescription.new(parentActorFree, "child:s", "Free the CHILD actor from it's parent."),
	"/children/list": CommandDescription.new(listChildren, "parent:s", "List all PARENT's children actors."),
	"/front": CommandDescription.new(setInFrontOfActor, "actor:s target:s", "Draw the ACTOR in front of the TARGET.", Flags.asArray(false)),
	"/behind": CommandDescription.new(setBehindActor, "actor:s target:s", "Draw the ACTOR behind the TARGET.", Flags.asArray(false)),
	"/top": CommandDescription.new(setTopActor, "actor:s", "Draw the ACTOR on top of everything else.", Flags.asArray(false)),
	"/bottom": CommandDescription.new(setBottomActor, "actor:s", "Draw the ACTOR behind everything else.", Flags.asArray(false)),
	"/size": CommandDescription.new(size, "actor:s size:f", "Set the ACTOR SIZE on both axes (same value for with and height).", Flags.asArray(false)),
	"/size/x": CommandDescription.new(sizeX, "actor:s size:f", "Set the ACTOR SIZE on the X axis.", Flags.asArray(false)),
	"/size/y": CommandDescription.new(sizeY, "actor:s size:f", "Set the ACTOR SIZE on the Y axis.", Flags.asArray(false)),
	"/scale": CommandDescription.new(scale, "actor:s multiply:f", "MULTIPLY the ACTOR's size (use values < 1.0 to devide).", Flags.asArray(false)),
	"/scale/x": CommandDescription.new(scaleX, "actor:s multiply:f", "MULTIPLY the ACTOR's size on the X axis (use values < 1.0 to devide).", Flags.asArray(false)),
	"/scale/y": CommandDescription.new(scaleY, "actor:s multiply:f", "MULTIPLY the ACTOR's size on the Y axis (use values < 1.0 to devide).", Flags.asArray(false)),
	"/apply/scale": CommandDescription.new(callActorMethodWithVector, "", "", Flags.gdScript()),
	"/set/position": CommandDescription.new(callActorMethodWithVector, "", "", Flags.gdScript()),
	#"/position": CommandDescription.new(setActorPropertyWithVector, "actor:s x:i y:i", "Set the ACTOR's absolute position in pixels.", Flags.gdScript()),
	#"/position/x": CommandDescription.new(setActorPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's absolute position in PIXELS on the X axis.", Flags.gdScript()),
	#"/position/y": CommandDescription.new(setActorPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's absolute position in PIXELS on the Y axis.", Flags.gdScript()),
	"/center": CommandDescription.new(center, "actor:s", "Set the ACTOR to the center of the screen."),
	"/move": CommandDescription.new(move, "actor:s xcoord:f ycoord:f", "Move ACTOR to XCOORD - YCOORD relative to the current position.", Flags.asArray(false)),
	"/move/x": CommandDescription.new(moveX, "actor:s xcoord:f", "Move ACTOR to XCOORD relative to the current position.", Flags.asArray(false)),
	"/move/y": CommandDescription.new(moveY, "actor:s ycoord:f", "Move ACTOR to YCOORD relative to the current position.", Flags.asArray(false)),
	#"/rotation/degrees": CommandDescription.new(setActorProperty, "actor:s degrees:f", "Set the angle of the ACTOR in DEGREES.", Flags.gdScript()),
	"/rotate": CommandDescription.new(rotate, "actor:s degrees:f", "Rotate ACTOR a number of DEGREES relative to the current rotation.", Flags.asArray(false)),
	# text
	"/type": CommandDescription.new(setActorText, "actor:s text:s", "Add TEXT to an ACTOR.", Flags.asArray(true)),
	"/text/visible/ratio": CommandDescription.new(setTextProperty, "actor:s ratio:s", "Set how much text is visible.", Flags.gdScript()),
	"/text/color": CommandDescription.new(setTextColor, "actor:s r:f g:f b:f", "Add TEXT to an ACTOR."),
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
	var contents = file.get_as_text()
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
	var msg = " ".join(args)
	editor.set_text("%s\n%s" % [editor.get_text(), msg])
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
	postWindow.set_text("%s\n%s" % [postWindow.get_text(), " ".join(PackedStringArray(args))])
	postWindow.set_caret_line(postWindow.get_line_count())
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
	# this might change in the future if we convert /defs into CommandDescriptions.
	# as for now it dumps the def's subcommands
	if typeof(cmdDesc) == TYPE_DICTIONARY: 
		var msg := "[HELP] custom definition\n/def %s" % [cmd]
		for key in cmdDesc.variables.keys():
			msg += " %s" % [key]
		msg += "\n"
		for subcmd in cmdDesc.subcommands:
			msg += "\t%s\n" % [" ".join(subcmd)]
		return Status.ok(cmdDesc, msg)
	
	var msg = "[HELP] %s %s\n\n%s" % [cmd, cmdDesc.argsDescription, cmdDesc.description]
	return Status.ok(cmdDesc, msg)

### Read a file with a [param filename] and return its OSC constent in a string
#func loadFile(filename: String) -> Status:
	#Log.verbose("Reading: %s" % [filename])
	#var file = FileAccess.open(filename, FileAccess.READ)
	#var content = file.get_as_text()
	#if content == null: return Status.error()
	#return Status.ok("Read file successful: %s" % filename, content)

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

## Get a variable value by [param varName].
##
## This method returns a single value. If by any reason the value holds
## more than one, it will return only the first one.
func getVar(varName: String) -> Status:
	var value = variables[varName][0] if variables.has(varName) else null
#	Log.debug("Looking for var '%s': %s" % [varName, value])
	if value == null: return Status.error("Variable '%s' not found return: %s" % [varName, value])
	return Status.ok(value, "Variable '%s': %s" % [varName, value])

## Set and store new [param value] in a variable with a [param varName]
## Returns the value stored in the variable
func setVar(varName: String, value: Variant) -> Status:
	variables[varName] = [value]
	if Log.getLevel() == Log.LOG_LEVEL_VERBOSE:
		_list(variables)
	return Status.ok(variables[varName][0])

## Returns the value of a command to be executed.
## If no description is found, it returns [code]null[/code].
func getCommandDescription(command: String) -> Variant:
	if coreCommands.has(command): return coreCommands[command]
	elif defCommands.has(command): return defCommands[command]
	else: return null

## Remove the [param key] and its value from [param dict]
func remove(key, dict) -> Status:
	if variables.has(key): 
		variables.erase(key)
		return Status.ok(null, "Removed '%s' from %s" % [key, dict])
	else:
		return Status.error("Key not found in %s: '%s'" % [dict, key])

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
	print("animation finished")

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

## Sets any Vector [param property] of any node. 
## [param args[1..]] are the vector values (between 2 and 4). If only 1 value is passed, it will set the same value on all axes.
func setNodePropertyWithVector(node, property, args) -> Status:
	property = property.substr(1) if property.begins_with("/") else property
	property = property.replace("/", "_")
	var setProperty = "set_%s" % [property]
	var vec = node.call("get_%s" % [property])
	if len(args) < 2:
		match typeof(vec):
			TYPE_VECTOR2: args = [args[0], args[0]]
			TYPE_VECTOR3: args = [args[0], args[0], args[0]]
			TYPE_VECTOR4: args = [args[0], args[0], args[0], args[0]]
	return callMethodWithVector(node, setProperty, args)

func setActorPropertyWithVector(property, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		setNodePropertyWithVector(actor, property, args.slice(1))
	return Status.ok()

func setAnimationPropertyWithVector(property, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		var animation = actor.get_node("Animation")
		setNodePropertyWithVector(animation, property, args.slice(1))
	return Status.ok()

## Sets the value for the N axis of any Vector [param property] (position, scale, ...) of any actor.
## For example: /position/x would set the [method actor.get_position().x] value.
## [param args\[0\]] is the actor name.
## [param args[1]] is the value.
func setNodePropertyWithVectorN(node, property, value) -> Status:
	var vec = node.call("get_" + property.get_slice("/", 1).to_snake_case())
	var axis = property.get_slice("/", 2)
	value = float(value)
	match axis:
		"x": vec.x = value
		"y": vec.y = value
		"z": vec.z = value
		"r": vec.r = value
		"g": vec.g = value
		"b": vec.b = value
		"a": vec.a = value
	node.call("set_" + property.get_slice("/", 1).to_snake_case(), vec)
#	Log.debug("Set %s %s -- %s: %s" % [property, actor.get_position(), vec, value])
	return Status.ok("Set %s.%s: %s" % [vec, axis, value])

func setActorPropertyWithVectorN(actor, args: Array) -> Status:
	#var result = getActors(args[1])
	#if result.isError(): return result
	#var property = args[0]
	#for actor in result.value:
		#var value = getArgsAsPropertyType(actor, property, args.slice(2))
		#setNodePropertyWithVectorN(actor, property, args[1])
	return Status.error("Broken when imlementing new setActorProperty")
	return Status.ok()

func setAnimationPropertyWithVectorN(property, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		var animation = actor.get_node("Animation")
		setNodePropertyWithVectorN(animation, property, args[1])
	return Status.ok()

## Converts a command to GDScript property setter syntax.
## For example: [code]/visible/ratio[/code] is converted to [code]set_visible_ratio[/code]
func _cmd_to_set_property(property: String) -> String:
	property = property.substr(1) if property.begins_with("/") or property.begins_with("_") else property
	return "set_%s" % [property.replace("/", "_")]

## Converts a command to GDScript property syntax.
## For example: [code]/visible/ratio[/code] is converted to [code]visible_ratio[/code]
func _cmd_to_property(property: String) -> String:
	property = property.substr(1) if property.begins_with("/") or property.begins_with("_") else property
	return property.replace("/", "_")

# FIX: change array arguments to separate arguments: property, actor, value(s)
func setActorProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	var property = _cmd_to_property(args[0])	
	for actor in result.value:
		result = getArgsAsPropertyType(actor, property, args.slice(2))
		if result.isError(): return result
		property = result.value.propertyName
		var value = result.value.propertyValue
		actor.call(_cmd_to_set_property(property), value)
	return Status.ok()

func setAnimationProperty(property, args) -> Status:
	return callAnimationMethod("/set" + property, args)

func setAnimationFramesProperty(property, args) -> Status:
	return callAnimationFramesMethod("/set" + property, args)

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

func setRelativeProperty(args: Array) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	for actor in result.value:
		var property = args[0]
		var values = args.slice(2)
		if property.begins_with("/"): property = property.substr(1)
		property = property.replace("/", "_")
		var object = actor if actor.has_method("get_"+property) else actor.get_node("Animation")
		var currentValue = object.get(property)
		var modifier: Variant
	#	Log.debug("property: %s.%s" % [object.name, property])
	#	Log.debug("values: %s -> %s" % [currentValue, values])
		if currentValue == null: return Status.error("Property not found: %s.%s" % [object.name, property])
		match typeof(currentValue):
			TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4: 
				# need to convert values to vector to do the math, then convert them
				# back to array for setNodePropertyWithVector, which only accepts array arguments
				# because it's a callabe in a CommandDescription which can't pass vector carguments. 
				modifier = arrayToVector(values)
				var modifiedVec = currentValue + modifier
				var modifiedValues : Array
				match typeof(currentValue):
					TYPE_VECTOR2: modifiedValues = [modifiedVec.x, modifiedVec.y]
					TYPE_VECTOR3: modifiedValues = [modifiedVec.x, modifiedVec.y, modifiedVec.y]
					TYPE_VECTOR4: modifiedValues = [modifiedVec.x, modifiedVec.y, modifiedVec.y, modifiedVec.z]
				setNodePropertyWithVector(object, property, modifiedValues)
				return Status.ok(object.get(property))
			TYPE_ARRAY: modifier = values
			TYPE_FLOAT: modifier = float(values[0])
			TYPE_INT: modifier = int(values[0])
			_:
				modifier = values[0]
		object.set(property, currentValue + modifier)
	#return Status.ok(object.get(property))
	return Status.ok()

func arrayToVector(input: Array) -> Variant:
	for i in len(input):
		input[i] = float(input[i])
	match len(input):
		2: return Vector2(input[0], input[1])
		3: return Vector3(input[0], input[1], input[2])
		4: return Vector4(input[0], input[1], input[2], input[3])
		_: return null

func callActorMethod(method, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	method = method.replace("/", "_")
	if method.begins_with("_"): method = method.substr(1)
	args = args.slice(1)
	for actor in result.value:
		if method.begins_with("/"): method = method.substr(1)
		if len(args) == 0:
			result = actor.call(method)
		else:
			result = actor.callv(method, args)
	#return Status.ok(result, "Called %s.%s(%s): %s" % [actor.get_name(), method, args, result])
	return Status.ok()
	
func callAnimationMethod(method, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	method = method.substr(1).replace("/", "_").to_lower()
	args = args.slice(1)
	for actor in result.value:
		var animation = actor.get_node("Animation")
		if len(args) == 0:
			result = animation.call(method)
		else:
			result = animation.callv(method, args)
	#return Status.ok(result, "Called %s.%s.%s(%s): %s" % [actor.get_name(), animation.get_animation(), method, args, result])
	return Status.ok()

func callAnimationFramesMethod(method, args) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	method = method.substr(1) if method.begins_with("/") else method
	method = method.replace("/", "_").to_lower()
	for actor in result.value:
		var animation = actor.get_node("Animation")
		var frames = animation.get_sprite_frames()
		# replace first argument with animation name
		# most of the SpriteFrames methods need the animation name as first argument
		args[0] = animation.get_animation()
		var x = typeof(args[1])
		result = frames.callv(method, args)
	return Status.ok()

func callActorMethodWithVector(method, args) -> Status:
	var result = getActors(args[1])
	if result.isError(): return result
	for actor in result.value:
		callMethodWithVector(actor, method, args.slice(1))
	return Status.ok()

func callMethodWithVector(object: Variant, method: String, args: Array) -> Status:
	method = method.substr(1) if method.begins_with("/") else method
	method = method.replace("/", "_").to_lower()
	for i in len(args):
		args[i] = float(args[i])
	
	match len(args):
		2:
			object.call(method, Vector2(args[0], args[1]))
		3:
			object.call(method, Vector3(args[0], args[1], args[2]))
		4:
			object.call(method, Vector4(args[0], args[1], args[2], args[3]))
		_:
			return Status.error("callActorMethodWithVector xpected between 1 and 4 arguments, received: %s" % [len(args.slice(1))])
	return Status.ok(true, "Called %s.%s(Vector%d(%s))" % [object.get_name(), method, args.slice(1)])

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
	return Status.ok(true, "New routine '%s' (%s times every %s): %s" % [name, repeats, interval, command])

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

func rotate(args: Array) -> Status:
	return setRelativeProperty(["/rotation/degrees"] + args)

func center(actorName: String) -> Status:
	var result = getActors(actorName)
	if result.isError(): return result
	for actor in result.value:
		actor.set_position(Vector2(0.5,0.5) * get_parent().get_viewport_rect().size)
	return Status.ok()

func move(args: Array) -> Status:
	return setRelativeProperty(["/position"] + args)

func moveX(args: Array) -> Status:
	args.append(0)
	return move(args)

func moveY(args: Array) -> Status:
	args.insert(1,0)
	return move(args)

func size(args: Array) -> Status:
	return setActorPropertyWithVector("/scale", args)

func sizeX(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actor.scale.x = float(args[1])
	return Status.ok()

func sizeY(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actor.scale.y = float(args[1])
	return Status.ok()

func scale(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actor.scale *= Vector2(float(args[1]), float(args[1]))
	return Status.ok()

func scaleX(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actor.scale.x *= float(args[1])
	return Status.ok()

func scaleY(args: Array) -> Status:
	var result = getActors(args[0])
	if result.isError(): return result
	for actor in result.value:
		actor.scale.y *= float(args[1])
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
	var transitionType = args[1] as float
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
		tween.tween_property(node, property, value, dur)
	return Status.ok()

## converts the array of arguments given by the command to the appropriate type depending on
## the property
func getArgsAsPropertyType(node: Node, propertyName: String, args: Array) -> Status:
	var property = node.get(propertyName)
	var isNone := false
	var value: Variant
	match typeof(property):
		TYPE_VECTOR2: value = Vector2(args[0] as float, args[1] as float)
		TYPE_VECTOR3: value = Vector3(args[0] as float, args[1] as float, args[2] as float)
		TYPE_VECTOR4: value = Vector4(args[0] as float, args[1] as float, args[2] as float, args[3] as float)
		TYPE_COLOR: value = Color(args[0] as float, args[1] as float, args[2] as float)
		TYPE_STRING: value = " ".join(args)
		TYPE_FLOAT: value = args[0] as float
		TYPE_INT: value = args[0] as float
		_: 
			# if it's none of the above, probably is an axis of a vector or a color 
			# we take the whole vector and assign the command value to the according axis keeping
			# the rest intact
			var axisName = propertyName.split("_")[1]
			propertyName = propertyName.split("_")[0]
			property = node.get(propertyName)
			if propertyName == null: return Status.error("Property not found: %s.%s" % [node, propertyName])
			var axisValue = args[0] as float
			match axisName:
				"x": property.x = args[0] as float
				"y": property.y = args[0] as float
				"z": property.z = args[0] as float
				"r": property.r = args[0] as float
				"g": property.g = args[0] as float
				"b": property.b = args[0] as float
				"a": property.a = args[0] as float
			value = property
			propertyName = propertyName.replace("_", ".")
	return Status.ok({"node": node, "propertyName": propertyName, "propertyValue": value})

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

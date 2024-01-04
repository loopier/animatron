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

var ocl := preload("res://ocl.gd").new()
var status := preload("res://Status.gd")
var metanode := preload("res://meta_node.tscn")
@onready var Routine := preload("res://RoutineNode.tscn")
var assetHelpers := preload("res://asset_helpers.gd").new()
@onready var postWindow: Node
@onready var actorsNode: Node
@onready var routinesNode: Node
@onready var stateMachines: Dictionary
@onready var commandManger: Node
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
	"/load/file": CommandDescription.new(loadCommandFile, "path:s", "Load a custom command definitions file, which should have the format described below."),
#	"/test": CommandDescription.new(getActor, "", "This is just a test"), ## used to test random stuff
	"/set": CommandDescription.new(setVar, "", "TODO"),
	"/get": CommandDescription.new(getVar, "", "TODO"),
	# log
	"/log/level": CommandDescription.new(setLogLevel, "level:s", "Set the log level to either 'fatal', 'error', 'warn', 'debug' or 'verbose'"),
	# general commands
	"/commands/list": CommandDescription.new(listAllCommands, "", "Get list of available commands."),
	"/commands": "/commands/list",
	# assets
	"/load": CommandDescription.new(loadAnimationAsset, "animation:s", "Load an ANIMATION asset from disk. It will create an animation with the same name as the asset. Wildcards are supported, so several animations can be loaded at once. See also: `/assets/list`."),
	"/assets/list": CommandDescription.new(listAnimationAssets, "", "Get the list of available (unloaded) assets. Assets must be loaded as animations in order to create actor instances."), # available in disk
#	"/assets/list": CommandDescription.new(main.bla, "", "a bla"),
	"/assets": "/assets/list",
	"/assets/path": CommandDescription.new(setAssetsPath, "path:s", "Set the path for the parent directory of the assets."), # available in disk
	"/animations/list": CommandDescription.new(listAnimations, "", "Get the list of available (loaded) animations."), # loaded
	"/animations": "/animations/list",
	# actors
	"/actors/list": CommandDescription.new(listActors, "", "Get list of current actor instances. Returns /list/actors/reply OSC message."),
	"/create": CommandDescription.new(createActor, "actor:s animation:s", "Create an ACTOR that plays ANIMATION."),
	"/remove": CommandDescription.new(removeActor, "actor:s", "Delete the ACTOR by name (remove its instance). "),
	"/free": "/remove",
	"/color": CommandDescription.new(colorActor, "actor:s r:f g:f b:f", "Add an RGB colour to the ACTOR. R, G and B should be in the 0-1 range (can be negative to subtract colour). Set to black (0,0,0) to restore its original colour."),
	# routines
	"/routine": CommandDescription.new(addRoutine, "name:s repeats:i interval:f cmd:...", "Start a routine named NAME that sends CMD every INTERVAL of time (in seconds) for an arbitrary number of REPEATS.", Flags.asArray(true)),
	"/routines": CommandDescription.new(listRoutines, "", "Get the list of routines."),
	"/routine/start": CommandDescription.new(startRoutine, "name:s", "Start the routine named NAME."),
	"/routine/stop": CommandDescription.new(stopRoutine, "name:s", "Stop the routine named NAME."),
	"/routine/free": CommandDescription.new(freeRoutine, "name:s", "Remove the routine named NAME"),
	"/routine/finished": CommandDescription.new(finishedRoutine, "routine:s cmd:s", "Set the CMD to be sent when the ROUTINE (name) is finished.", Flags.asArray(true)),
	# state machine
	"/state/add": CommandDescription.new(addState, "actor:s new:s next:s", "Add a NEW state to the ACTOR's state machine. NEXT states is an arbitrary number of next possible states. Example: `/state/add mymachine state1 state1 state2` would create a new state1 in `mymachine` that would either repeat or move on to `state2.`", Flags.asArray(true)),
	"/states": CommandDescription.new(listStates, "", "Get a list of states for the given ACTOR."),
	"/state/free": CommandDescription.new(freeState, "actor:s state:s", "Remove the STATE from the ACTOR's state machine."),
	"/state/next": CommandDescription.new(nextState, "actor:s", "Change ACTOR to next STATE."),
	# def
	"/def": CommandDescription.new(defineCommand, "cmdName:s [args:v] subcommands:c", "Define a custom OSC command that is a list of other OSC commands. This may be recursive, so each SUBCOMMAND may reference one of the built-in commands, or another custom-defined command. Another way to define custom commands is via the file commands/init.osc. The CMDNAME string (first argument) may include argument names (ARG1 ... ARGN), which may be referenced as SUBCOMMAND arguments using $ARG1 ... $ARGN. Example: /def \"/addsel actor anim\" \"/create $actor $anim\" \"/select $actor\". ", Flags.asArray(true)),
	# post
	"/post": CommandDescription.new(post, "msg:s", "Print MSG in the post window.", Flags.asArray(false)),
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
	# utils
	"/relative": CommandDescription.new(setRelativeProperty, "", "TODO", Flags.asArray(false)),
	"/rand": CommandDescription.new(randCmdValue, "cmd:s actor:s min:f max:f", "Send a CMD to an ACTOR with a random value between MIN and MAX. If a wildcard is used, e.g. `bl*`, all ACTORs with with a name that begins with `bl` will get a different value. *WARNING: This only works with single-value commands.*", Flags.asArray(true)),
}

## Custom command definitions
var defCommands := {}

## Node commands map.
## Node commands are parsed differently than [param coreCommands]. They use 
## OSC address as method name (by removing the forward slash), and first argument is
## usually the actor's name (the node's name).[br]
## [br]
## Using meta methods filtered by parameter types allows to automatically map a lot
## of OSC messages to a few actual GDScript functions and methods.[br]
## [br]
## Keep in mind, though, that the command (OSC address) has to have the same signature as
## the expected GDScript method. If a different command name is needed, use a [method def].[br]
## [br]
## To expose new methods or properties, just replace the snake_case underscore in the method for
## a slash '/' in the osc command.
##
## [codeblock]
##   /animation ...tbd...
##   /play ...tbd...
##   ...
## [/codeblock]
var nodeCommands: Dictionary = {
	"/animation": CommandDescription.new(setAnimationProperty, "actor:s animation:s", "Change the ACTOR's ANIMATION.", Flags.gdScript()),
	"/play": CommandDescription.new(callAnimationMethod, "actor:s", "Start playing ACTOR's image sequence.", Flags.gdScript()),
	"/play/backwards": CommandDescription.new(callAnimationMethod, "actor:s", "Play ACTOR's animation backwards.", Flags.gdScript()),
	"/reverse": "/play/backwards",
	"/animation/loop": CommandDescription.new(setAnimationFramesProperty, "", "", Flags.gdScript()),
	"/stop": CommandDescription.new(callAnimationMethod, "actor:s", "Stop playing the ACTOR's animation.", Flags.gdScript()),
	"/frame": CommandDescription.new(setAnimationProperty, "actor:s frame:i", "Set the ACTOR's current FRAME.", Flags.gdScript()),
	"/frame/progress": CommandDescription.new(setAnimationProperty, "", "", Flags.gdScript()),
	"/speed/scale": CommandDescription.new(setAnimationProperty, "actor:s speed:f", "Set the ACTOR's animation SPEED (1 = normal speed, 2 = 2 x speed).", Flags.gdScript()),
	"/speed": "/speed/scale",
	"/flip/v": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip/ ACTOR vertically."),
	"/flip/h": CommandDescription.new(toggleAnimationProperty, "actor:s", "Flip ACTOR horizontally."),
	"/visible": CommandDescription.new(toggleActorProperty, "actor:s visibility:b", "Set ACTOR's VISIBILITY to either true or false."),
	"/hide": CommandDescription.new(callActorMethod, "actor:s", "Show ACTOR (set visibility to true).", Flags.gdScript()),
	"/show": CommandDescription.new(callActorMethod, "actor:s", "Hide ACTOR (set visibility to false).", Flags.gdScript()),
	"/offset": CommandDescription.new(setAnimationPropertyWithVector, "actor:s x:i y:i", "Set the ACTOR's animation drawing offset in pixels.", Flags.gdScript()),
	"/offset/x": CommandDescription.new(setAnimationPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's animation drawing offset on the X axis.", Flags.gdScript()),
	"/offset/y": CommandDescription.new(setAnimationPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's animation drawing offset on the Y axis.", Flags.gdScript()),
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
	"/position": CommandDescription.new(setActorPropertyWithVector, "actor:s x:i y:i", "Set the ACTOR's absolute position in pixels.", Flags.gdScript()),
	"/position/x": CommandDescription.new(setActorPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's absolute position in PIXELS on the X axis.", Flags.gdScript()),
	"/position/y": CommandDescription.new(setActorPropertyWithVectorN, "actor:s pixels:i", "Set the ACTOR's absolute position in PIXELS on the Y axis.", Flags.gdScript()),
	"/move": CommandDescription.new(move, "actor:s xcoord:f ycoord:f", "Move ACTOR to XCOORD - YCOORD relative to the current position.", Flags.asArray(false)),
	"/move/x": CommandDescription.new(moveX, "actor:s xcoord:f", "Move ACTOR to XCOORD relative to the current position.", Flags.asArray(false)),
	"/move/y": CommandDescription.new(moveY, "actor:s ycoord:f", "Move ACTOR to YCOORD relative to the current position.", Flags.asArray(false)),
	"/rotation/degrees": CommandDescription.new(setActorProperty, "actor:s degrees:f", "Set the angle of the ACTOR in DEGREES.", Flags.gdScript()),
	"/angle": "/rotation/degrees",
	"/rotate": CommandDescription.new(rotate, "actor:s degrees:f", "Rotate ACTOR a number of DEGREES relative to the current rotation.", Flags.asArray(false)),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	oscSender = OscReceiver.new()

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
	defCommands[commandName] = {"variables": {}, "subcommands": subCommands}
	# we need to initialize the variables placeholder 
	for variable in commandVariables:
		defCommands[commandName].variables[variable] = null
	return Status.ok([commandName, commandVariables, subCommands], "Added command def: %s %s" % [commandName, commandVariables, subCommands])

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

func post(args: Array) -> Status:
	args = " ".join(PackedStringArray(args)).split("\\n")
	for arg in args:
		Log.info(arg)
	postWindow.set_text("%s\n%s" % [postWindow.get_text(), " ".join(PackedStringArray(args))])
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
	return Status.ok()

func midiNoteOnNum(args: Array) -> Status:
	# TODO
	
	var chan = int(args[0])
	var num = int(args[1])
	midiCommands[chan]["noteOnNum"].append = args.slice(1)
	return Status.ok()

func midiNoteOnTrig(args: Array) -> Status:
	return Status.ok()

func midiNoteOnNumVelocity(args: Array) -> Status:
	return Status.ok()

func midiNoteOnVelocity(args: Array) -> Status:
	return Status.ok()

func midiNoteOn(args: Array) -> Status:
	return Status.ok()

func midiNoteOffNum(args: Array) -> Status:
	return Status.ok()

func midiNoteOff(args: Array) -> Status:
	return Status.ok()

func getHelp(cmd: String) -> Status:
	var cmdDesc = getCommandDescription(cmd)
	if not(cmd.begins_with("/")): 
		return getHelp("/" + cmd)
	if cmdDesc == null:
		return Status.error("Help not found: %s" % [cmd])
	
	# this might change in the future if we convert /defs into CommandDescriptions.
	# as for now it dumps the def's subcommands
	if typeof(cmdDesc) == TYPE_DICTIONARY: 
		var msg := "[HELP] custom definition\n/def %s" % [cmd]
		for key in cmdDesc.variables.keys():
			msg += " %s" % [key]
		msg += "\n"
		for subcmd in cmdDesc.subcommands:
			msg += "\t%s\n" % [" ".join(subcmd)]
		postWindow.set_text(msg)
		return Status.ok(cmdDesc, msg)
	postWindow.set_text("[HELP] %s %s\n\n%s" % [cmd, cmdDesc.argsDescription, cmdDesc.description])
	return Status.ok(cmdDesc, "[HELP] %s %s - %s" % [cmd, cmdDesc.argsDescription, cmdDesc.description])

## Read a file with a [param filename] and return its OSC constent in a string
func loadFile(filename: String) -> Status:
	Log.verbose("Reading: %s" % [filename])
	var file = FileAccess.open(filename, FileAccess.READ)
	var content = file.get_as_text()
	if content == null: return Status.error()
	return Status.ok("Read file successful: %s" % filename, content)

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
	elif nodeCommands.has(command): return nodeCommands[command]
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
	list += "\nNode Commands:\n"
	list += listCommands(nodeCommands).value
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
	Log.info("List of actors (%s)" % [len(actors)])
	for actor in actors:
		var actorName := actor.get_name()
		var anim: String = actor.get_node("Animation").get_animation()
		actorsList.append("%s (%s)" % [actorName, anim])
		Log.info(actorsList.back())
	actorsList.sort()
	return Status.ok(actorsList)

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
			if result.isError(): return Status.error("Image sequence assets not loaded: %s" % [path])
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
	for file in filenames:
		if file.ends_with(".png"):
#			Log.debug("Loading img to '%s': %s" % [animName, path.path_join(file)])
			var texture := assetHelpers.loadImage(path.path_join(file))
			animationsLibrary.add_frame(animName, texture)
	
	return Status.ok(true, "Loaded %s frames: %s" % [animationsLibrary.get_frame_count(animName), animName])


func getAllActors() -> Status:
	return Status.ok(actorsNode.get_children())

## Returns an actor by exact name match (see [method getActors])
func getActor(actorName: String) -> Status:
	var actor = actorsNode.find_child(actorName)
	if actor == null: return Status.error("Actor not found: %s" % [actorName])
	return Status.ok(actor)

## Returns an array of children matching the name pattern
func getActors(namePattern: String) -> Status:
	var actors = actorsNode.find_children(namePattern)
	if actors == null or len(actors) == 0: return Status.error("No actors found: %s" % [namePattern])
	return Status.ok(actors)

func createActor(actorName: String, anim: String) -> Status:
	if not animationsLibrary.has_animation(anim):
		return Status.error("Animation not found: %s" % [anim])
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
	actor.set_position(Vector2(0.5,0.5) * get_parent().get_viewport_rect().size)
	var animationNode = actor.get_node("Animation")
	animationNode.set_sprite_frames(animationsLibrary)
	animationNode.play(anim)
	animationNode.get_sprite_frames().set_animation_speed(anim, 12)
	actorsNode.add_child(actor)
	# Need to set an owner so it appears in the SceneTree and can be found using
	# Node.finde_child(pattern) -- see Node docs
	actor.set_owner(actorsNode)
	return Status.ok(actor, msg)

func removeActor(actorName: String) -> Status:
	var result = getActor(actorName)
	if result.isError(): return result
	var actor = result.value
	actorsNode.remove_child(actor)
	return Status.ok(actor)

func setActorAnimation(actorName, animation) -> Status:
	var result = getActor(actorName)
	if result.isError(): return result
	if not animationsLibrary.has_animation(animation): return Status.error("Animation not found: %s" % [animation])
	result.value.get_node("Animation").play(animation)
	return Status.ok(true, "Set animation for '%s': %s" % [actorName, animation])

## Sets any Vector [param property] of any node. 
## [param args[1..]] are the vector values (between 2 and 4). If only 1 value is passed, it will set the same value on all axes.
func setNodePropertyWithVector(node, property, args) -> Status:
	var setProperty = "set_%s" % [property.get_slice("/",1)]
	var vec = node.call("get_%s" % [property.get_slice("/",1)])
	if len(args) < 2:
		match typeof(vec):
			TYPE_VECTOR2: args = [args[0], args[0]]
			TYPE_VECTOR3: args = [args[0], args[0], args[0]]
			TYPE_VECTOR4: args = [args[0], args[0], args[0], args[0]]
	return callMethodWithVector(node, setProperty, args)

func setActorPropertyWithVector(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	return setNodePropertyWithVector(result.value, property, args.slice(1))

func setAnimationPropertyWithVector(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Animation")
	return setNodePropertyWithVector(animation, property, args.slice(1))

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

func setActorPropertyWithVectorN(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	return setNodePropertyWithVectorN(actor, property, args[1])

func setAnimationPropertyWithVectorN(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Animation")
	return setNodePropertyWithVectorN(animation, property, args[1])

func setActorProperty(property, args) -> Status:
	return callActorMethod("/set" + property, args if len(args) > 0 else [])

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
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	return toggleProperty(property, actor)

func toggleAnimationProperty(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var animation = result.value.get_node("Animation")
	return toggleProperty(property, animation)

func setRelativeProperty(args: Array) -> Status:
	var result = getActor(args[1])
	if result.isError(): return result
	var actor = result.value
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
	return Status.ok(object.get(property))

func arrayToVector(input: Array) -> Variant:
	for i in len(input):
		input[i] = float(input[i])
	match len(input):
		2: return Vector2(input[0], input[1])
		3: return Vector3(input[0], input[1], input[2])
		4: return Vector4(input[0], input[1], input[2], input[3])
		_: return null

func callActorMethod(method, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	if method.begins_with("/"): method = method.substr(1)
	method = method.replace("/", "_")
	args = args.slice(1)
	if len(args) == 0:
		result = actor.call(method)
	else:
		result = actor.callv(method, args)
	return Status.ok(result, "Called %s.%s(%s): %s" % [actor.get_name(), method, args, result])
	
func callAnimationMethod(method, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Animation")
	method = method.substr(1).replace("/", "_").to_lower()
	args = args.slice(1)
	if len(args) == 0:
		result = animation.call(method)
	else:
		result = animation.callv(method, args)
	return Status.ok(result, "Called %s.%s.%s(%s): %s" % [actor.get_name(), animation.get_animation(), method, args, result])

func callAnimationFramesMethod(method, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Animation")
	var frames = animation.get_sprite_frames()
	method = method.substr(1) if method.begins_with("/") else method
	method = method.replace("/", "_").to_lower()
	# replace first argument with animation name
	# most of the SpriteFrames methods need the animation name as first argument
	args[0] = animation.get_animation()
	result = frames.callv(method, args)
	return Status.ok(result, "Called %s.%s.frames.%s(%s): %s" % [actor.get_name(), animation.get_animation(), method, args, result])

func callActorMethodWithVector(method, args) -> Status:
	var result = getActor(args[1])
	if result.isError(): return result
	var actor = result.value
	return callMethodWithVector(actor, method, args.slice(1))

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
	var result := getActor(actorName)
	if result.isError(): return result
	var actor := result.value as Node
	var animation := actor.get_node("Animation") as AnimatedSprite2D
	var rgb := Vector3(red as float, green as float, blue as float)
	setImageShaderUniform(animation, "uAddColor", rgb)
	return Status.ok(result, "Set actor '%s' color to %s" % [actor.get_name(), rgb])


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

func listStates() -> Status:
	var machines := stateMachines.keys()
	machines.sort()
	var msg := "State machines:"
	for machine in machines:
		msg += "%s(%s): %s" % [machine, stateMachines[machine].status(), stateMachines[machine].list()]
	return Status.ok(machines, msg)

func addState(args: Array) -> Status:
	var machineName = args[0]
	if not(stateMachines.has(machineName)):
		var machine = StateMachine.new()
		machine.name = machineName
		stateMachines[machineName] = machine
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
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actor.scale.x = float(args[1])
	return Status.ok(actor)

func sizeY(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actor.scale.y = float(args[1])
	return Status.ok(actor)

func scale(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actor.scale *= Vector2(float(args[1]), float(args[1]))
	return Status.ok(actor)

func scaleX(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actor.scale.x *= float(args[1])
	return Status.ok(actor)

func scaleY(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actor.scale.y *= float(args[1])
	return Status.ok(actor)

func setInFrontOfActor(args: Array) -> Status:
	var result = getActor(args[0])
	var targetResult = getActor(args[1])
	if result.isError(): return result
	if targetResult.isError(): return targetResult
	var actor = result.value
	var target = targetResult.value
	actorsNode.move_child(actor, target.get_index()+1)
	return Status.ok(true)

func setBehindActor(args: Array) -> Status:
	var result = getActor(args[0])
	var targetResult = getActor(args[1])
	if result.isError(): return result
	if targetResult.isError(): return targetResult
	var actor = result.value
	var target = targetResult.value
	actorsNode.move_child(target, actor.get_index()+1)
	return Status.ok(true)

func setTopActor(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actorsNode.move_child(actor, actorsNode.get_child_count())
	return Status.ok(true)

func setBottomActor(args: Array) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	actorsNode.move_child(actor, 0)
	return Status.ok(true)

func randCmdValue(args: Array) -> Status:
	var command = args[0]
	var result = getActors(args[1])
	if result.isError(): return result
	for actor in result.value:
		var value = randf_range(float(args[2]), float(args[3]))
		commandManger.evalCommand([command, actor.name, value], "CommandInterface")
	return Status.ok(true)

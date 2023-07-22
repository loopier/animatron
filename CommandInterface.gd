class_name OscInterface
extends Node
## Map OSC commands to Godot functionality
##
## Using dictionaries to store variable values and function pointers.
##
## @tutorial:	TODO
## @tutorial(2):	TODO

signal command_finished(msg, sender)
signal command_not_found(command, sender)
signal command_error(msg, sender)

enum {
	COMMAND_CALLABLE,
	COMMAND_VARIABLE,
	COMMAND_DEF,
	COMMAND_SUBCOMMAND,
}

var status := preload("res://Status.gd")
@onready var metanode := preload("res://meta_node.tscn")
@onready var animationNodePath := "Offset/Animation"
var animationsLibrary: SpriteFrames ## The meta node containing these frames needs to be initialized in _ready
@onready var main := get_parent()
@onready var actorsNode := main.get_node("Actors")
var assetsPath = "user://assets"

## A dictionary used to store variables accessible from OSC messages.
## They are stored in a file, and loaded into this dictionary.
var variables: Dictionary:
	set(value): variables = value
	get: return variables
## Commands map.
var coreCommands: Dictionary = {
	"/test": getActor, ## used to test random stuff
	"/set": setVar,
	"/get": getVar,
	# general commands
	"/commands/list": listCommands,
	# assets
	"/load": loadAsset,
	"/assets/list": listAssets, # available in disk
	"/animations/list": listAnimations, # loaded
	"/actors/list": listActors,
	"/create": createActor,
}
var actorCommands: Dictionary = {
	"/remove": removeActor,
	"/free": "/remove",
	"/animation": setActorAnimation,
#	"/scale": scaleActor,
	"/scale": callActorMethodWithVector,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	var animationsLibraryNode = metanode.instantiate().get_node(animationNodePath)
	animationsLibraryNode.set_sprite_frames(SpriteFrames.new())
	animationsLibrary = animationsLibraryNode.get_sprite_frames()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func reportError(msg, sender = null):
	Log.error(msg)

func reportStatus(msg, sender = null):
	Log.verbose("TODO: report message back to '%s'" % [sender])
	Log.info(msg)

## Different behaviours depend on the [param command] contents in the [member commands] Dictionary.
func parseCommand(key: String, args: Array, sender: String) -> Variant:
	var commandDicts := [coreCommands, actorCommands]
	var commandValue: Variant
	var commandDict: Dictionary
	var result: Status
	for dict in commandDicts:
		commandValue = dict.get(key)
		if commandValue != null: 
			commandDict = dict
			break
	
	match commandDict:
		coreCommands:
			result = commandValue.callv(args)
		actorCommands:
			result = commandValue.call(key, args)
		_:
			command_not_found.emit(key, sender)
			return null
	
	match result.type:
		Status.OK: command_finished.emit(result.msg, sender)
		Status.ERROR: command_error.emit(result.msg, sender)
		_: command_not_found.emit(key, sender)

	return null
#	# all custom command methods must return anything other than 'null'
#	var result: Status = getCommand(key)
#	# get OSC key from commands dict
#	var value = result.value
#	var msg = result.msg
#	match typeof(value):
#		TYPE_CALLABLE: result = value.callv(args)
#		TYPE_STRING:
#			# if it's a variable: get the value and return it to the parent command
#			result = getVar(value)
#			# if it's a command: parse arguments
#			if result.value == null:
#				result = getCommand(value)
#				Log.debug("Checking for subcommand '%s':'%s' => %s" % [key, value, result])
#				result = parseCommand(value, args, sender)
#		_: 
##			result = executeCommandAsGdScript(key, args)
#			pass
#
#	# else: it doesn't, report error back to sender
##	if result.value == null:
##		reportError("TODO: send '%s' error back to the sender" % [key])
##		return
#	Log.verbose("Parsed command '%s': %s %s" % [key, value, args])
#	reportStatus(result.msg, sender)
#	return result

## Read a file with a [param filename] and return its OSC constent in a string
func loadFile( filename: String ) -> Status:
	Log.verbose("Reading: %s" % [filename])
	var file = FileAccess.open(filename, FileAccess.READ)
	var content = file.get_as_text()
	if content == null: return Status.error()
	return Status.ok("Read file successful: %s" % filename, content)

## Return a dictionary based on the string [param oscStr] of OSC messages.[br]
## The address is the key of the dictionary (or the first element), and the 
## array of arguments the value.
func oscStrToDict( oscStr: String ) -> Dictionary:
	var dict: Dictionary
	var lines = oscStr.split("\n")
	for line in lines:
		var items: Array = line.split(" ")
		if items[0] == "": continue
		dict[items[0]] = items.slice(1)
	return dict

func isActor( name ) -> bool:
	return false if main.get_node("Actors").find_child(name) == null else true

## Try to execute a command as a GDScript function
func executeCommandAsGdScript(command, args) -> Status:
	# if args first element is an actor, call it's Node2D method equivalent to 'command'
	var actorName = args[0]
	args = args.slice(1)
	var actor = getActor(actorName).value
	if actor == null:
		return Status.error("Actor not found: %s" % [actorName])
	command = command.get_slice("/", 1)
	var msg = "Execute GDScript command: %s.%s(%s)" % [actor, command, args]
	var result = actor.callv(command, args)
	Log.debug("exec result: %s" % [result])
	return Status.ok(result, msg)

## Get a variable value by [param name].
##
## This method returns a single value. If by any reason the value holds
## more than one, it will return only the first one.
func getVar( name: String ) -> Status:
	var value = variables[name][0] if variables.has(name) else null
#	Log.debug("Looking for var '%s': %s" % [name, value])
	if value == null: return Status.error("Variable '%s' not found return: %s" % [name, value])
	return Status.ok(value, "Variable '%s': %s" % [name, value])

## Set and store new [param value] in a variable with a [param name]
## Returns the value stored in the variable
func setVar( name: String, value: Variant ) -> Status:
	variables[name] = [value]
	if Log.getLevel() == Log.LOG_LEVEL_VERBOSE:
		list(variables)
	reportStatus(variables[name][0], null)
	return Status.ok(variables[name][0])

func getCommand( command: String ) -> Status:
	var value = coreCommands[command] if coreCommands.has(command) else null
	if value == null: Status.error("Command '%s' not found" % [command])
	return Status.ok(value, "Command found '%s': %s" % [command, value])

## Remove the [param key] and its value from [param dict]
func remove( key, dict ) -> Status:
	if variables.has(key): 
		variables.erase(key)
		reportStatus("Removed '%s' from %s" % [key, dict], null)
		return Status.ok(null, "Removed '%s' from %s" % [key, dict])
	else:
		return Status.error("Key not found in %s: '%s'" % [dict, key])

## List contents of [param dict]
func list( dict: Dictionary ) -> Status:
	var list := []
	var msg: String
	for key in dict:
		list.append(key)
		msg += "%s: %s" % [key, dict[key]]
	list.sort()
	return Status.ok(list, msg)
	

func listCommands() -> Status:
	var list := "\nCommands:\n"
	for command in coreCommands.keys():
		list += "%s\n" % [command]
	return Status.ok(coreCommands.keys(), list)

func listActors() -> Status:
	var actorsList := []
	var actors: Array = getAllActors().value
	Log.info("List of actors (%s)" % [len(actors)])
	for actor in actors:
		var name: String = actor.get_name()
		var anim: String = actor.get_node(animationNodePath).get_animation()
		actorsList.append("%s (%s)" % [name, anim])
		Log.info(actorsList.back())
	actorsList.sort()
	return Status.ok(actorsList)

func listAnimations() -> Status:
	var animationNames = animationsLibrary.get_animation_names()
	var msg := "List of animations (%s):\n" % [len(animationNames)]
	for name in animationNames:
		var frameCount = animationsLibrary.get_frame_count(name)
		msg += "%s (%s)\n" % [name, frameCount]
	return Status.ok(animationNames, msg)

func listAssets() -> Status:
	var dir := DirAccess.open(assetsPath)
	var assetNames := []
	if dir:
		dir.list_dir_begin()
		var filename = dir.get_next()
		while filename != "":
			assetNames.append(filename)
			filename = dir.get_next()
	assetNames.sort()
	var msg := "Assets at '%s':\n" % [ProjectSettings.globalize_path(assetsPath)]
	for name in assetNames:
		msg += "%s\n" % [name]
	return Status.ok(assetNames, msg)

func loadAsset(name: String) -> Status:
	var path = assetsPath.path_join(name)
	Log.debug("TODO: load sprites and image sequences from disk: %s" % [path])
	var result = loadImageSequence(path)
	if result.isError(): return Status.error("Assets not found: %s" % [path])
	return Status.ok(true)

func loadImageSequence(path: String) -> Status:
	var filenames = DirAccess.get_files_at(path)
	var name = path.get_basename().split("/")[-1]
	if animationsLibrary.has_animation(name):
		return Status.error("Animation already loaded: '%s'" % [name])
	animationsLibrary.add_animation(name)
	for file in filenames:
		if file.ends_with(".png"):
#			Log.debug("Loading img to '%s': %s" % [name, path.path_join(file)])
			var texture = loadImage(path.path_join(file))
			animationsLibrary.add_frame(name, texture)
	
	return Status.ok(true, "Loaded %s frames: %s" % [animationsLibrary.get_frame_count(name), name])

func loadImage(path: String) -> ImageTexture:
	Log.verbose("Loading image: %s" % [path])
	var img = Image.load_from_file(path)
	var texture = ImageTexture.create_from_image(img)
	return texture

func getAllActors() -> Status:
	return Status.ok(actorsNode.get_children())

## Returns an actor by exact name match (see [method getActors])
func getActor(name: String) -> Status:
	var actor = actorsNode.get_node(name)
	if actor == null: return Status.error("Actor not found: %s" % [name])
	return Status.ok(actorsNode.get_node(name))

## Returns an array of children matching the name pattern
func getActors(namePattern: String) -> Status:
	var actors = actorsNode.find_children(namePattern)
	if actors == null or len(actors) == 0: return Status.error("No actors found: %s" % [namePattern])
	return Status.ok(actors)

func createActor(name: String, anim: String) -> Status:
	Log.debug("TODO Add anim to actor on creation '%s': %s" % [name, anim])
	if not animationsLibrary.has_animation(anim):
		return Status.error("Animation not found: %s" % [anim])
	var actor: CharacterBody2D
	var msg: String
	var result = getActor(name)
	Log.debug(result.msg)
	if result.value != null:
		actor = getActor(name).value
		msg = "Actor already exists: %s\n" % [actor]
		msg += "Setting new animation: %s" % [anim]
	else:
		actor = metanode.instantiate()
		msg = "Created new actor '%s': %s" % [name, anim]
	Log.debug(msg)
	actor.set_name(name)
	actor.set_position(Vector2(0.5,0.5) * get_parent().get_viewport_rect().size)
	var animationNode = actor.get_node(animationNodePath)
	animationNode.set_sprite_frames(animationsLibrary)
	animationNode.play(anim)
	animationNode.get_sprite_frames().set_animation_speed(anim, 12)
	actorsNode.add_child(actor)
	# Need to set an owner so it appears in the SceneTree and can be found using
	# Node.finde_child(pattern) -- see Node docs
	actor.set_owner(actorsNode)
	return Status.ok(actor, msg)

func removeActor(name: String) -> Status:
	var result = getActor(name)
	if result.isError(): return result
	var actor = result.value
	actorsNode.remove_child(actor)
	return Status.ok(actor)

func setActorAnimation(actorName, animation) -> Status:
	var result = getActor(actorName)
	if result.isError(): return result
	if not animationsLibrary.has_animation(animation): return Status.error("Animation not found: %s" % [animation])
	result.value.get_node(animationNodePath).play(animation)
	return Status.ok(true, "Set animation for '%s': %s" % [actorName, animation])

func callActorMethodWithVector(method, args) -> Status:
	var result = getActor(args[0])
#	return Status.error("Calling '%s': %s" % [method, args])
	if result.isError(): return result
	var actor = result.value
	# we need to remove the actor name from the arguments
	args = args.slice(1)
	method = "set_%s" % [method.get_slice("/",1)]
	Log.debug("actor: %s - method: %s - args (%s): %s" % [actor.name, method, len(args), args])
	match len(args):
		2:
			actor.call(method, Vector2(args[0], args[1]))
		3:
			actor.call(method, Vector3(args[0], args[1], args[2]))
		4:
			actor.call(method, Vector4(args[0], args[1], args[2], args[3]))
		_:
			return Status.error("callActorMethodWithVector xpected between 2 and 4 arguments, received: %s" % [len(args.slice(1))])
	return Status.ok(true, "Called %s.%s(Vector%d(%s))" % [actor.get_name(), method, args.slice(1)])

func scaleActor(name: String, x: float, y: float) -> Status:
	var result = getActor(name)
	if result.isError(): return result
	var actor = result.value
	var scale = Vector2(x,y)
	actor.set_scale(Vector2(x,y))
	return Status.ok(result, "%s" % [actor.get_scale()])

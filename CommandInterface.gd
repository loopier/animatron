class_name OscInterface
extends Node
## Map OSC commands to Godot functionality
##
## Using dictionaries to store variable values and function pointers.
##
## @tutorial:	TODO
## @tutorial(2):	TODO

signal command_finished(msg, sender)
signal command_error(msg, sender)

var status := preload("res://Status.gd")
var metanode := preload("res://meta_node.tscn")
@onready var animationNodePath := "Offset/Animation"
@onready var main := get_parent()
@onready var actorsNode := main.get_node("Actors")
var animationsLibrary: SpriteFrames ## The meta node containing these frames needs to be initialized in _ready
var assetsPath = "user://assets"

## A dictionary used to store variables accessible from OSC messages.
## They are stored in a file, and loaded into this dictionary.
var variables: Dictionary:
	set(value): variables = value
	get: return variables
## Core ommands map.
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
	"/remove": removeActor,
	"/free": "/remove",
	"/animation": setActorAnimation,
}
## Node commands map.
## Node commands are parsed differently than [param coreCommands]. They use 
## OSC address as method name (by removing the forward slash), and first argument is
## usually the actor's name (the node's name).
## Using meta methods filtered by parameter types allows to automatically map a lot
## of OSC messages to a few actual GDScript functions and methods.
## Keep in mind, though, that the command (OSC address) has to have the same signature as
## the expected GDScript method. If a different command name is needed, use a [method def].
var nodeCommands: Dictionary = {
	"/play": callAnimationMethod,
	"/play/backwards": callAnimationMethod,
	"/reverse": "/play/backwards",
	"/stop": callAnimationMethod,
	"/frame": setAnimationProperty,
	"/frame/progress": setAnimationProperty,
	"/speed/scale": setAnimationProperty,
	"/speed": "/speed/scale",
	"/flip/v": setAnimationProperty,
	"/flip/h": setAnimationProperty,
	"/offset": setAnimationVector,
	"/scale": setActorVector,
	"/scale/x": setActorVectorN,
	"/scale/y": setActorVectorN,
	"/position": setActorVector,
	"/position/x": setActorVectorN,
	"/position/y": setActorVectorN,
	"/rotation": "/rotation/degrees",
	"/rotation/degrees": setActorProperty,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	var animationsLibraryNode = AnimatedSprite2D.new()
	animationsLibraryNode.set_sprite_frames(SpriteFrames.new())
	animationsLibrary = animationsLibraryNode.get_sprite_frames()
	main.add_child(animationsLibraryNode)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func reportError(msg, sender = null):
	Log.error(msg)

func reportStatus(msg, sender = null):
	Log.verbose("TODO: report message back to '%s'" % [sender])
	Log.info(msg)

## Different behaviours depend on the [param command] contents in the different [member xxxCommands] dictionaries.
func parseCommand(key: String, args: Array, sender: String) -> Status:
	var commandDicts := [coreCommands, nodeCommands]
	var commandValue: Variant
	var commandDict: Dictionary
	var result := Status.new()
	for dict in commandDicts:
		commandValue = dict.get(key)
		if commandValue != null: 
			commandDict = dict
			break
	
	# aliases
	if typeof(commandValue) == TYPE_STRING: 
		return parseCommand(commandValue, args, sender) 
	
	match commandDict:
		coreCommands: result = commandValue.callv(args)
		nodeCommands: result = commandValue.call(key, args)
		_: command_error.emit("Command not found: %s" % [key], sender)
	
	match result.type:
		Status.OK: command_finished.emit(result.msg, sender)
		Status.ERROR: command_error.emit(result.msg, sender)
		_: pass

	return result

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
		_list(variables)
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
func _list( dict: Dictionary ) -> Status:
	var list := []
	var msg: String
	for key in dict:
		list.append(key)
		msg += "%s: %s" % [key, dict[key]]
	list.sort()
	return Status.ok(list, msg)
	

func listCommands() -> Status:
	var list := "\nCommands:\n"
	var commands = coreCommands.keys()
	commands.append_array(nodeCommands.keys())
	for command in commands:
		list += "%s\n" % [command]
	return Status.ok(commands, list)

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
	var actor = actorsNode.find_child(name)
	if actor == null: return Status.error("Actor not found: %s" % [name])
	return Status.ok(actor)

## Returns an array of children matching the name pattern
func getActors(namePattern: String) -> Status:
	var actors = actorsNode.find_children(namePattern)
	if actors == null or len(actors) == 0: return Status.error("No actors found: %s" % [namePattern])
	return Status.ok(actors)

func createActor(name: String, anim: String) -> Status:
	Log.debug("TODO Add anim to actor on creation '%s': %s" % [name, anim])
	if not animationsLibrary.has_animation(anim):
		return Status.error("Animation not found: %s" % [anim])
	var actor: Variant
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

## Sets any Vector [param property] of any actor. 
## [param args\[0\]] is the actor name.
## [param args[1..]] are the vector values (between 2 and 4). If only 1 value is passed, it will set the same value on all axes.
func setNodeVector(node, property, args) -> Status:
	var setProperty = "set_%s" % [property.get_slice("/",1)]
	var vec = node.call("get_%s" % [property.get_slice("/",1)])
	match len(args):
		1: 
			match typeof(vec):
				TYPE_VECTOR2: node.call(setProperty, Vector2(args[0], args[0]))
				TYPE_VECTOR3: node.call(setProperty, Vector3(args[0], args[0], args[0]))
				TYPE_VECTOR4: node.call(setProperty, Vector4(args[0], args[0], args[0], args[0]))
		2:
			node.call(setProperty, Vector2(args[0], args[1]))
		3:
			node.call(setProperty, Vector3(args[0], args[1], args[2]))
		4:
			node.call(setProperty, Vector4(args[0], args[1], args[2], args[3]))
		_:
			return Status.error("callActorMethodWithVector xpected between 1 and 4 arguments, received: %s" % [len(args.slice(1))])
	return Status.ok(true, "Called %s.%s(Vector%d(%s))" % [node.get_name(), property, args.slice(1)])

func setActorVector(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	return setNodeVector(result.value, property, args.slice(1))

func setAnimationVector(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Offset/Animation")
	return setNodeVector(animation, property, args.slice(1))

## Sets the value for the N axis of any Vector [param property] (position, scale, ...) of any actor.
## For example: /position/x would set the [method actor.get_position().x] value.
## [param args\[0\]] is the actor name.
## [param args[1]] is the value.
func setActorVectorN(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var vec = actor.call("get_" + property.get_slice("/", 1).to_snake_case())
	var axis = property.get_slice("/", 2).to_snake_case()
	var value = float(args[1])
	match axis:
		"x": vec.x = value
		"y": vec.y = value
		"z": vec.z = value
		"r": vec.r = value
		"g": vec.g = value
		"b": vec.b = value
		"a": vec.a = value
	actor.call("set_" + property.get_slice("/", 1).to_snake_case(), vec)
#	Log.debug("Set %s %s -- %s: %s" % [property, actor.get_position(), vec, value])
	return Status.ok("Set %s.%s: %s" % [vec, axis, value])

func setActorProperty(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	property = "set_" + property.substr(1).replace("/", "_").to_lower()
	var value = args[1]
	actor.call(property, value)
	return Status.ok(true, "Set %s.%s: %s" % [actor.get_name(), property, value])
	
func setAnimationProperty(property, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	var animation = actor.get_node("Offset/Animation")
	property = "set_" + property.substr(1).replace("/", "_").to_lower()
	var value: Variant = args.slice(1)
	animation.callv(property, value)
	return Status.ok(true, "Set %s.%s.%s: %s" % [actor.get_name(), animation.get_animation(), property, value])

func callActorMethod(method, args) -> Status:
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	method = method.substr(1)
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
	var animation = actor.get_node("Offset/Animation")
	method = method.substr(1).replace("/", "_").to_lower()
	args = args.slice(1)
	if len(args) == 0:
		result = animation.call(method)
	else:
		result = animation.callv(method, args)
	return Status.ok(result, "Called %s.%s.%s(%s): %s" % [actor.get_name(), animation.get_animation(), method, args, result])

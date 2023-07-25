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

var status := preload("res://Status.gd")
var metanode := preload("res://meta_node.tscn")
@onready var main := get_parent()
@onready var actorsNode := main.get_node("Actors")
var animationsLibrary: SpriteFrames ## The meta node containing these frames needs to be initialized in _ready
var assetsPath = "user://assets"
var animationAssetsPath = assetsPath + "/animations"

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
	"/load": loadAnimationAsset,
	"/assets/list": listAnimationAssets, # available in disk
	"/animations/list": listAnimations, # loaded
	"/actors/list": listActors,
	"/create": createActor,
	"/remove": removeActor,
	"/free": "/remove",
}
## Node commands map.
## Node commands are parsed differently than [param coreCommands]. They use 
## OSC address as method name (by removing the forward slash), and first argument is
## usually the actor's name (the node's name).
## Using meta methods filtered by parameter types allows to automatically map a lot
## of OSC messages to a few actual GDScript functions and methods.
## Keep in mind, though, that the command (OSC address) has to have the same signature as
## the expected GDScript method. If a different command name is needed, use a [method def].
## To expose new methods or properties, just replace the snake_case underscore in the method for
## a slash '/' in the osc command.
var nodeCommands: Dictionary = {
	"/animation": setAnimationProperty,
	"/play": callAnimationMethod,
	"/play/backwards": callAnimationMethod,
	"/reverse": "/play/backwards",
	"/animation/loop": setAnimationFramesProperty,
	"/stop": callAnimationMethod,
	"/frame": setAnimationProperty,
	"/frame/progress": setAnimationProperty,
	"/speed/scale": setAnimationProperty,
	"/speed": "/speed/scale",
	"/flip/v": setAnimationProperty,
	"/flip/h": setAnimationProperty,
	"/offset": setAnimationPropertyWithVector,
	"/offset/x": setAnimationPropertyWithVectorN,
	"/offset/y": setAnimationPropertyWithVectorN,
	"/scale": setActorPropertyWithVector,
	"/scale/x": setActorPropertyWithVectorN,
	"/scale/y": setActorPropertyWithVectorN,
	"/apply/scale": callActorMethodWithVector,
	"/set/position": callActorMethodWithVector,
	"/position/x": setActorPropertyWithVectorN,
	"/position/y": setActorPropertyWithVectorN,
	"/rotation": "/rotation/degrees",
	"/rotation/degrees": setActorProperty,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	var animationsLibraryNode = AnimatedSprite2D.new()
	animationsLibraryNode.set_sprite_frames(SpriteFrames.new())
	animationsLibrary = animationsLibraryNode.get_sprite_frames()
	main.add_child.call_deferred(animationsLibraryNode)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func reportError(msg: String, _sender = null):
	Log.error(msg)

func reportStatus(msg: String, sender = null):
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
	return false if main.get_node("Actors").find_child(actorName) == null else true

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
	reportStatus(variables[varName][0], null)
	return Status.ok(variables[varName][0])

func getCommand(command: String) -> Status:
	var value = coreCommands[command] if coreCommands.has(command) else null
	if value == null: Status.error("Command '%s' not found" % [command])
	return Status.ok(value, "Command found '%s': %s" % [command, value])

## Remove the [param key] and its value from [param dict]
func remove(key, dict) -> Status:
	if variables.has(key): 
		variables.erase(key)
		reportStatus("Removed '%s' from %s" % [key, dict], null)
		return Status.ok(null, "Removed '%s' from %s" % [key, dict])
	else:
		return Status.error("Key not found in %s: '%s'" % [dict, key])

## List contents of [param dict]
func _list(dict: Dictionary) -> Status:
	var list := []
	var msg := ""
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

func loadAnimationAsset(assetName: String) -> Status:
	var path = animationAssetsPath.path_join(assetName)
	Log.debug("TODO: load sprites and image sequences from disk: %s" % [path])
	var result = loadImageSequence(path)
	if result.isError(): return Status.error("Assets not found: %s" % [path])
	return Status.ok(true)

func loadImageSequence(path: String) -> Status:
	var filenames := DirAccess.get_files_at(path)
	var animName := path.get_basename().split("/")[-1]
	if animationsLibrary.has_animation(animName):
		return Status.error("Animation already loaded: '%s'" % [animName])
	animationsLibrary.add_animation(animName)
	for file in filenames:
		if file.ends_with(".png"):
#			Log.debug("Loading img to '%s': %s" % [animName, path.path_join(file)])
			var texture := loadImage(path.path_join(file))
			animationsLibrary.add_frame(animName, texture)
	
	return Status.ok(true, "Loaded %s frames: %s" % [animationsLibrary.get_frame_count(animName), animName])

func loadImage(path: String) -> ImageTexture:
	Log.verbose("Loading image: %s" % [path])
	var img = Image.load_from_file(path)
	var texture = ImageTexture.create_from_image(img)
	return texture

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
	Log.debug("TODO Add anim to actor on creation '%s': %s" % [actorName, anim])
	if not animationsLibrary.has_animation(anim):
		return Status.error("Animation not found: %s" % [anim])
	var actor: Variant
	var msg: String
	var result = getActor(actorName)
	Log.debug(result.msg)
	if result.value != null:
		actor = getActor(actorName).value
		msg = "Actor already exists: %s\n" % [actor]
		msg += "Setting new animation: %s" % [anim]
	else:
		actor = metanode.instantiate()
		msg = "Created new actor '%s': %s" % [actorName, anim]
	Log.debug(msg)
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
	var axis = property.get_slice("/", 2).to_snake_case()
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
	return callActorMethod("/set" + property, args)

func setAnimationProperty(property, args) -> Status:
	return callAnimationMethod("/set" + property, args)

func setAnimationFramesProperty(property, args) -> Status:
	return callAnimationFramesMethod("/set" + property, args)

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
	var result = getActor(args[0])
	if result.isError(): return result
	var actor = result.value
	return callMethodWithVector(actor, method, args.slice(1))

func callMethodWithVector(object: Variant, method: String, args: Array) -> Status:
	method = method.substr(1) if method.begins_with("/") else method
	method = method.replace("/", "_").to_lower()
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
	

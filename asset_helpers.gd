extends Node

var spriteFilenameRegex : RegEx
var sequenceFilenameRegex : RegEx

func _ready():
	spriteFilenameRegex = RegEx.new()
	spriteFilenameRegex.compile("(.+?)(?:_(\\d+)dir)?_(\\d+)x(\\d+)_(\\d+)fps")
	sequenceFilenameRegex = RegEx.new()
	sequenceFilenameRegex.compile("(.+)_(\\d+)fps")

############################################################
# Helpers
############################################################
static func getAssetBaseName(fileName: String) -> String:
	var baseName := fileName.get_basename()
	var split := baseName.split("_", false, 1)
	if !split.is_empty(): baseName = split[0]
	return baseName


static func getAnimSequenceFrames(path: String) -> Array:
	var dir := DirAccess.open(path)
	var frames := []
	if dir:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename and !dir.current_is_dir():
			if filename.ends_with(".png") or filename.ends_with(".jpg"):
				frames.push_back(filename)
			filename = dir.get_next()
	frames.sort()
	return frames


static func getAssetFilesMatching(path: String, nameWildcard: String) -> Dictionary:
	var dir := DirAccess.open(path)
	var files := { sprites = [], seqs = [] }
	if dir:
		dir.list_dir_begin()
		var filename := dir.get_next()
		while filename:
			var fullPath := path.path_join(filename)
			if dir.current_is_dir():
				var baseFile := getAssetBaseName(filename)
				if baseFile.match(nameWildcard):
					var seqFrames := getAnimSequenceFrames(fullPath);
					if !seqFrames.is_empty():
						Log.info("Sequence (%d frames) file name: %s" % [seqFrames.size(), filename])
						files.seqs.push_back(fullPath)
			elif filename.ends_with(".png") or filename.ends_with(".jpg"):
				var baseFile := getAssetBaseName(filename)
				if baseFile.match(nameWildcard):
					Log.info("File name: %s" % [filename])
					files.sprites.push_back(fullPath)
			filename = dir.get_next()
	return files


static func getExternalTexture(path: String) -> Texture2D:
	var img := Image.new()
	img.load(path)
	var texture := ImageTexture.new()
	# We don't want interpolation or repeats here
	texture.create_from_image(img) # used to use: Texture.FLAG_MIPMAPS
	return texture

func getSpriteFileInfo(name: String) -> Dictionary:
	var dict := {}
	var result := spriteFilenameRegex.search(name)
	if result:
		dict.name = result.get_string(1)
		dict.directions = 1 if result.get_string(2).is_empty() else result.get_string(2).to_int()
		dict.xStep = result.get_string(3).to_int()
		dict.yStep = result.get_string(4).to_int()
		dict.fps = result.get_string(5).to_int()
		Log.debug(dict)
	else:
		dict.name = name
		dict.directions = 1
		dict.xStep = 1
		dict.yStep = 1
		dict.fps = 0
	return dict


func getSeqFileInfo(name: String) -> Dictionary:
	var dict := {}
	var result := sequenceFilenameRegex.search(name)
	if result:
		dict.name = result.get_string(1)
		dict.fps = result.get_string(2).to_int()
		Log.debug(dict)
	else:
		dict.name = name
		dict.fps = 24
	return dict


# Add directions or actions from a spritesheet that may contain several
# NOTE: Currently assumes there are equal numbers of sprites per sub-action,
#       and does not support offsets or anything more flexible.
func addSubSprites(animFramesLibrary: SpriteFrames, atlas: Texture2D, suffixes: Array[String], info: Dictionary) -> void:
	var totalFrames : int = info.xStep * info.yStep
	var subFrames : int = totalFrames / info.directions
	assert(suffixes.size() == info.directions)
	var width : int = atlas.get_size().x / info.xStep
	var height : int = atlas.get_size().y / info.yStep
	for suffix in suffixes:
		var animName : String = info.name + suffix
		animFramesLibrary.remove_animation(animName)
		animFramesLibrary.add_animation(animName)
		animFramesLibrary.set_animation_speed(animName, info.fps)
	var frameId := 0
	for y in range(0, info.yStep):
		for x in range(0, info.xStep):
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(width * x, height * y, width, height)
			texture.margin = Rect2(0, 0, 0, 0)
			var subAnim := frameId / subFrames
			var animName : String = info.name + suffixes[subAnim]
			animFramesLibrary.add_frame(animName, texture, frameId % subFrames)
			frameId += 1


func loadSprites(animFramesLibrary: SpriteFrames, sprites: Array[String]) -> void:
	Log.debug("Runtime sprites: %s" % [sprites])
	# Add the runtime-loaded sprites to our pre-existing library
	for spritePath in sprites:
		var res : Texture2D
		# res = load(spritePath)
		if !res: res = getExternalTexture(spritePath)
		if res:
			var info = getSpriteFileInfo(spritePath.get_file().get_basename())
			if info.directions == 8:
				var dirSuffixes = ["-s", "-se", "-e", "-ne", "-n", "-nw", "-w", "-sw"]
				addSubSprites(animFramesLibrary, res, dirSuffixes, info)
			else:
				addSubSprites(animFramesLibrary, res, [""], info)


func loadSequences(animFramesLibrary: SpriteFrames, sequences: Array[String]):
	Log.debug("Runtime sequences: %s" % [sequences])
	# Add the runtime-loaded image sequences to our pre-existing library
	for seqPath in sequences:
		var info := getSeqFileInfo(seqPath.get_file().get_basename())
		animFramesLibrary.remove_animation(info.name)
		animFramesLibrary.add_animation(info.name)
		animFramesLibrary.set_animation_speed(info.name, info.fps)
		var frameId := 0
		for img in getAnimSequenceFrames(seqPath):
			var texture := getExternalTexture(seqPath + "/" + img)
			if texture:
				var width := texture.get_size().x
				var height := texture.get_size().y
				animFramesLibrary.add_frame(info.name, texture, frameId)
				frameId += 1

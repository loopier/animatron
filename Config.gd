class_name Config

signal load_config(filename)

const defaultConfigDir = "user://config"
static var assetsPath := "user://assets"
static var allowRemoteClients := true

func _init():
	Log.info("User data dir: %s" % [OS.get_user_data_dir()])

func loadConfig(path) -> Status:
	var configFile = Helper.getPathWithDefaultDir(path, defaultConfigDir)
	load_config.emit(configFile)
	return Status.ok(configFile, "Loaded config from: %s" % [configFile])

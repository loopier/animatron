class_name Log
extends Node

enum {
	LOG_LEVEL_FATAL,
	LOG_LEVEL_ERROR,
	LOG_LEVEL_WARNING,
	LOG_LEVEL_INFO,
	LOG_LEVEL_DEBUG,
	LOG_LEVEL_VERBOSE,
} 

const levelNames := ["FATAL", "ERROR", "WARNING", "INFO", "DEBUG", "VERBOSE"]

static var level: int = LOG_LEVEL_INFO: set = setLevel, get = getLevel

static var target: TextEdit: set = setTarget

static func setTarget( inTarget ):
	target = inTarget

static func setLevel( inLevel ):
	level = inLevel
	logMsg("Log level set to: %s" % [levelNames[level]])

static func getLevel():
	return level

static func getLevelName() -> String:
	return levelNames[level]

static func setLevelFatal():
	setLevel(LOG_LEVEL_FATAL)

static func setLevelError():
	setLevel(LOG_LEVEL_ERROR)

static func setLevelWarning():
	setLevel(LOG_LEVEL_WARNING)

static func setLevelInfo():
	setLevel(LOG_LEVEL_INFO)

static func setLevelDebug():
	setLevel(LOG_LEVEL_DEBUG)

static func setLevelVerbose():
	setLevel(LOG_LEVEL_VERBOSE)

static func fatal( msg ):
	logMsg("[FATAL]: %s" % [msg], true)

static func error( msg ):
	if level < LOG_LEVEL_ERROR:
		return
	logMsg("[ERROR]: %s" % [msg], true)

static func warn( msg ):
	if level < LOG_LEVEL_WARNING:
		return
	logMsg("[WARNING]: %s" % [msg], true)

static func info( msg ):
	if level < LOG_LEVEL_INFO:
		return
	logMsg("[INFO]: %s" % [msg], true)

static func debug( msg ):
	if level < LOG_LEVEL_DEBUG:
		return
	logMsg("[DEBUG]: %s" % [msg])

static func verbose( msg ):
	if level < LOG_LEVEL_VERBOSE:
		return
	logMsg("[VERBOSE]: %s" % [msg])

static func logMsg( msg, post=false ):
	print(msg)
	if target != null and post:
		target.append(msg)

static func logDict( dict, post=false ):
	for key in dict:
		logMsg("%s:%s" % [key, dict[key]], post)

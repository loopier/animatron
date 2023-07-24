class_name MetaNode
extends CharacterBody2D

var stateMachine: Dictionary
var frameCmds: Dictionary
var finishCmds: Dictionary
var isVisibleEnd: bool = true:
	set(value): isVisibleEnd = value
	get: return isVisibleEnd
var frameCmdsIndex = 0
# frame that triggers the next command in the frameCmds
var trigFrame = 0
@onready var main := get_parent().get_parent()
@onready var animationsLibrary: SpriteFrames = main.find_child("animationsLibraryNode").get_sprite_frames()

func _ready():
	var animNode = get_node("Offset/Animation")
	animNode.frame_changed.connect(_on_Animation_frame_changed)
	animNode.animation_finished.connect(_on_Animation_animation_finished)

func _on_Animation_frame_changed():
	main = get_parent()
	if main == null:
		return
	main = main.get_parent()
	var anim = get_node("Offset/Animation").get_animation()
	var frame = get_node("Offset/Animation").get_frame()
	if frameCmds.has(frame):
		sendCmds(frame)

func _on_Animation_animation_finished():
	for cmd in finishCmds:
		main.evalOscCommand(finishCmds[cmd][0], finishCmds[cmd].slice(1,-1), null)
	
	set_visible(isVisibleEnd)
	nextState()

func resetFrameCmds():
	frameCmdsIndex = 0

func addCmdToFrameCmds( inframe, cmd ):
	var anim = get_node("Offset/Animation").get_animation()
#	print("%s:%s %s:%s" % [typeof frame, frame, typeof cmd, cmd])
	var numframes = get_node("Offset/Animation").get_sprite_frames().get_frame_count(anim)
#	print("%s/%s: %s %s" % [inframe, numframes, cmd, anim])
	trigFrame = int(inframe) % numframes
	
	var key = getKey(cmd)
	if frameCmds.has(trigFrame):
		frameCmds[trigFrame][key] = cmd
	else:
		frameCmds[trigFrame] = {key: cmd}
	
	print("add cmd to frameCmds on frame %d: %s" % [trigFrame, cmd])
	print(frameCmds)
	return frameCmds

func removeCmdFromFrameCmds( inframe, cmd ):
	print("remove cmd for frame %s: %s" % [inframe, cmd])
	var reply
	var key = getKey(cmd)
	inframe = int(inframe)
	
	if frameCmds.has(inframe):
		frameCmds[inframe].erase(key)
		reply = frameCmds[inframe]
		if len(frameCmds[inframe]) == 0:
			frameCmds.erase(inframe)
	else:
		# TODO: change to send '/report/error'
		reply = "Command not found in trigger frame %d: %s" % [inframe, cmd]
	print(reply)
	return reply

func addFinishCmd( cmd ):
	var key = getKey(cmd)
	finishCmds[key] = cmd
	print("add onfinish cmd: %s : %s" % [key, cmd])
	print("on finish: ", finishCmds)

func removeFinishCmd( cmd ):
	print(cmd)
	var key = getKey(cmd)
	if finishCmds.has(key):
		finishCmds.erase(key)
	print("remove  cmd: %s : %s" % [key, cmd])
	print("on finish: ", finishCmds)

func getFrameCmds():
	return frameCmds

func getKey( cmd ):
	if len(cmd) > 1:
		return "%s/%s" % [cmd[0], cmd[1]]
	return cmd[0]

func sendCmds( inframe ):
	for cmd in frameCmds[inframe]:
		var addr = frameCmds[inframe][cmd][0]
		var args = frameCmds[inframe][cmd].slice(1,-1)
		main.evalOscCommand(addr, args, null)

func listFrameCmds():
	print("frame commands for %s:\n%s" % [name,frameCmds])
	print("finish commands for %s:\n%s" % [name,finishCmds])

func setVisibleEnd(visible):
	isVisibleEnd = visible

func listStates():
	Log.info("State machine: %s" % [name])
	for state in stateMachine:
		Log.info("%s : %s" % [state, stateMachine[state]])

func addState(newState, nextStates):
	stateMachine[newState] = nextStates if nextStates is Array else [nextStates]
	listStates()

func removeState(state):
	stateMachine.erase(state)

func nextState():
	var animNode = get_node("Offset/Animation")
	var anim = animNode.get_animation()
	if not stateMachine.has(anim):
		return
	var nextPossibleStates = stateMachine[anim]
	var nextState = nextPossibleStates[ randi() % nextPossibleStates.size() ]
	animNode.set_animation(nextState)
	Log.verbose("changing '%s' state from: %s to: %s" % [name, anim, nextState])

class_name StateMachine

signal state_changed(cmd: Array)

var name := ""
var current := ""
var states := {}
static var stateDefs := {}

static func defineState(name: String, entry: String, exit: String):
	StateMachine.stateDefs[name] = {"entry": entry, "exit": exit}

func addState(state: String, next: Array):
	if isEmpty(): current = state
	states[state] = next
	Log.verbose("%s -- Add state: %s %s" % [name, state, next])

func removeState(state: String):
	# There's no wildcard matching for dictionaries, we need it to do it manually
	for key in states.keys():
		if key.match(state):
			Log.verbose("%s -- Remove state: %s" % [name, state])
			states.erase(state)

## FIX: return status or send OSC message or emit signal
func next():
	var nextIndex = randi() % len(states[current])
	var nextState = states[current][nextIndex]
	if not states.has(nextState):
		Log.error("%s(%s) -- State not found: %s" % [name, current, nextState])
		return
	Log.debug("%s(%s) -- Next state: %s" % [name, current,  nextState])
	Log.debug("%s(%s) -- Exit def: %s" % [name, current,  stateDefs[current].exit])
	Log.debug("%s(%s) -- Entry def: %s" % [name, nextState,  stateDefs[nextState].exit])
	state_changed.emit([stateDefs[current].exit])
	state_changed.emit([stateDefs[nextState].entry])
	current = nextState

func isEmpty() -> bool:
	return states.is_empty()

func list() -> String:
	var statesList := ""
	var stateNames := states.keys()
	stateNames.sort()
	for state in stateNames:
		statesList = "%s\n%s: %s" % [statesList, state, states[state]]
	return statesList

func status() -> String:
	return current

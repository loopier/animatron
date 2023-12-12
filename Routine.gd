class_name Routine
extends Timer

# This is not the code for the Main.Routines node.
# Main.Routines holds different instances of this script, which is a
# single routine.

var command := []
var lastCommand := []
@onready var repeats := 0
@onready var iteration := 0
@onready var callOnNext : Callable

func _ready():
	wait_time = 1.0
	timeout.connect(_on_timeout)

func _on_timeout():
	next()

func next():
	#Log.verbose("Timeout %s:%s %s" % [name, iteration, command])
	if repeats > 0 and iteration >= repeats:
		if len(lastCommand) > 0:
			stop()
			reset()
			callOnNext.call(lastCommand, "ROUTINE")
		return
	callOnNext.call(command, "ROUTINE")
	iteration = iteration + 1

func _exit_tree():
	timeout.disconnect(_on_timeout)

func reset():
	iteration = 0

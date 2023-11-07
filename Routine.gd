extends Timer

# This is not the code for the Main.Routines node.
# Main.Routines holds different instances of this script, which is a
# single routine.

signal eval_command(command)
signal routine_finished(command)

var command := []
@onready var repeats := 0
@onready var iteration := 0
@onready var main := get_parent().get_parent()

func _ready():
	wait_time = 1.0
	timeout.connect(_next)
	eval_command.connect(main.evalCommands)
	routine_finished.connect(main._on_routine_finished)

func _next():
	Log.debug("Timeout %s:%s %s" % [name, iteration, command])
	if repeats > 0 and iteration >= repeats:
		routine_finished.emit(name)
		return
	eval_command.emit(command)
	iteration = iteration + 1

func _exit_tree():
	timeout.disconnect(_next)
	eval_command.disconnect(main.evalCommands)
	routine_finished.disconnect(main._on_routine_finished)

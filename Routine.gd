class_name Routine
extends Timer

# This is not the code for the Main.Routines node.
# Main.Routines holds different instances of this script, which is a
# single routine.

signal eval_command(command, sender)
signal routine_finished(command)

var command := []
@onready var repeats := 0
@onready var iteration := 0
@onready var main := get_parent().get_parent()

func _ready():
	wait_time = 1.0
	timeout.connect(_on_timeout)
	eval_command.connect(main.evalCommand)
	routine_finished.connect(main._on_routine_finished)

func _on_timeout():
	next()

func next():
	#Log.verbose("Timeout %s:%s %s" % [name, iteration, command])
	if repeats > 0 and iteration >= repeats:
		routine_finished.emit(name)
		return
	eval_command.emit(command, "ROUTINE")
	iteration = iteration + 1

func _exit_tree():
	timeout.disconnect(_on_timeout)
	eval_command.disconnect(main.evalCommands)
	routine_finished.disconnect(main._on_routine_finished)

func reset():
	iteration = 0

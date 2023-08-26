extends Timer

# This is not the code for the Main.Routines node.
# Main.Routines holds different instances of this script, which is a
# single routine.

signal eval_command(command)

var command := []
@onready var repeats = 0
@onready var iteration = 0

func _ready():
	wait_time = 1.0
	timeout.connect(_next)
	var main = get_parent().get_parent()
	eval_command.connect(main._on_eval_command)

func _next():
#	Log.debug("Timeout %s:%s %s" % [name, iteration, command])
	eval_command.emit(command)

func _exit_tree():
	timeout.disconnect(_next)

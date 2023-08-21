extends Timer

# This is not the code for the Main.Routines node.
# Main.Routines holds different instances of this script, which is a
# single routine.

var command := []
@onready var repeats = 0
@onready var iteration = 0

func _ready():
	wait_time = 1.0
	timeout.connect(_next)

func _next():
	Log.debug("Timeout %s:%s %s" % [name, iteration, command])

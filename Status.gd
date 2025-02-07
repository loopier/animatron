class_name Status
## All methods that are mapped from OSC messages must return an instance of this class,
## in order to determine wether it has succeeded of failed.

enum { NULL = -1, ERROR = 0, OK = 1 , WARNING = 2}

var type: int
var value: Variant
var msg: String

func _init(inType: int = Status.NULL, inValue: Variant = null, inMsg: String = ""):
	type = inType
	value = inValue
	msg = inMsg

static func ok( inValue: Variant = true, inMsg: String = "" ) -> Status:
	return Status.new(Status.OK, inValue, inMsg)

static func error(inMsg: String = "") -> Status:
	return Status.new(Status.ERROR, null, inMsg)

static func warning(inMsg: String = "") -> Status:
	return Status.new(Status.WARNING, null, inMsg)

func isOk() -> bool:
	return type == Status.OK

func isError() -> bool:
	return type == Status.ERROR

func isWarning() -> bool:
	return type == Status.WARNING

## All methods that are mapped from OSC messages must return an instance of this class,
## in order to determine wether it has succeeded of failed.
class_name Status


const ERROR := 0
const OK := 1

var type:
	get: 
		return type
	set(inType): 
		type = inType
var value:
	get: 
		return value
	set(inValue): 
		value = inValue

var msg: String:
	get: 
		return msg
	set(inMsg): 
		msg = inMsg

func _init(inType: int, inValue: Variant, inMsg: String = ""):
	type = inType
	value = inValue
	msg = inMsg

static func ok( value: Variant = true, msg: String = "" ) -> Status:
	return Status.new(Status.OK, value, msg)

static func error(msg: String = "") -> Status:
	return Status.new(Status.ERROR, null, msg)

func isOk() -> bool:
	return type == Status.OK

func isError() -> bool:
	return type == Status.ERROR

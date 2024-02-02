class_name VariablesManager

## A [class Dictionary] used to store variables accessible from OSC messages.
static var animatronVariables = {
	"time": func(): return Time.get_ticks_msec() * 1e-3,
	"rnd": RandomNumberGenerator.new(),
}
static var userVariables := {}

func _init():
	pass

static func getAll() -> Dictionary:
	# avoid overriding default variables
	var all := {}
	for key in animatronVariables:
		var value = animatronVariables[key]
		if typeof(value) == TYPE_CALLABLE: value = value.call()
		all[key] = value
	# 'animatronVariables' won't be overriden by 'userVariables'
	all.merge(userVariables)
	return all

static func getValue(variableName: String) -> Variant:
	var all := getAll()
	var value: Variant
	if not all.has(variableName): return null
	return all[variableName]

static func setValue(variableName: String, value: Variant):
	userVariables[variableName] = value

static func unsetValue(variableName: String):
	userVariables.erase(variableName)

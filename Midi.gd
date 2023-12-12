class_name Midi
extends Node

signal noteon(ch, num, velocity)
signal noteoff(ch, num, velocity)
signal cc(ch, num, value)

@onready var debug := false

func _ready():
	OS.open_midi_inputs()
	Log.info("MIDI devices: %s" % [OS.get_connected_midi_inputs()])
	set_process_unhandled_input(true)

func _input(event):
	if event is InputEventMIDI:
		if debug: _print_midi_info(event)
		var ch = event.channel
		var msg = event.message
		var num = 0
		var value = 0
		match msg:
			MIDI_MESSAGE_NOTE_ON:
				noteon.emit(ch, event.pitch, event.velocity)
			MIDI_MESSAGE_NOTE_OFF:
				noteoff.emit(ch, event.pitch, event.velocity)
			MIDI_MESSAGE_CONTROL_CHANGE:
				cc.emit(ch, event.controller_number, event.controller_value)

func _print_midi_info(midi_event: InputEventMIDI):
	print(midi_event)
	#print("Channel " + str(midi_event.channel))
	#print("Message " + str(midi_event.message))
	#print("Pitch " + str(midi_event.pitch))
	#print("Velocity " + str(midi_event.velocity))
	#print("Instrument " + str(midi_event.instrument))
	#print("Pressure " + str(midi_event.pressure))
	#print("Controller number: " + str(midi_event.controller_number))
	#print("Controller value: " + str(midi_event.controller_value))

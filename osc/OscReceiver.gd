class_name OscReceiver
extends Node2D

class OscMessage:
	var addr: String
	var args: Array
	var semder: String # IP

signal osc_msg_received(addr, args, sender)

var socketUdp: PacketPeerUDP = PacketPeerUDP.new()
var senderIP: String
enum {OSC_ARG_TYPE_NULL, OSC_ARG_TYPE_FLOAT=102, OSC_ARG_TYPE_INT=105, OSC_ARG_TYPE_STRING=115}
var observers: Dictionary = Dictionary()

# osc server
var serverPort: int = 56101 :
	get: return serverPort
	set(port): serverPort = port

func _ready():
	pass

func startServer():
	var err = socketUdp.bind(serverPort)
	if err != 0:
		Log.error("OSC ERROR while trying to listen on port: %s" % [serverPort])
	else:
		Log.info("OSC server listening on port: %s" % [socketUdp.get_local_port()])

func startServerOn(listenPort):
	serverPort = listenPort
	startServer()	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if socketUdp.get_available_packet_count() > 0:
		var msg = parseOsc(socketUdp.get_packet())
		var sender = socketUdp.get_packet_ip()
		osc_msg_received.emit(msg.addr, msg.args, sender)
		Log.verbose("OSC message received from '%s': %s %s" % [socketUdp.get_packet_ip(), msg.addr, msg.args])
#	print(sockestUdp.get_available_packet_count())
#	print(socketUdp.get_local_port())
	pass

func _exit_tree():
	socketUdp.close()
#	thread.wait_to_finish()

func setServerPort(port):
	serverPort = port
func getServerPort() -> int:
	return serverPort

func parseOsc(packet):
	var buf = StreamPeerBuffer.new()
	buf.set_data_array(packet)
	buf.set_big_endian(true)
	var addr := getString(buf)
	# move the cursor to the beginning of the argument types string fs
	buf.seek(getArgTypesIndex(buf))
	var start := buf.get_position()
	# get the types
	var types := getString(buf)
	# skip the leading ','
	var typeIndex := 1
	# get the current type
	var type := types.substr(typeIndex,1)
	# get the last position of the type string
	var end := buf.get_position()
	# move the cursor to the next byte if the current one is not a multiple of 4
	var next := end if end % 4 == 0 else end + 4 - (end % 4)
	buf.seek(next)
	# parse the arguments
	var args := []
	for i in buf.get_size():
		type = types.substr(typeIndex, 1)
		match type:
			"i": args.append(getInt(buf))
			"f": args.append(getFloat(buf))
			"s": args.append(getString(buf))
			_: continue
		typeIndex += 1
#		print("OSC arg %s: %s(%s)" % [i, args.back(), type])
	
	var msg = OscMessage.new()
	msg.addr = addr
	msg.args = args
	
	return msg

func getString(buf) -> String:
	var str := ""
	for i in buf.get_size():
		var c = buf.get_u8()
		# keep moving the cursor until the next multiple of 4
		if c == 0 and buf.get_position() % 4 == 0: break
		str += char(c)
	return str

func getFloat(buf) -> float:
	return buf.get_float()
	
func getInt(buf) -> int:
	return buf.get_32()
	
# osc messages define the arg types in a byte = 44 (,)
func getArgTypesIndex(buf) -> int:
	return buf.get_data_array().find(",".to_ascii_buffer()[0])

func getArgs(buf: StreamPeerBuffer) -> Array:
	return []

#func _thread_function(userdata):
#	print("I'm a thread! Userdata is: ", userdata)

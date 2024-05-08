extends Node
class_name OscReceiver

class OscMessage:
	var addr: String
	var args: Array
	var semder: String # IP

signal osc_msg_received(addr: String, args: Array, sender: String)

var socketUdp := PacketPeerUDP.new()
var senderIP: String
var senderPort: int
enum {OSC_ARG_TYPE_NULL, OSC_ARG_TYPE_FLOAT=102, OSC_ARG_TYPE_INT=105, OSC_ARG_TYPE_STRING=115}
var observers: Dictionary = Dictionary()

# osc server
var serverPort: int = 56101 :
	get = getServerPort,
	set = setServerPort

var oscBuf := StreamPeerBuffer.new()
var oscArgBuf := StreamPeerBuffer.new()

func _ready():
	oscBuf.big_endian = true
	oscArgBuf.big_endian = true

func startServer():
	var err := socketUdp.bind(serverPort)
	if err != 0:
		Log.error("OSC ERROR while trying to listen on port: %s" % [serverPort])
	else:
		Log.info("OSC server listening on port: %s" % [socketUdp.get_local_port()])

func startServerOn(listenPort: int):
	serverPort = listenPort
	startServer()

# 'delta' is the elapsed time since the previous update.
func _physics_process(_delta):
	while socketUdp.get_available_packet_count() > 0:
		var msg := parseOsc(socketUdp.get_packet())
		var sender := "%s/%d" % [socketUdp.get_packet_ip(), socketUdp.get_packet_port()]
		Log.verbose("OSC message received from %s: %s %s" % [sender, msg.addr, msg.args])
		osc_msg_received.emit(msg.addr, msg.args, sender)

func _exit_tree():
	socketUdp.close()
#	thread.wait_to_finish()

func setServerPort(port: int):
	serverPort = port
func getServerPort() -> int:
	return serverPort

func parseOsc(packet: PackedByteArray) -> OscMessage:
	var buf := StreamPeerBuffer.new()
	buf.set_data_array(packet)
	buf.set_big_endian(true)
	var addr := getString(buf)
	# move the cursor to the beginning of the argument types string fs
	buf.seek(getArgTypesIndex(buf))
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
			"T": args.append(true)
			"F": args.append(false)
			"N": args.append(null)
			_: continue
		typeIndex += 1
#		print("OSC arg %s: %s(%s)" % [i, args.back(), type])
	
	var msg := OscMessage.new()
	msg.addr = addr
	msg.args = args
	
	return msg

func getString(buf: StreamPeer) -> String:
	var result := ""
	for i in buf.get_size():
		var c := buf.get_u8()
		# keep moving the cursor until the next multiple of 4
		if c == 0 and buf.get_position() % 4 == 0: break
		result += char(c)
	return result

func getFloat(buf: StreamPeer) -> float:
	return buf.get_float()
	
func getInt(buf: StreamPeer) -> int:
	return buf.get_32()
	
# osc messages define the arg types in a byte = 44 (,)
func getArgTypesIndex(buf: StreamPeer) -> int:
	return buf.get_data_array().find(",".to_ascii_buffer()[0])

func getArgs(_buf: StreamPeer) -> Array:
	return []

func addString(buf: StreamPeer, inStr: String):
	buf.put_data(inStr.to_ascii_buffer())
	var padding := 4 - inStr.length() % 4
	if padding == 4:
		buf.put_32(0)
	else:
		for i in range(padding):
			buf.put_8(0)

func sendMessage(target: String, oscAddr: String, oscArgs: Array):
	oscBuf.clear()
	oscArgBuf.clear()
	addString(oscBuf, oscAddr)
	var argTags := ","
	for arg in oscArgs:
		match typeof(arg):
			TYPE_FLOAT:
				argTags += "f"
				oscArgBuf.put_float(arg)
			TYPE_INT:
				argTags += "i"
				oscArgBuf.put_32(arg)
			TYPE_STRING, TYPE_STRING_NAME:
				argTags += "s"
				addString(oscArgBuf, arg)
			TYPE_BOOL:
				argTags += "T" if arg else "F"
			TYPE_NIL:
				argTags += "N"
			_:
				Log.error("Unsupported OSC type: %s" % typeof(arg))				

	addString(oscBuf, argTags)
	oscBuf.put_data(oscArgBuf.data_array)
	
	var addrPort := target.split("/")
	if addrPort.size() == 2:
		Log.verbose("Replying %s to %s/%s" % [oscAddr, addrPort[0], addrPort[1] as int])
		socketUdp.set_dest_address(addrPort[0], addrPort[1] as int)
		socketUdp.put_packet(oscBuf.data_array)

#func _thread_function(userdata):
#	print("I'm a thread! Userdata is: ", userdata)

extends AnimatedSprite2D

@onready var start_frame := 0
@onready var end_frame := 0
@onready var loop_mode: Animation.LoopMode

signal animation_finsihed(name)

# Called when the node enters the scene tree for the first time.
func _ready():
	set_end_frame(sprite_frames.get_frame_count(get_animation()))
	Log.verbose("%s:frame progress: %s" % [get_parent().name, frame_progress])

func _on_frame_changed():
	if is_playing and ((get_frame() == end_frame - 1 and get_speed_scale() > 0) or (get_frame() == start_frame and get_speed_scale() < 0)):
		if loop_mode == Animation.LOOP_PINGPONG:
			set_speed_scale(get_speed_scale() * -1)
			var dir = int(get_speed_scale() < 0) * 2 - 1
			frame = max(0, (frame + 1) * dir)
		animation_finished.emit(get_parent().name)
		
	if is_playing() and get_frame() > end_frame:
		set_frame(start_frame if get_speed_scale() > 0 else end_frame)
	elif is_playing() and get_frame() < start_frame: 
		set_frame(end_frame if get_speed_scale() < 0 else start_frame)

func _on_animation_changed():
	#set_frame_progress(0)
	#Log.verbose("%s:%s:frame progress: %s" % [get_parent().name, animation, frame_progress])
	##Log.verbose("%s:%s:speed: %s" % [get_parent().name, animation, speed_scale])
	#Log.verbose("%s:%s:animation speed: %s" % [get_parent().name, animation, sprite_frames.get_animation_speed(animation)])
	#Log.verbose("%s:%s:frames: %s" % [get_parent().name, animation, sprite_frames.get_frame_count(animation)])
	var progress = frame_progress
	var speed_scale = get_speed_scale()
	var anim_speed = sprite_frames.get_animation_speed(animation)
	#var frames = sprite_frames.get_frame_count(animation)
	#var current_frame = get_frame()
	#var current_progress = get_frame_progress()
	set_frame(0)
	set_frame_progress(0)
	pass

## Sets the lower value to [param start_frame] and the highest value to [param end_frame].
## This is done to be consistent in the playing speed.
func adjust_start_and_end_frames():
	var tmp = end_frame
	set_end_frame(start_frame)
	set_start_frame(tmp)

func adjust_speed_scale():
	if start_frame < end_frame:
		set_speed_scale(abs(get_speed_scale()))
	elif start_frame > end_frame: 
		adjust_start_and_end_frames()
		set_speed_scale(0 - abs(get_speed_scale()))

func set_start_frame(frame: int):
	start_frame = clamp(frame, 0, sprite_frames.get_frame_count(get_animation()) - 1)
	adjust_speed_scale()

func set_end_frame(frame: int):
	end_frame = clamp(frame, 0, sprite_frames.get_frame_count(get_animation()))
	if frame < 0: end_frame = sprite_frames.get_frame_count(get_animation())
	adjust_speed_scale()

func set_loop_mode(loopMode: int):
	self.loop_mode = loopMode

func next_frame():
	var numFrames = end_frame - start_frame
	var nextFrame = (frame + 1) % numFrames + start_frame
	self.set_frame(nextFrame)

func previous_frame():
	var numFrames = end_frame - start_frame
	var newFrame = frame - 1 if frame > 0 else end_frame
	self.set_frame(newFrame)

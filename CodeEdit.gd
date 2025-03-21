extends CodeEdit

signal eval_code(text: String)
signal font_size_changed(object: CodeEdit)

@onready var fontSize = get_theme_font_size("theme")
@onready var hl = get_syntax_highlighter() as CodeHighlighter
@onready var saveDialog: FileDialog
@onready var loadDialog: FileDialog

@onready var history = []
@onready var historyIndex = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	hl.add_color_region("#", "", Color(0.447059, 0.462745, 0.498039), true) # comment
	hl.add_color_region("/", " ", Color(0.95309376716614, 0.42354467511177, 0.50218969583511)) # osc address
	hl.add_color_region("$", " ", Color(0.97654688358307, 0.68245977163315, 0.44307622313499)) # variable

func _input(event):
	if event.is_action_pressed("eval_block"): 
		evalBlock()
		_ignoreEvent()
	if event.is_action_pressed("eval_line"): 
		evalLine()
		_ignoreEvent()
	if event.is_action_pressed("increase_editor_font"): 
		increaseFont()
		_ignoreEvent()
	if event.is_action_pressed("decrease_editor_font"): 
		decreaseFont()
		_ignoreEvent()
	if event.is_action_pressed("previous_command"):
		previousCommand()
		_ignoreEvent()
	if event.is_action_pressed("next_command"):
		nextCommand()
		_ignoreEvent()

func _ignoreEvent():
	get_parent().get_parent().get_parent().set_input_as_handled()

func evalText(inText):
	inText = inText.strip_edges()
	if inText.length() == 0:
		inText = getLastCommand()
	eval_code.emit(inText)
	deselect()
	updateHistory(inText)
	clearPrompt()
	
func evalLine():
	var ln = get_caret_line()
	#var col = get_caret_column()
	selectLine(ln)
	evalText(get_selected_text())

func evalBlock():
	if get_selected_text().is_empty():
		selectBlock()
	
	var blocks = get_selected_text().split("\n\n")
	for block in blocks:
		evalText(block)

func selectLine(line: int):
	select(line, 0, line, len(get_line(line)))

func selectBlock():
	var line := get_caret_line()
	var from := findPrevLinebreak(line)
	var to := findNextLinebreak(line)
	select(from, 0, to, len(get_line(to)))

func findPrevLinebreak(line: int) -> int:
	var ln = line
	while ln >= 0:
		ln = ln - 1
		if get_line(ln) == "": break
	return ln + 1

func findNextLinebreak(line: int) -> int:
	if get_line(line) == "": return line - 1
	var ln = line
	while ln < get_line_count():
		ln = ln + 1
		if get_line(ln) == "": break
	return ln - 1

func increaseFont():
	fontSize = get_theme_font_size("font_size") + 1
	add_theme_font_size_override("font_size", fontSize)
	font_size_changed.emit(self)

func decreaseFont():
	fontSize = get_theme_font_size("font_size") - 1
	add_theme_font_size_override("font_size", fontSize)
	font_size_changed.emit(self)

func append(inText: String):
	set_text("%s%s" % [get_text(), inText])
	set_caret_line(get_line_count())

func getFontSize() -> float:
	var size := self.get_theme_font_size("font size")
	var lineSpacing := 2.5 # not available as property :(
	return size * lineSpacing

func clearPrompt():
	set_placeholder(getLastCommand())
	clear()

func getLastCommand() -> String:
	if history.size() <= 0: return ""
	return history.back()

func updateHistory(cmd: String):
	if cmd == getLastCommand(): return
	history.append(cmd)
	# swap index of memorized command
	if historyIndex != history.size() - 1:
		history.remove_at(historyIndex)
	historyIndex = history.size()
	Log.debug(history)

func previousCommand():
	if history.size() <= 0: return
	historyIndex -= 1
	if historyIndex < 0: historyIndex = history.size() - 1
	var cmd : String = history[historyIndex]
	self.set_text(cmd)

func nextCommand():
	if history.size() <= 0: return
	historyIndex = abs(historyIndex + 1) % history.size()
	var cmd : String = history[historyIndex]
	self.set_text(cmd)

func _on_save_dialog_confirmed():
	Log.debug("save file confirmed: %s" % [saveDialog.current_path])
	saveFile(saveDialog.current_path)

func _on_load_dialog_confirmed():
	Log.debug("load file confirmed: %s" % [loadDialog.current_path])
	openFile(loadDialog.current_path)
	
func saveFile(path: String):
	Log.debug("saving text: %s" % [path])
	var file = FileAccess.open(path, FileAccess.WRITE)
	var content = get_text()
	file.store_string(content)
	file.close()

func openFile(path: String):
	Log.debug("appending text: %s" % [path])
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text(true)
	file.close()
	append(content)

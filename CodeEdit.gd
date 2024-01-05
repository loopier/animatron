extends CodeEdit

signal eval_code(text: String)

@onready var hl = get_syntax_highlighter() as CodeHighlighter

# Called when the node enters the scene tree for the first time.
func _ready():
	hl.add_color_region("#", "", Color(0.447059, 0.462745, 0.498039), true) # comment
	hl.add_color_region("/", " ", Color(0.95309376716614, 0.42354467511177, 0.50218969583511)) # osc address
	hl.add_color_region("$", " ", Color(0.97654688358307, 0.68245977163315, 0.44307622313499)) # variable

func _input(event):
	var line := get_caret_line()
	var col := get_caret_column()
	if event.is_action_pressed("eval_block"): 
		evalBlock()
		_ignoreEvent()
	if event.is_action_pressed("eval_line"): evalLine()
	if event.is_action_pressed("increase_editor_font"): 
		increaseFont()
		_ignoreEvent()
	if event.is_action_pressed("decrease_editor_font"): 
		decreaseFont()
		_ignoreEvent()

func _ignoreEvent():
	get_parent().get_parent().get_parent().set_input_as_handled()

func evalText(text):
	text = text.strip_edges()
	eval_code.emit(text)
	deselect()
	
func evalLine():
	var ln = get_caret_line()
	var col = get_caret_column()
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
	var fontSize = get_theme_font_size("font_size") + 1
	add_theme_font_size_override("font_size", fontSize)

func decreaseFont():
	var fontSize = get_theme_font_size("font_size") - 1
	add_theme_font_size_override("font_size", fontSize)

func append(text: String):
	set_text("%s\n%s" % [get_text(), text])
	set_caret_line(get_line_count())

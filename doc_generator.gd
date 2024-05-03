# create .adoc files from .ocl docstring comments

class_name DocGenerator

static func getTextFromFile(inputFilePath: String) -> Status:
	var file = FileAccess.open(inputFilePath, FileAccess.READ)
	if file == null: return Status.error("File not found: %s" % [inputFilePath])
	return Status.ok(file.get_as_text(true))

static func writeTextToFile(inputFilePath: String, text: String) -> Status:
	var file = FileAccess.open(inputFilePath, FileAccess.WRITE)
	if file == null: return Status.error("File not found: %s" % [inputFilePath])
	file.store_string(text)
	return Status.ok()

static func generateFrom(inputFilePath: String) -> Status:
	Log.verbose("Generating docs from: %s" % [inputFilePath])
	var contents = getTextFromFile(inputFilePath).value
	var textBlocks = getTextBlocks(contents).value
	var filename = inputFilePath.get_file().get_basename()
	var asciidocPath = "res://docs/%s.adoc" % [filename]
	var asciidoc = DocGenerator.formatAsciiDoc(textBlocks).value
	var result = writeTextToFile(asciidocPath, asciidoc)
	if result.isError(): return Status.error("Could not write helpf file: %s" % [inputFilePath])
	return Status.ok(true, "Help file successfully generated from: %s\nto: %s" % [inputFilePath, asciidocPath])

static func getTextBlocks(text: String) -> Status:
	var blocks := []
	var rex = RegEx.new()
	rex.compile("((#\\s*(.*)\\n)+(\\/def\\s.*\\n)*)")
	var result = rex.search_all(text)
	if result:
		blocks = result
	return Status.ok(blocks)

static func formatAsciiDoc(items: Array) -> Status:
	var asciidoc := ""
	for i in items.size():
		var lines = Array(items[i].get_string().split("\n"))
		var def = lines.pop_at(-2) # last element is an empty line that we want to keep
		lines.push_front(def)
		for ln in lines:
			ln = ln.replace("# ", "")
			ln = ln.replace("#", "")
			ln = ln.replace("/def ", "=== ")
			ln += "\n"
			asciidoc += ln
	return Status.ok(asciidoc)

## Find a [param def] in the [param text] and return its docstring
static func getDocString(text:String, def: String) -> Status:
	var rex = RegEx.new()
	rex.compile("((#\\s*(.*)\\n)+\\/def\\s.*\\/*%s.*)" % [def])
	#rex.compile(def)
	var result = rex.search(text)
	if result:
		var docstring = result.get_string()
		docstring = docstring.replace("# ", "")
		docstring = docstring.replace("#", "")
		docstring = docstring.replace("/def ", "")
		docstring = Array(docstring.split("\n"))
		var defstring = docstring.pop_at(-1) + "\n"
		docstring.push_front(defstring.strip_edges())
		docstring = "\n".join(docstring)
		return Status.ok(docstring)
	return Status.error("/def not found: %s" % [def])

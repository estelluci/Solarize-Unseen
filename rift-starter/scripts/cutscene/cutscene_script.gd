class_name CutsceneScript
extends RefCounted
## A parsed cutscene. Cutscenes are plain text files (res://cutscenes/*.cutscene)
## so writers can author them without touching code:
##
##     # comments start with #
##     camera Mafia 1.8
##     say Fairy "You nearly got swallowed by a portal."
##     move Mafia 300
##     if not flag met_fairy
##         set_flag met_fairy
##     else
##         say Mafia "We've met."
##     end
##
## One command per line: a command name, then arguments separated by spaces.
## Wrap arguments containing spaces in "double quotes" (\" for a quote inside).
## Indentation is ignored (but makes if/else blocks readable).
##
## Conditions:  if [not] flag <name> | upgrade <id> | eye <Solar|Lunar> | sight
## The available commands live in CutsceneCommands (cutscene_commands.gd).

const CONDITION_KINDS := ["flag", "upgrade", "eye", "sight"]

var source_name := ""
var commands: Array[Dictionary] = []   ## {cmd, args, line, ...}
var errors: PackedStringArray = []


func is_valid() -> bool:
	return errors.is_empty()


static func load_file(path: String, registry: Dictionary = {}) -> CutsceneScript:
	if not FileAccess.file_exists(path):
		var s := CutsceneScript.new()
		s.source_name = path
		s.errors.append("%s: file not found" % path)
		return s
	return parse(FileAccess.get_file_as_string(path), path, registry)


## Parse `text`. If `registry` (command name -> spec) is given, unknown
## commands and wrong argument counts are reported with line numbers.
static func parse(text: String, name := "<inline>", registry: Dictionary = {}) -> CutsceneScript:
	var s := CutsceneScript.new()
	s.source_name = name
	var stack: Array[int] = []   # indices of open `if`s
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var tokens := tokenize(line)
		if tokens.is_empty():
			s.errors.append("%s:%d: unterminated quote" % [name, line_no])
			continue
		var cmd := tokens[0].to_lower()
		var args: Array = Array(tokens.slice(1))
		var entry := {"cmd": cmd, "args": args, "line": line_no}
		match cmd:
			"if":
				var cond := _parse_condition(args)
				if cond.has("error"):
					s.errors.append("%s:%d: %s" % [name, line_no, cond.error])
				entry["cond"] = cond
				entry["else_index"] = -1
				entry["end_index"] = -1
				stack.append(s.commands.size())
			"else":
				if stack.is_empty():
					s.errors.append("%s:%d: 'else' without 'if'" % [name, line_no])
				elif s.commands[stack.back()].else_index != -1:
					s.errors.append("%s:%d: second 'else' for one 'if'" % [name, line_no])
				else:
					s.commands[stack.back()].else_index = s.commands.size()
					entry["if_index"] = stack.back()
			"end":
				if stack.is_empty():
					s.errors.append("%s:%d: 'end' without 'if'" % [name, line_no])
				else:
					var if_index: int = stack.pop_back()
					s.commands[if_index].end_index = s.commands.size()
					var else_index: int = s.commands[if_index].else_index
					if else_index >= 0:
						s.commands[else_index].end_index = s.commands.size()
			_:
				if not registry.is_empty():
					if not registry.has(cmd):
						s.errors.append("%s:%d: unknown command '%s'" % [name, line_no, cmd])
					else:
						var spec: Dictionary = registry[cmd]
						if args.size() < spec.min_args or args.size() > spec.max_args:
							s.errors.append("%s:%d: '%s' takes %s (usage: %s)" % [
								name, line_no, cmd, _count_text(spec.min_args, spec.max_args), spec.usage])
						elif spec.validate.is_valid():
							var problem: String = spec.validate.call(args)
							if problem != "":
								s.errors.append("%s:%d: %s" % [name, line_no, problem])
		s.commands.append(entry)
	for open_if in stack:
		s.errors.append("%s:%d: 'if' is missing its 'end'" % [name, s.commands[open_if].line])
	return s


## Split a line into words, keeping "quoted strings" together.
## Returns an empty array if a quote is left open.
static func tokenize(line: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	var in_quotes := false
	var had_token := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_quotes:
			if c == "\\" and i + 1 < line.length() and line[i + 1] == "\"":
				cur += "\""
				i += 1
			elif c == "\"":
				in_quotes = false
			else:
				cur += c
		elif c == "\"":
			in_quotes = true
			had_token = true
		elif c == " " or c == "\t":
			if had_token or cur != "":
				out.append(cur)
			cur = ""
			had_token = false
		else:
			cur += c
			had_token = true
		i += 1
	if in_quotes:
		return PackedStringArray()
	if had_token or cur != "":
		out.append(cur)
	return out


static func _parse_condition(args: Array) -> Dictionary:
	var a := args.duplicate()
	var negate := false
	if not a.is_empty() and String(a[0]).to_lower() == "not":
		negate = true
		a.pop_front()
	if a.is_empty():
		return {"error": "'if' needs a condition: flag/upgrade/eye/sight"}
	var kind := String(a[0]).to_lower()
	if not CONDITION_KINDS.has(kind):
		return {"error": "unknown condition '%s' (use flag, upgrade, eye or sight)" % kind}
	var needs_name := kind != "sight"
	if needs_name and a.size() != 2:
		return {"error": "'if %s' needs exactly one name" % kind}
	if not needs_name and a.size() != 1:
		return {"error": "'if sight' takes no name"}
	return {"negate": negate, "kind": kind, "name": String(a[1]) if needs_name else ""}


static func _count_text(lo: int, hi: int) -> String:
	if lo == hi:
		return "%d argument%s" % [lo, "" if lo == 1 else "s"]
	return "%d-%d arguments" % [lo, hi]
